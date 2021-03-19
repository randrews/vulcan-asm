#include "cvemu.h"
#include "../util/opcodes.h"

const int MAX_DEVICES = 100;
const int MAX_HOOKS = 256;

/* Userdata boilerplate */
int newCpu(lua_State *L);
Cpu* checkCpu(lua_State *L, int i);
int cpuToString(lua_State *L);
int gcCpu(lua_State *L);

/* Methods */
int cvemu_reset(lua_State *L);
void cpu_reset(Cpu *cpu);
int cvemu_push_data(lua_State *L);
void cpu_push_data(Cpu *cpu, int word);
int cvemu_pop_data(lua_State *L);
int cpu_pop_data(Cpu *cpu);
int cvemu_push_call(lua_State *L);
void cpu_push_call(Cpu *cpu, int addr);
int cvemu_pop_call(lua_State *L);
int cpu_pop_call(Cpu *cpu);
int cpu_peek_call(Cpu *cpu);
int cvemu_poke(lua_State *L);
void cpu_poke(Cpu *cpu, unsigned int addr, unsigned char value, lua_State *L);
int cvemu_poke24(lua_State *L);
void cpu_poke24(Cpu *cpu, unsigned int addr, unsigned int value, lua_State *L);
int cvemu_peek24(lua_State *L);
int cpu_peek24(Cpu *cpu, unsigned int addr, lua_State *L);
int cvemu_peek(lua_State *L);
unsigned char cpu_peek(Cpu *cpu, unsigned int addr, lua_State *L);
int cvemu_print_stack(lua_State *L);
int cvemu_fetch_stack(lua_State *L);
Opcode cpu_fetch(Cpu *cpu, lua_State *L);
int cvemu_run(lua_State *L);
void cpu_run(Cpu *cpu, lua_State *L);
int cvemu_install_device(lua_State *L);
int cvemu_flags(lua_State *L);
int cvemu_tick_devices(lua_State *L);
void cpu_tick_devices(Cpu *cpu, lua_State *L);
int cvemu_interrupt(lua_State *L);
int cvemu_pc(lua_State *L);
int cvemu_sp(lua_State *L);
int cvemu_dp(lua_State *L);
int cvemu_set_pc(lua_State *L);

/* Utils */
int to_signed(int word);

/****************************************/

int luaopen_cvemu(lua_State *lua){
    luaL_Reg CpuMethods[] = {
        {"__tostring", cpuToString},
        {"__gc", gcCpu},
        {"reset", cvemu_reset},
        {"push_data", cvemu_push_data},
        {"pop_data", cvemu_pop_data},
        {"push_call", cvemu_push_call},
        {"pop_call", cvemu_pop_call},
        {"poke", cvemu_poke},
        {"peek", cvemu_peek},
        {"poke24", cvemu_poke24},
        {"peek24", cvemu_peek24},
        {"pc", cvemu_pc},
        {"sp", cvemu_sp},
        {"dp", cvemu_dp},
        {"set_pc", cvemu_set_pc},
        {"print_stack", cvemu_print_stack},
        {"stack", cvemu_fetch_stack},
        {"install_device", cvemu_install_device},
        {"run", cvemu_run},
        {"flags", cvemu_flags},
        {"tick_devices", cvemu_tick_devices},
        {"interrupt", cvemu_interrupt},
        {NULL, NULL}
    };

    luaL_newlib(lua, CpuMethods);
    luaL_newmetatable(lua, "Cpu");
    lua_pushstring(lua, "__index");
    lua_pushvalue(lua, -3);
    lua_settable(lua, -3);

    luaL_Reg cvemu[] = {
        {"new", newCpu},
        {NULL, NULL}
    };

    luaL_newlib(lua, cvemu);

    return 1;
}

/****************************************/

int newCpu(lua_State *L){
    if ( lua_gettop(L) > 0 ) { srand(luaL_checkinteger(L, 1)); }
    Cpu *cpu = lua_newuserdatauv(L, sizeof(Cpu), MAX_HOOKS); // The uservalues are all functions for device hooks
    lua_pushvalue(L, -1);
    luaL_getmetatable(L, "Cpu");
    lua_setmetatable(L, -2);

    cpu->mem = malloc(MEM * sizeof(char));
    for(int n = 0; n < MEM; n++) {
        cpu->mem[n] = (char) (rand() % 256);
    }

    cpu->sp = 0;
    cpu->dp = 0;

    cpu->int_enabled = 0;
    cpu->int_vector = 0;

    cpu->devices = malloc(MAX_DEVICES * sizeof(Device));
    cpu->num_devices = 0;
    cpu->num_hooks = 0;

    cpu_reset(cpu);

    return 1;
}

Cpu* checkCpu(lua_State *L, int n){
    void *ud = luaL_checkudata(L, n, "Cpu");
    luaL_argcheck(L, ud != NULL, n, "`Cpu' expected");
    return (Cpu*)ud;
}

int cpuToString(lua_State *L){
    Cpu *cpu = checkCpu(L, 1);
    char *s = malloc(64);
    sprintf(s, "<cvemu.CPU 0x%lx>", (unsigned long)(cpu));
    lua_pushstring(L, s);
    free(s);
    return 1;
}

int gcCpu(lua_State *L){
    Cpu *cpu = checkCpu(L, 1);
    printf("killing <cvemu.CPU 0x%lx>\n", (unsigned long)(cpu));
    free(cpu->mem);
    return 0;
}

//////////////////////////////////////////////////
/// Instance methods /////////////////////////////
//////////////////////////////////////////////////

int cvemu_reset(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    cpu_reset(cpu);

    for(int n = 0; n < cpu->num_devices; n++) {
        if (cpu->devices[n].reset) {
            lua_getiuservalue(L, 1, cpu->devices[n].reset);
            lua_call(L, 0, 0);
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

void cpu_reset(Cpu *cpu) {
    cpu->dp = 256; // Data stack pointer (0x00-0xff reserved, always points at low byte of top of stack)
    cpu->bottom_dp = 256; // Exists only for debugging; set this in a setdp instruction
    cpu->sp = 1024; // Return stack pointer (256 cells higher)
    cpu->pc = 1024; // Program counter
    cpu->halted = 0; // Flag to stop execution
    cpu->int_enabled = 0; // Flag to disable interrupts
    cpu->int_vector = 0; // Interrupt vector
    cpu->next_pc = -1; // Set after each fetch, opcodes can change it
}

static void dumpstack (lua_State *L) {
  int top=lua_gettop(L);
  for (int i=1; i <= top; i++) {
    printf("%d\t%s\t", i, luaL_typename(L,i));
    switch (lua_type(L, i)) {
      case LUA_TNUMBER:
        printf("%g\n",lua_tonumber(L,i));
        break;
      case LUA_TSTRING:
        printf("%s\n",lua_tostring(L,i));
        break;
      case LUA_TBOOLEAN:
        printf("%s\n", (lua_toboolean(L, i) ? "true" : "false"));
        break;
      case LUA_TNIL:
        printf("%s\n", "nil");
        break;
      default:
        printf("%p\n",lua_topointer(L,i));
        break;
    }
  }
}

int store_hook(Cpu *cpu, lua_State *L, const char *name) {
    lua_pushstring(L, name);
    lua_gettable(L, -2);
    if (lua_isfunction(L, -1)) {
        cpu->num_hooks++;
        if (lua_setiuservalue(L, 1, cpu->num_hooks)) {
            return cpu->num_hooks;
        } else { return luaL_error(L, "Out of hooks"); }
    } else {
        lua_pop(L, 1);
        return 0;
    }
}

int cvemu_install_device(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    if (cpu->num_devices == MAX_DEVICES) { // Ensure there's room
        return luaL_error(L, "Maximum number of devices installed");
    }
    // Store the address range
    cpu->devices[cpu->num_devices].start = luaL_checkinteger(L, 2);
    cpu->devices[cpu->num_devices].end = luaL_checkinteger(L, 3);

    if (!lua_istable(L, 4)) { luaL_error(L, "Expected a table for the final argument to install_device"); }

    // Store the hooks as uservalues
    cpu->devices[cpu->num_devices].reset = store_hook(cpu, L, "reset");
    cpu->devices[cpu->num_devices].peek = store_hook(cpu, L, "peek");
    cpu->devices[cpu->num_devices].poke = store_hook(cpu, L, "poke");
    cpu->devices[cpu->num_devices].tick = store_hook(cpu, L, "tick");

    cpu->num_devices++;

    lua_pushvalue(L, 1);
    return 1;
}

int cvemu_push_data(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    int word = luaL_checkinteger(L, 2);
    cpu_push_data(cpu, word);
    return 0;
}

// The 'dp' register always points one above the high byte of the
// top of the stack, so mem[dp-3] is the least significant byte
void cpu_push_data(Cpu *cpu, int word) {
    word &= 0xffffff;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    cpu_poke24(cpu, cpu->dp, word, 0);
    cpu->dp += 3;
}

int cvemu_pop_data(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu_pop_data(cpu));
    return 1;
}

int cpu_pop_data(Cpu *cpu) {
    cpu->dp -= 3;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    return cpu_peek24(cpu, cpu->dp, 0);
}

int cvemu_push_call(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    int val = luaL_checkinteger(L, 2);
    cpu_push_call(cpu, val);
    return 0;
}

// The 'sp' register always points to the low byte of the
// top of the stack, so mem[sp] is the least significant byte
void cpu_push_call(Cpu *cpu, int val) {
    cpu->sp -= 3;
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    cpu_poke24(cpu, cpu->sp, val & 0xffffff, 0);
}

int cvemu_pop_call(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu_pop_call(cpu));
    return 1;
}

int cpu_pop_call(Cpu *cpu) {
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    int val = cpu_peek24(cpu, cpu->sp, 0);
    cpu->sp += 3;
    return val;
}

int cpu_peek_call(Cpu *cpu) {
    // Warning! We're implicitly assuming the stacks don't overlap with device memory
    int val = cpu_peek24(cpu, cpu->sp, 0);
    return val;
}

int cvemu_poke(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    unsigned char value = luaL_checkinteger(L, 3) & 0xff;
    cpu_poke(cpu, addr, value, L);

    return 0;
}

// The lua_State parameter is optional! This can be called from opcodes / contexts
// where poking to devices makes sense, or it can be called from contexts where it
// doesn't make sense, because setting the stack pointers to memory that overlaps
// memory-mapped devices will cause undefined behavior.
void cpu_poke(Cpu *cpu, unsigned int addr, unsigned char value, lua_State *L) {
    addr &= 0x01ffff;

    if(L) {
        for(int n = 0; n < cpu->num_devices; n++) {
            if (cpu->devices[n].poke && addr >= cpu->devices[n].start && addr <= cpu->devices[n].end) {
                lua_getiuservalue(L, 1, cpu->devices[n].poke);
                lua_pushinteger(L, addr - cpu->devices[n].start);
                lua_pushinteger(L, value);
                lua_call(L, 2, 0);
                return;
            }
        }
    }

    cpu->mem[addr] = value;
}

int cvemu_pc(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu->pc);
    return 1;
}

int cvemu_sp(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu->sp);
    return 1;
}

int cvemu_dp(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu->dp);
    return 1;
}

int cvemu_set_pc(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int new_pc = luaL_checkinteger(L, 2);
    cpu->pc = new_pc;
    return 0;
}

int cvemu_peek(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    lua_pushinteger(L, cpu_peek(cpu, addr, L));
    return 1;
}

// The lua_State parameter is optional! See cpu_poke
unsigned char cpu_peek(Cpu *cpu, unsigned int addr, lua_State *L) {
    addr &= 0x01ffff;

    if(L) {
        for(int n = 0; n < cpu->num_devices; n++) {
            if (cpu->devices[n].peek && addr >= cpu->devices[n].start && addr <= cpu->devices[n].end) {
                lua_getiuservalue(L, 1, cpu->devices[n].peek);
                lua_pushinteger(L, addr - cpu->devices[n].start);
                lua_call(L, 1, 1);
                int val = luaL_checkinteger(L, -1);
                lua_pop(L, 1);
                return val;
            }
        }
    }

    return cpu->mem[addr];
}

int cvemu_poke24(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    unsigned char value = luaL_checkinteger(L, 3) & 0xff;
    cpu_poke24(cpu, addr, value, L);

    return 0;
}

void cpu_poke24(Cpu *cpu, unsigned int addr, unsigned int value, lua_State *L) {
    cpu_poke(cpu, addr, value & 0xff, L);
    cpu_poke(cpu, addr + 1, (value >> 8) & 0xff, L);
    cpu_poke(cpu, addr + 2, (value >> 16) & 0xff, L);
}

int cvemu_peek24(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    lua_pushinteger(L, cpu_peek24(cpu, addr, L));
    return 1;
}

int cpu_peek24(Cpu *cpu, unsigned int addr, lua_State *L) {
    int val = cpu_peek(cpu, addr, L);
    val |= (cpu_peek(cpu, addr + 1, L) << 8);
    val |= (cpu_peek(cpu, addr + 2, L) << 16);
    return val;
}

int cvemu_print_stack(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    if (cpu->dp == cpu->bottom_dp) {
        printf("<stack empty>\n");
    } else {
        for (int i = cpu->bottom_dp; i < cpu->dp; i+=3) {
            printf("%d:\t0x%x\n", i, cpu_peek24(cpu, i, 0));
        }
    }
    return 0;
}


int cvemu_fetch_stack(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    
    if (cpu->dp < cpu->bottom_dp) {
        luaL_error(L, "Stack has underflowed");
    } else if (cpu->dp == cpu->bottom_dp) {
        return 0; // Stack's empty, return nothing
    } else {
        int count = 0;
        for (int i = cpu->bottom_dp; i < cpu->dp; i+=3) {
            lua_pushinteger(L, cpu_peek24(cpu, i, 0));
            count++;
        }
        return count;
    }
}


Opcode cpu_fetch(Cpu *cpu, lua_State *L) {
    int instruction = cpu_peek(cpu, cpu->pc, L);
    int arg_length = instruction & 3;
    Opcode opcode = instruction >> 2;

    if (arg_length > 0) {
        int arg = 0;
        for(int n=1; n <= arg_length; n++) {
            unsigned int b = cpu_peek(cpu, cpu->pc + n, L);
            b <<= (8 * (n - 1));
            arg += b;
        }

        cpu_push_data(cpu, arg);
    }

    if (opcode != HLT) {
        cpu->next_pc = cpu->pc + arg_length + 1;
    }

    return opcode;
}

int to_signed(int word) {
    if (word & 0x800000) {
        return -((word ^ 0xffffff) + 1);
    } else {
        return word;
    }
}

void cpu_execute(Cpu *cpu, Opcode instruction, lua_State *L) {
    int a, b, c;

    switch(instruction) {
    case PUSH: break; // Fetch deals with this
    case ADD:
        cpu_push_data(cpu, cpu_pop_data(cpu) + cpu_pop_data(cpu));
        break;
    case SUB:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_pop_data(cpu) - b);
        break;
    case MUL:
        cpu_push_data(cpu, cpu_pop_data(cpu) * cpu_pop_data(cpu));
        break;
    case DIV:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_pop_data(cpu) / b);
        break;
    case MOD:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_pop_data(cpu) % b);
        break;
    case RAND:
        // TODO
        break;
    case AND:
        cpu_push_data(cpu, cpu_pop_data(cpu) & cpu_pop_data(cpu));
        break;
    case OR:
        cpu_push_data(cpu, cpu_pop_data(cpu) | cpu_pop_data(cpu));
        break;
    case XOR:
        cpu_push_data(cpu, cpu_pop_data(cpu) ^ cpu_pop_data(cpu));
        break;
    case NOT:
        cpu_push_data(cpu, cpu_pop_data(cpu) ? 0 : 1);
        break;
    case GT:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_push_data(cpu, a > b ? 1 : 0);
        break;
    case LT:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_push_data(cpu, a < b ? 1 : 0);
        break;
    case AGT:
        b = to_signed(cpu_pop_data(cpu));
        a = to_signed(cpu_pop_data(cpu));
        cpu_push_data(cpu, a > b ? 1 : 0);
        break;
    case ALT:
        b = to_signed(cpu_pop_data(cpu));
        a = to_signed(cpu_pop_data(cpu));
        cpu_push_data(cpu, a < b ? 1 : 0);
        break;
    case LSHIFT:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_pop_data(cpu) << b);
        break;
    case RSHIFT:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_pop_data(cpu) >> b);
        break;
    case ARSHIFT:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        if (a & 0x800000) {
            for(int n=0; n < b; n++) {
                a = (a >> 1) | 0x800000;
            }
            cpu_push_data(cpu, a);
        } else {
            cpu_push_data(cpu, a >> b);
        }
        break;
    case POP:
        b = cpu_pop_data(cpu);
        break;
    case DUP:
        cpu_push_data(cpu, cpu_peek24(cpu, cpu->dp - 3, 0));
        break;
    case SWAP:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_push_data(cpu, b);
        cpu_push_data(cpu, a);
        break;
    case PICK:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_peek24(cpu, cpu-> dp - (b + 1) * 3, 0));
        break;
    case ROT:
        c = cpu_pop_data(cpu);
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_push_data(cpu, b);
        cpu_push_data(cpu, c);
        cpu_push_data(cpu, a);
        break;
    case JMP:
        cpu->next_pc = cpu_pop_data(cpu);
        break;
    case JMPR:
        cpu->next_pc = cpu->pc + cpu_pop_data(cpu);
        break;
    case CALL:
        cpu_push_call(cpu, cpu->next_pc);
        cpu->next_pc = cpu_pop_data(cpu);
        break;
    case RET:
        cpu->next_pc = cpu_pop_call(cpu);
        break;
    case BRZ:
        b = to_signed(cpu_pop_data(cpu));
        if (!cpu_pop_data(cpu)) { cpu->next_pc = cpu->pc + b; }
        break;
    case BRNZ:
        b = to_signed(cpu_pop_data(cpu));
        if (cpu_pop_data(cpu)) { cpu->next_pc = cpu->pc + b; }
        break;
    case HLT:
        cpu->halted = 1;
        break;
    case LOAD:
        cpu_push_data(cpu, cpu_peek(cpu, cpu_pop_data(cpu), L));
        break;
    case LOADW:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_peek(cpu, b, L) | cpu_peek(cpu, b+1, L) << 8 | cpu_peek(cpu, b+2, L) << 16);
        break;
    case STORE:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_poke(cpu, b, a, L);
        break;
    case STOREW:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_poke(cpu, b, a, L);
        cpu_poke(cpu, b+1, a >> 8, L);
        cpu_poke(cpu, b+2, a >> 16, L);
        break;
    case INTON:
        cpu->int_enabled = 1;
        break;
    case INTOFF:
        cpu->int_enabled = 0;
        break;
    case SETIV:
        cpu->int_vector = cpu_pop_data(cpu);
        break;
    case SDP:
        cpu_push_data(cpu, cpu->sp);
        cpu_push_data(cpu, cpu->dp + 3);
        break;
    case SETSDP:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu->dp = b;
        cpu->sp = a;
        break;
    case PUSHR:
        cpu_push_call(cpu, cpu_pop_data(cpu));
        break;
    case POPR:
        cpu_push_data(cpu, cpu_pop_call(cpu));
        break;
    case PEEKR:
        cpu_push_data(cpu, cpu_peek_call(cpu));
        break;
    case DEBUG:
        cvemu_print_stack(L);
        printf("--------------------\n");
        break;
    }
    cpu->pc = cpu->next_pc;
}

int cvemu_run(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    cpu_run(cpu, L);
    return 1;
}

void cpu_run(Cpu *cpu, lua_State *L) {
    while (!cpu->halted) {
        cpu_execute(cpu, cpu_fetch(cpu, L), L);
        cpu_tick_devices(cpu, L);
    }
}

int cvemu_flags(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushboolean(L, cpu->halted);
    lua_pushboolean(L, cpu->int_enabled);
    return 2;
}

int cvemu_tick_devices(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    cpu_tick_devices(cpu, L);
    return 0;
}

void cpu_tick_devices(Cpu *cpu, lua_State *L) {
    if (cpu->num_devices) {
        for(int n = 0; n < cpu->num_devices; n++) {
            if (cpu->devices[n].tick) {
                lua_getiuservalue(L, 1, cpu->devices[n].tick);
                lua_call(L, 0, 0);
            }
        }
    }
}

int cvemu_interrupt(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    if (cpu->int_enabled) {
        cpu->int_enabled = 0;
        cpu->halted = 0;
        cpu_push_call(cpu, cpu->pc);

        for(int n = 2; n <= lua_gettop(L); n++) {
            cpu_push_data(cpu, luaL_checkinteger(L, n));
        }
        cpu->pc = cpu->int_vector;
    }
    return 0;
}
