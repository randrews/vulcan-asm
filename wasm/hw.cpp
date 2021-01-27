#include <stdio.h>

extern "C" {
    int squareit(int n);
}

int squareit(int n) {
    return n * n;
}
