#pragma once
#include <stdlib.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

// The size of main memory in bytes
#define MEM (128 * 1024)

typedef struct Device { int start, end; int peek, poke, tick, reset; } Device;

typedef struct Cpu {
    Device *devices; // All the devices
    int num_devices;
    int num_hooks;

    char *mem; // Initialized to rand

    int int_enabled; // false
    int int_vector; // zero

    int pc; // 1024, Program counter
    int dp; // 256, Data stack pointer (0x00-0xff reserved, always points at low byte of top of stack)
    int bottom_dp; // 256, Exists only for debugging; set this in a setdp instruction
    int sp; // 1024, Return stack pointer (256 cells higher)
    int halted; // false
    int next_pc; // 0
    // Last entry of stack is set to STACK - 1
    // All devices' reset hooks called
} Cpu;

int luaopen_lfov(lua_State *lua);
