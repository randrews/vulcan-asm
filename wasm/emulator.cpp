#include "Vulcan.h"

Vulcan cpu;

extern "C" {
    void loadROM(const unsigned char *rom, unsigned int length);
    unsigned char peek(unsigned int addr);
    void poke(unsigned int addr, unsigned char value);
    void step();
    void reset();
    int stackSize();
    int getStack(int index);
}

void loadROM(const unsigned char *rom, unsigned int length) {
    cpu.loadROM(0x400, rom, length);
}

void step() {
    cpu.tick();
}

unsigned char peek(unsigned int addr) {
    return cpu.peek(addr);
}

void poke(unsigned int addr, unsigned char value) {
    cpu.poke(addr, value);
}

void reset() {
    cpu.reset();
}

int stackSize() {
    return 10;
}

int getStack(int index) {
    return index * 3 + 1;
}
