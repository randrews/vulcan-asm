#pragma once
#include <stdlib.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

// The size of the stack in 24-bit words
#define STACK 2048

// The size of main memory in bytes
#define MEM (128 * 1024)

typedef struct Device { int start, end; int peek, poke, tick, reset; } Device;

typedef struct Cpu {
    Device *devices; // All the devices
    int num_devices;
    int num_hooks;

    int *stack; // initialized to zeroes

    char *mem; // Initialized to rand

    int int_enabled; // false
    int int_vector; // zero

    int pc; // 256
    int call, data; // STACK - 1
    int halted; // false
    int next_pc; // 0
    // Last entry of stack is set to STACK - 1
    // All devices' reset hooks called
} Cpu;

int luaopen_lfov(lua_State *lua);
