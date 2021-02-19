#include "Vulcan.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "../util/opcodes.h"

int to_signed(unsigned int word);

Vulcan::Vulcan() {
    init();
}

Vulcan::Vulcan(int seed) {
    srand(seed);
    init();
}

Vulcan::Vulcan(const Vulcan& other) {
    *this = other;
}

Vulcan& Vulcan::operator= (const Vulcan& other) {
    if (this != &other) {
        mem = (unsigned char*)(malloc(VULCAN_MEM * sizeof(char)));
        memcpy(mem, other.mem, VULCAN_MEM * sizeof(char));
        int_enabled = other.int_enabled;
        int_vector = other.int_vector;
        pc = other.pc;
        dp = other.dp;
        sp = other.sp;
        bottom_dp = other.bottom_dp;
        top_sp = other.top_sp;
        halted = other.halted;
        next_pc = other.next_pc;
    }
    return *this;
}

Vulcan::~Vulcan() {
    free(mem);
}

void Vulcan::init() {
    mem = (unsigned char*)(malloc(VULCAN_MEM * sizeof(char)));
    for(int n = 0; n < VULCAN_MEM; n++) {
        mem[n] = (char) (rand() % 256);
    }
    
    sp = 0;
    dp = 0;

    int_enabled = 0;
    int_vector = 0;
}

unsigned char Vulcan::peek(unsigned int addr) const {
    return mem[addr & 0x01ffff];
}

void Vulcan::poke(unsigned int addr, unsigned char value) {
    mem[addr & 0x01ffff] = value;
}

void Vulcan::loadROM(unsigned int start, const unsigned char *rom, unsigned int length){
    memcpy(mem + start, rom, length);
}

void Vulcan::reset() {
    dp = 256; // Data stack pointer (0x00-0xff reserved, always points at low byte of top of stack)
    bottom_dp = 256; // Exists only for debugging; set this in a setdp instruction
    top_sp = 1024; // Exists only for debugging; set this in a setdp instruction
    sp = 1024; // Return stack pointer (256 cells higher)
    pc = 1024; // Program counter
    halted = 0; // Flag to stop execution
    next_pc = -1; // Set after each fetch, opcodes can change it
}

void Vulcan::push_data(unsigned int word) {
    word &= 0xffffff;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    poke24(dp, word);
    dp += 3;
}

void Vulcan::push_call(unsigned int val) {
    sp -= 3;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    poke24(sp, val & 0xffffff);
}

unsigned int Vulcan::pop_data() {
    dp -= 3;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    return peek24(dp);
}

unsigned int Vulcan::pop_call() {
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    int val = peek24(sp);
    sp += 3;
    return val;
}

unsigned int Vulcan::peek24(unsigned int addr) const {
    int val = peek(addr);
    val |= (peek(addr + 1) << 8);
    val |= (peek(addr + 2) << 16);
    return val;
}

void Vulcan::poke24(unsigned int addr, unsigned int value) {
    poke(addr, value & 0xff);
    poke(addr + 1, (value >> 8) & 0xff);
    poke(addr + 2, (value >> 16) & 0xff);
}

void Vulcan::tick() {
    if (!halted) {
        execute(fetch());
    }
}

Opcode Vulcan::fetch() {
    int instruction = peek(pc);
    int arg_length = instruction & 3;
    Opcode opcode = (Opcode)(instruction >> 2);

    if (arg_length > 0) {
        int arg = 0;
        for(int n = 1; n <= arg_length; n++) {
            unsigned int b = peek(pc + n);
            b <<= (8 * (n - 1));
            arg += b;
        }

        push_data(arg);
    }

    if (opcode != HLT) {
        next_pc = pc + arg_length + 1;
        printf("pc: %d arg: %d next: %d\n", pc, arg_length, next_pc);
    }

    return opcode;
}

void Vulcan::execute(Opcode instruction) {
    int a, b;

    switch(instruction) {
    case PUSH: break; // Fetch deals with this
    case ADD:
        push_data(pop_data() + pop_data());
        break;
    case SUB:
        b = pop_data();
        push_data(pop_data() - b);
        break;
    case MUL:
        push_data(pop_data() * pop_data());
        break;
    case DIV:
        b = pop_data();
        push_data(pop_data() / b);
        break;
    case MOD:
        b = pop_data();
        push_data(pop_data() % b);
        break;
    case RAND:
        // TODO
        break;
    case AND:
        push_data(pop_data() & pop_data());
        break;
    case OR:
        push_data(pop_data() | pop_data());
        break;
    case XOR:
        push_data(pop_data() ^ pop_data());
        break;
    case NOT:
        push_data(pop_data() ? 0 : 1);
        break;
    case GT:
        b = pop_data();
        a = pop_data();
        push_data(a > b ? 1 : 0);
        break;
    case LT:
        b = pop_data();
        a = pop_data();
        push_data(a < b ? 1 : 0);
        break;
    case AGT:
        b = to_signed(pop_data());
        a = to_signed(pop_data());
        push_data(a > b ? 1 : 0);
        break;
    case ALT:
        b = to_signed(pop_data());
        a = to_signed(pop_data());
        push_data(a < b ? 1 : 0);
        break;
    case LSHIFT:
        b = pop_data();
        push_data(pop_data() << b);
        break;
    case RSHIFT:
        b = pop_data();
        push_data(pop_data() >> b);
        break;
    case ARSHIFT:
        b = pop_data();
        a = pop_data();
        if (a & 0x800000) {
            for(int n=0; n < b; n++) {
                a = (a >> 1) | 0x800000;
            }
            push_data(a);
        } else {
            push_data(a >> b);
        }
        break;
    case POP:
        b = pop_data();
        break;
    case DUP:
        push_data(peek24(dp - 3));
        break;
    case DUP2:
        push_data(peek24(dp - 6));
        push_data(peek24(dp - 6));
        break;
    case SWAP:
        b = pop_data();
        a = pop_data();
        push_data(b);
        push_data(a);
        break;
    case PICK:
        b = pop_data();
        push_data(peek24(dp - (b + 1) * 3));
        break;
    case JMP:
        next_pc = pop_data();
        break;
    case JMPR:
        next_pc = pc + pop_data();
        break;
    case CALL:
        push_call(next_pc);
        next_pc = pop_data();
        break;
    case RET:
        next_pc = pop_call();
        break;
    case BRZ:
        b = to_signed(pop_data());
        if (!pop_data()) { next_pc = pc + b; }
        break;
    case BRNZ:
        b = to_signed(pop_data());
        if (pop_data()) { next_pc = pc + b; }
        break;
    case HLT:
        halted = 1;
        break;
    case LOAD:
        push_data(peek(pop_data()));
        break;
    case LOAD16:
        b = pop_data();
        push_data(peek(b) | peek(b+1) << 8);
        break;
    case LOAD24:
        b = pop_data();
        push_data(peek(b) | peek(b+1) << 8 | peek(b+2) << 16);
        break;
    case STORE:
        b = pop_data();
        a = pop_data();
        poke(b, a);
        break;
    case STORE16:
        b = pop_data();
        a = pop_data();
        poke(b, a);
        poke(b+1, a >> 8);
        break;
    case STORE24:
        b = pop_data();
        a = pop_data();
        poke(b, a);
        poke(b+1, a >> 8);
        poke(b+2, a >> 16);
        break;
    case INTON:
        int_enabled = 1;
        break;
    case INTOFF:
        int_enabled = 0;
        break;
    case SETIV:
        int_vector = pop_data();
        break;
    case SP:
        push_data(sp + pop_data());
        break;
    case DP:
        push_data(sp);
        break;
    case SETSDP:
        dp = pop_data();
        sp = pop_data();
        bottom_dp = dp;
        top_sp = sp;
        break;
    case INCSP:
        sp += pop_data();
        break;
    case DECSP:
        sp -= pop_data();
        push_data(sp);
        break;
    }
    pc = next_pc;
}

///////////////////////////////////////////////////////////

int Vulcan::getPC() {
    return pc;
}

int Vulcan::stackSize() {
    return (dp - bottom_dp) / 3;
}

int Vulcan::getStack(int index) {
    return peek24(dp - 3 - index * 3);
}

int Vulcan::returnSize() {
    return (top_sp - sp) / 3;
}

int Vulcan::getReturn(int index) {
    return peek24(sp + index * 3);
}

///////////////////////////////////////////////////////////

int to_signed(unsigned int word) {
    if (word & 0x800000) {
        return -((word ^ 0xffffff) + 1);
    } else {
        return word;
    }
}
