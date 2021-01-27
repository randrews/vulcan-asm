#pragma once
#include "../util/opcodes.h"

// The size of main memory in bytes
#define VULCAN_MEM (128 * 1024)

class Vulcan {
private:
    unsigned char *mem; // Initialized to rand
    int int_enabled; // false
    int int_vector; // zero
    int pc; // 1024, Program counter
    int dp; // 256, Data stack pointer (0x00-0xff reserved, always points at low byte of top of stack)
    int sp; // 1024, Return stack pointer (256 cells higher)
    int bottom_dp; // 256, Exists only for debugging; set this in a setdp instruction
    int top_sp; // 1024, Exists only for debugging; set this in a setdp instruction
    int halted; // false
    int next_pc; // 0

    void init();

    void execute(Opcode instruction);
    Opcode fetch();

    unsigned int peek24(unsigned int addr) const;
    void poke24(unsigned int addr, unsigned int value);
    void push_data(unsigned int word);
    void push_call(unsigned int val);
    unsigned int pop_data();
    unsigned int pop_call();

public:
    Vulcan();
    Vulcan(int seed);
    Vulcan(const Vulcan& other);
    Vulcan& operator= (const Vulcan& other);
    ~Vulcan();

    unsigned char peek(unsigned int addr) const;
    void poke(unsigned int addr, unsigned char value);
    void loadROM(unsigned int start, const unsigned char *rom, unsigned int length);
    void reset();
    void tick();

    int getPC();
    int stackSize();
    int getStack(int index);
    int returnSize();
    int getReturn(int index);
};
