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