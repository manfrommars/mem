# Memory Access Violation
We're back again to look at everyone's favorite bug:  the memory access violation, a.k.a. SEGFAULT.  SEGFAULT is a gift from the OS informing our program that it has attempted to read or write from invalid memory.  Most commonly this shows up as a null pointer dereference, but there are all sorts of memory accesses that we can perform to non-null addresses which may also violate access permissions.

# Basic Pointers
Starting with a basic pointer example, we declare some stack variables and pointers to them.  Note that even though `c` is not yet initialized, it already has space on the stack.  While it is possible to print the value of `c` here, the value is meaningless and it will cause warnings from our tools that we're not concerned with for now.

```C
#include <stdio.h>

int main() {
    int  a = 42;
    int* b = &a;

    printf(" a: %d\n", a);
    printf(" b: %p\n", b);
    printf("*b: %d\n", *b);

    int  c;
    int* d = &c;
    printf(" d: %p\n", d);

    return 0;
}
```
## Bugs, bugs, bugs
If we reset the value of our pointer to `a` rather than `a` itself, we'll end up with a nice runtime bug that crashes our program.

```C
#include <stdio.h>

int main() {
    int  a = 42;
    int* b = &a;

    printf(" a: %d\n", a);
    printf(" b: %p\n", b);
    printf("*b: %d\n", *b);

    // Reset a
    b = 0;

    printf(" a: %d\n", a);
    printf(" b: %p\n", b);
    printf("*b: %d\n", *b);

    return 0;
}
```
Program output:
```
$ ./test2 
 a: 42
 b: 0x7ffc5458321c
*b: 42
 a: 42
 b: (nil)
Segmentation fault (core dumped)
```
But no one is ever **that** mindless with their code, you argue.  Very true!  But more practical examples will come in a minute.

## Valgrind
Running this program through valgrind gives us a last-minute warning:
```
$ valgrind ./test2 
==16024== Memcheck, a memory error detector
==16024== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==16024== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==16024== Command: ./test2
==16024== 
 a: 42
 b: 0x1ffefffefc
*b: 42
 a: 42
 b: (nil)
==16024== Invalid read of size 4
==16024==    at 0x108751: main (main.c:16)
==16024==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
==16024== 
==16024== 
==16024== Process terminating with default action of signal 11 (SIGSEGV)
==16024==  Access not within mapped region at address 0x0
==16024==    at 0x108751: main (main.c:16)
==16024==  If you believe this happened as a result of a stack
==16024==  overflow in your program's main thread (unlikely but
==16024==  possible), you can try to increase the size of the
==16024==  main thread stack using the --main-stacksize= flag.
==16024==  The main thread stack size used in this run was 8388608.
==16024== 
==16024== HEAP SUMMARY:
==16024==     in use at exit: 0 bytes in 0 blocks
==16024==   total heap usage: 1 allocs, 1 frees, 1,024 bytes allocated
==16024== 
==16024== All heap blocks were freed -- no leaks are possible
==16024== 
==16024== For counts of detected and suppressed errors, rerun with: -v
==16024== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
Segmentation fault (core dumped)
```
Inline, we see output from valgrind (prefixed by process ID), followed by the output from our `printf()` calls, then the output warning of our invalid access before the program crashes.  As our process terminates, valgrind is nice enough to inform us of the accesses and possibility of stack overflow due to SIGSEGV.  In this case, we know that our stack is fine, so we can ignore the stack overflow warning there.

## AddressSanitizer
Running the same code with address sanitizer shows a similar failure:
```
$ ./test2-asan 
 a: 42
 b: 0x7ffc55856e40
*b: 42
 a: 42
 b: (nil)
ASAN:DEADLYSIGNAL
=================================================================
==16184==ERROR: AddressSanitizer: SEGV on unknown address 0x000000000000 (pc 0x557365988d48 bp 0x7ffc55856ea0 sp 0x7ffc55856e10 T0)
==16184==The signal is caused by a READ memory access.
==16184==Hint: address points to the zero page.
    #0 0x557365988d47 in main /home/elliot/mem/test2/main.c:16
    #1 0x7ff99249eb96 in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x21b96)
    #2 0x557365988a69 in _start (/home/elliot/mem/test2/cmake-build-debug/test2-asan+0xa69)

AddressSanitizer can not provide additional info.
SUMMARY: AddressSanitizer: SEGV /home/elliot/mem/test2/main.c:16 in main
==16184==ABORTING
```
Again here we see the warning regarding the read of address 0 after the valid output from our program, prefixed by PID.

Worth noting, neither valgrind nor AddressSanitizer will keep our program running after a SEGFAULT, but just limp along until they can output some information regarding the failed memory access.

# Another test case
The detection also applies across stack frames:
```C
#include <stdio.h>

int func1(int* a) {
    if (*a > 100) {
        *a = 1;
        return 100;
    }
    else {
        *a = 2;
        return 101;
    }
}

int main() {
    int  a = 200;
    int* b = &a;
    int  c = func1(b);

    printf(" c: %d\n", c);
    printf(" a: %d\n", a);
    printf("&a: %p\n", &a);
    printf(" b: %p\n", b);
    printf("*b: %d\n", *b);

    // Oops
    b = 0;

    c = func1(b);

    printf(" c: %d\n", c);
    printf(" a: %d\n", a);
    printf("&a: %p\n", &a);
    printf(" b: %p\n", b);
    printf("*b: %d\n", *b);

    return 0;
}
```
In this case the failures shows up when calling `func1()`.  Valgrind shows:
```
$ valgrind ./test2
==36261== Memcheck, a memory error detector
==36261== Copyright (C) 2002-2017, and GNU GPL'd, by Julian Seward et al.
==36261== Using Valgrind-3.13.0 and LibVEX; rerun with -h for copyright info
==36261== Command: ./test2
==36261== 
 c: 100
 a: 1
&a: 0x1ffeffff08
 b: 0x1ffeffff08
*b: 1
==36261== Invalid read of size 4
==36261==    at 0x1086B6: func1 (main.c:4)
==36261==    by 0x10879C: main (main.c:28)
==36261==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
==36261== 
==36261== 
==36261== Process terminating with default action of signal 11 (SIGSEGV)
==36261==  Access not within mapped region at address 0x0
==36261==    at 0x1086B6: func1 (main.c:4)
==36261==    by 0x10879C: main (main.c:28)
==36261==  If you believe this happened as a result of a stack
==36261==  overflow in your program's main thread (unlikely but
==36261==  possible), you can try to increase the size of the
==36261==  main thread stack using the --main-stacksize= flag.
==36261==  The main thread stack size used in this run was 8388608.
==36261== 
==36261== HEAP SUMMARY:
==36261==     in use at exit: 0 bytes in 0 blocks
==36261==   total heap usage: 1 allocs, 1 frees, 1,024 bytes allocated
==36261== 
==36261== All heap blocks were freed -- no leaks are possible
==36261== 
==36261== For counts of detected and suppressed errors, rerun with: -v
==36261== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
Segmentation fault (core dumped)
```
And AddressSanitizer shows similarly:
```
$ ./test2-asan 
 c: 100
 a: 1
&a: 0x7ffe2332f1a0
 b: 0x7ffe2332f1a0
*b: 1
ASAN:DEADLYSIGNAL
=================================================================
==36267==ERROR: AddressSanitizer: SEGV on unknown address 0x000000000000 (pc 0x5555db32ec21 bp 0x7ffe2332f160 sp 0x7ffe2332f150 T0)
==36267==The signal is caused by a READ memory access.
==36267==Hint: address points to the zero page.
    #0 0x5555db32ec20 in func1 /home/elliot/mem/test2/main.c:4
    #1 0x5555db32ee5c in main /home/elliot/mem/test2/main.c:28
    #2 0x7f0e3432ab96 in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x21b96)
    #3 0x5555db32eaf9 in _start (/home/elliot/mem/test2/cmake-build-debug/test2-asan+0xaf9)

AddressSanitizer can not provide additional info.
SUMMARY: AddressSanitizer: SEGV /home/elliot/mem/test2/main.c:4 in func1
==36267==ABORTING
```
# Conclusion
It is clear from looking at the output of both valgrind and AddressSanitizer that either tool will help in tracking down a SEGFAULT, making the process much easier than without.  When debugging a segfault, if it will reproduce under either tool, it may be much faster to run with one of the tools enabled than to just guess and check by printing to standard out.  Compared with dropping in to a debugger, sometimes the tools can generate more context than simply ending up deep in the bowels of an unknown program.  Conversely, sometimes the tools will generate nonsense that makes it challenging to determine the real issue at hand.

One final note--looking at the program stack addresses reported by valgrind, compared to the addresses from AddressSanitizer, it appears that valgrind is running in 64-bit mode while reporting stack addresses in what appears to be 32-bit mode, and AddressSanitizer is 64-bit across the board.  We can dig in to this more in the future, including why and what it means when running our programs.