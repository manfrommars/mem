# Debugging Crashes with vgdb
Recently while running valgrind on a live system, a segfault showed up that had not yet been encountered in the field.  There are a number of possibilities as for why an issue would show up with the tool but not in the field, including a software bug that only shows up as a result of the timing differences when running under valgrind (e.g. the window in the field for the bug is small enough that it is almost never hit) or a bug in how valgrind is handling the program (unlikely as that may be).

To debug, we're going to use the valgrind GDB server and connect to the program at the point of failure.  The valgrind directions are pretty straightforward, so lets follow along and jump in [Valgrind Core Manual] (http://valgrind.org/docs/manual/manual-core-adv.html).

# Test Program
Our failure is a simple segfault, courtesy of your friendly neighborhood null pointer dereference, so we'll start with the following:
```C
#include <stdio.h>

int main() {
    int* a = NULL;
    *a = 100;
    return 0;
}
```
A quick build and run shows that it does indeed segfault when attempting to set `*a`:
```
$ valgrind ./test3
==3060== Memcheck, a memory error detector
==3060== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==3060== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==3060== Command: ./test3
==3060== 
==3060== Invalid write of size 4
==3060==    at 0x10865A: main (main.c:6)
==3060==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
==3060== 
==3060== 
==3060== Process terminating with default action of signal 11 (SIGSEGV)
==3060==  Access not within mapped region at address 0x0
==3060==    at 0x10865A: main (main.c:6)
==3060==  If you believe this happened as a result of a stack
==3060==  overflow in your program's main thread (unlikely but
==3060==  possible), you can try to increase the size of the
==3060==  main thread stack using the --main-stacksize= flag.
==3060==  The main thread stack size used in this run was 8388608.
==3060== 
==3060== HEAP SUMMARY:
==3060==     in use at exit: 0 bytes in 0 blocks
==3060==   total heap usage: 1 allocs, 1 frees, 1,024 bytes allocated
==3060== 
==3060== All heap blocks were freed -- no leaks are possible
==3060== 
==3060== For counts of detected and suppressed errors, rerun with: -v
==3060== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
Segmentation fault (core dumped)
```
# vgdb to the rescue!
To try and figure out why our program is crashing, we can connect with gdb to the process running under valgrind by passing the `--vgdb=yes` option.  We can also include `--vgdb-error=0` to allow a gdb connection *before* the world explodes...
```
$ valgrind --vgdb=yes --vgdb-error=0 ./test3
==3977== Memcheck, a memory error detector
==3977== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==3977== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==3977== Command: ./test3
==3977== 
==3977== (action at startup) vgdb me ... 
==3977== 
==3977== TO DEBUG THIS PROCESS USING GDB: start GDB like this
==3977==   /path/to/gdb ./test3
==3977== and then give GDB the following command
==3977==   target remote | /usr/lib/valgrind/../../bin/vgdb --pid=3977
==3977== --pid is optional if only one valgrind process is running
==3977== 
```
To start our program, follow the directions in a separate terminal:
```
$ gdb ./test3 
GNU gdb (Ubuntu 8.1-0ubuntu3) 8.1.0.20180409-git
Copyright (C) 2018 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "x86_64-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
<http://www.gnu.org/software/gdb/documentation/>.
For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from ./test3...done.
(gdb) target remote | /usr/lib/valgrind/../../bin/vgdb --pid=3977
Remote debugging using | /usr/lib/valgrind/../../bin/vgdb --pid=3977
relaying data between gdb and process 3977
warning: remote target does not support file transfer, attempting to access files from local filesystem.
Reading symbols from /lib64/ld-linux-x86-64.so.2...Reading symbols from /usr/lib/debug//lib/x86_64-linux-gnu/ld-2.27.so...done.
done.
0x0000000004001090 in _start () from /lib64/ld-linux-x86-64.so.2
(gdb) 
```
From here, we can continue program execution and wait until the segfault occurs.
```
(gdb) c
Continuing.

Program received signal SIGTRAP, Trace/breakpoint trap.
0x000000000010860a in main () at /home/elliot/mem/test3/main.c:5
5	    *a = 100;
(gdb) 
```
Of some interest, the signal received on the invalid access is a SIGTRAP rather than a SIGSEGV (segfault).  This is due to some fancy footwork valgrind does with signal handling, and is largely unavoidable.  When you allow the program to continue, valgrind allows the segfault to occur, and the SIGSEGV is hit.  Looking back at the valgrind execution terminal, you can see valgrind stepping through the various stages of handling the invalid write, first on the SIGTRAP...
```
==3977== Invalid write of size 4
==3977==    at 0x10860A: main (main.c:5)
==3977==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
==3977== 
==3977== (action on error) vgdb me ... 
```
...then on the SIGSEGV...
```
==3977== Continuing ...
```
...and finally on program termination.
```
==3977== 
==3977== Process terminating with default action of signal 11 (SIGSEGV)
==3977==  Access not within mapped region at address 0x0
==3977==    at 0x10860A: main (main.c:5)
==3977==  If you believe this happened as a result of a stack
==3977==  overflow in your program's main thread (unlikely but
==3977==  possible), you can try to increase the size of the
==3977==  main thread stack using the --main-stacksize= flag.
==3977==  The main thread stack size used in this run was 8388608.
==3977== (action on fatal signal) vgdb me ... 
==3977== 
==3977== HEAP SUMMARY:
==3977==     in use at exit: 0 bytes in 0 blocks
==3977==   total heap usage: 0 allocs, 0 frees, 0 bytes allocated
==3977== 
==3977== All heap blocks were freed -- no leaks are possible
==3977== 
==3977== For counts of detected and suppressed errors, rerun with: -v
==3977== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
Segmentation fault (core dumped)
```
## Connecting after failure
Another option available to us is to connect only after valgrind reports an issue with our program, by setting `--vgdb-error=1` (or higher), which will drop us in at the point just prior to the segfault:
```
$ valgrind --vgdb=yes --vgdb-error=1 ./test3
==4091== Memcheck, a memory error detector
==4091== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==4091== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==4091== Command: ./test3
==4091== 
==4091== 
==4091== TO DEBUG THIS PROCESS USING GDB: start GDB like this
==4091==   /path/to/gdb ./test3
==4091== and then give GDB the following command
==4091==   target remote | /usr/lib/valgrind/../../bin/vgdb --pid=4091
==4091== --pid is optional if only one valgrind process is running
==4091== 
==4091== Invalid write of size 4
==4091==    at 0x10860A: main (main.c:5)
==4091==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
==4091== 
==4091== (action on error) vgdb me ... 
```
In GDB:
```
(gdb) target remote | /usr/lib/valgrind/../../bin/vgdb --pid=4091
Remote debugging using | /usr/lib/valgrind/../../bin/vgdb --pid=4091
relaying data between gdb and process 4091
warning: remote target does not support file transfer, attempting to access files from local filesystem.
Reading symbols from /home/elliot/mem/test3/cmake-build-debug/test3...done.
Reading symbols from /usr/lib/valgrind/vgpreload_core-amd64-linux.so...(no debugging symbols found)...done.
Reading symbols from /usr/lib/valgrind/vgpreload_memcheck-amd64-linux.so...(no debugging symbols found)...done.
Reading symbols from /lib/x86_64-linux-gnu/libc.so.6...Reading symbols from /usr/lib/debug//lib/x86_64-linux-gnu/libc-2.27.so...done.
done.
Reading symbols from /lib64/ld-linux-x86-64.so.2...Reading symbols from /usr/lib/debug//lib/x86_64-linux-gnu/ld-2.27.so...done.
done.
0x000000000010860a in main () at /home/elliot/mem/test3/main.c:5
5	    *a = 100;
(gdb) 
```
If we continue from here, we get the SIGSEGV, and can continue through to program termination.
```
(gdb) c
Continuing.

Program received signal SIGSEGV, Segmentation fault.
0x000000000010860a in main () at /home/elliot/mem/test3/main.c:5
5	    *a = 100;
(gdb) c
Continuing.

Program terminated with signal SIGSEGV, Segmentation fault.
The program no longer exists.
(gdb) 
```
This option can also be used to verify a failure encountered during normal operation when running valgrind to find other (non-fatal) errors reported during execution.  Again, note that in this case upon connection we then immediately encounter the segfault, missing valgrind's initial SIGTRAP.
# AddressSanitizer
Because AddressSanitizer is a library linked in the executable, rather than a standalone application responsible for running the application on a "synthetic CPU", you can directly debug applications with GDB which already include AddressSanitizer.  Digging in to the AddressSanitizer library under the hood is something we'll get to later on, for now set a breakpoint on `__asan::ReportGenericError` and call it a day.