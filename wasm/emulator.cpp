#include "Vulcan.h"
#include <emscripten/bind.h>

Vulcan cpu;

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
    return cpu.stackSize();
}

int getStack(int index) {
    return cpu.getStack(index);
}

int returnSize() {
    return cpu.returnSize();
}

int getReturn(int index) {
    return cpu.getReturn(index);
}

unsigned int getPC() {
    return cpu.getPC();
}

using namespace emscripten;
EMSCRIPTEN_BINDINGS(emulator) {
    function("peek", &peek);
    function("poke", &poke);
    function("step", &step);
    function("reset", &reset);
    function("stackSize", &stackSize);
    function("getStack", &getStack);
    function("returnSize", &returnSize);
    function("getReturn", &getReturn);
    function("getPC", &getPC);
}
