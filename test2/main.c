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