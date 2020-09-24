#include "cvemu.h"
#include "opcodes.h"

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
int cvemu_poke(lua_State *L);
void cpu_poke(Cpu *cpu, unsigned int addr, unsigned char value);
int cvemu_peek(lua_State *L);
unsigned char cpu_peek(Cpu *cpu, unsigned int addr);
int cvemu_print_stack(lua_State *L);
Opcode cpu_fetch(Cpu *cpu);
int cvemu_run(lua_State *L);
void cpu_run(Cpu *cpu);

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
        {"print_stack", cvemu_print_stack},
        {"run", cvemu_run},
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
    Cpu *cpu = lua_newuserdatauv(L, sizeof(Cpu), 0);
    lua_pushvalue(L, -1);
    luaL_getmetatable(L, "Cpu");
    lua_setmetatable(L, -2);

    // cpu.devices = {}

    cpu->stack = malloc(STACK * sizeof(int));
    for(int n = 0; n < STACK; n++) {
        cpu->stack[n] = 0;
    }

    cpu->mem = malloc(MEM * sizeof(char));
    for(int n = 0; n < MEM; n++) {
        cpu->mem[n] = (char) (rand() % 256);
    }

    cpu->int_enabled = 0;
    cpu->int_vector = 0;

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
    free(cpu->stack);
    free(cpu->mem);
    return 0;
}

//////////////////////////////////////////////////
/// Instance methods /////////////////////////////
//////////////////////////////////////////////////

int cvemu_reset(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    cpu_reset(cpu);
    return 1;
}

void cpu_reset(Cpu *cpu) {
    cpu->pc = 256; // Program counter
    cpu->call = STACK - 1; // Stack index of first frame of of call stack
    cpu->data = STACK - 1; // Stack index of top of data stack
    cpu->halted = 0; // Flag to stop execution
    cpu->next_pc = -1; // Set after each fetch, opcodes can change it
    cpu->stack[STACK - 1] = STACK - 1; // First stack frame points at itself

    /* for _, device in ipairs(cpu->devices) do */
    /*     if device.reset then device.reset() end */
    /* end */
}

int cvemu_push_data(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    int word = luaL_checkinteger(L, 2);
    cpu_push_data(cpu, word);
    return 0;
}

void cpu_push_data(Cpu *cpu, int word) {
    word &= 0xffffff;
    cpu->data = (cpu->data + 1) % STACK;
    cpu->stack[cpu->data] = word;
}

int cvemu_pop_data(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu_pop_data(cpu));
    return 1;
}

int cpu_pop_data(Cpu *cpu) {
    int word = cpu->stack[cpu->data];
    cpu->data = (cpu->data - 1 + STACK) % STACK;
    return word;
}

int cvemu_push_call(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    int addr = luaL_checkinteger(L, 2);
    cpu_push_call(cpu, addr);
    return 0;
}

void cpu_push_call(Cpu *cpu, int addr) {
    int oldcall = cpu->call;
    int size = cpu->stack[cpu->call - 2] + 3; // Size of this stack frame
    cpu->call -= size;

    // Initialize new frame
    cpu->stack[cpu->call] = oldcall; // Pointer to previous frame
    cpu->stack[cpu->call - 1] = addr & 0xffffff; // Return address
    cpu->stack[cpu->call - 2] = 0; // No locals (yet)
}

int cvemu_pop_call(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    lua_pushinteger(L, cpu_pop_call(cpu));
    return 1;
}

int cpu_pop_call(Cpu *cpu) {
    int prev = cpu->stack[cpu->call];
    int ret = cpu->stack[cpu->call - 1];
    cpu->call = prev;
    return ret;
}

int cvemu_poke(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    unsigned char value = luaL_checkinteger(L, 3) & 0xff;
    cpu_poke(cpu, addr, value);
    return 0;
}

void cpu_poke(Cpu *cpu, unsigned int addr, unsigned char value) {
    addr &= 0x01ffff;
    /* for _, device in ipairs(self.devices) do */
    /*     if device.poke and addr >= device.address[1] and addr <= device.address[2] then */
    /*         device.poke(addr - device.address[1], value) */
    /*         return */
    /*     end */
    /* end */
    cpu->mem[addr] = value;
}

int cvemu_peek(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    unsigned int addr = luaL_checkinteger(L, 2);
    lua_pushinteger(L, cpu_peek(cpu, addr));
    return 1;
}

unsigned char cpu_peek(Cpu *cpu, unsigned int addr) {
    addr &= 0x01ffff;
    /* for _, device in ipairs(self.devices) do */
    /*     if device.peek and addr >= device.address[1] and addr <= device.address[2] then */
    /*         return device.peek(addr - device.address[1]) */
    /*     end */
    /* end */
    return cpu->mem[addr];
}

int cvemu_print_stack(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);    
    if (cpu->data == STACK - 1) {
        printf("<stack empty>\n");
    } else {
        for (int i = 0; i <= cpu->data; i++) {
            printf("%d:\t0x%x\n", cpu->data-i, cpu->stack[i]);
        }
    }
    return 0;
}

Opcode cpu_fetch(Cpu *cpu) {
    int instruction = cpu_peek(cpu, cpu->pc);
    int arg_length = instruction & 3;
    Opcode opcode = instruction >> 2;

    if (arg_length > 0) {
        int arg = 0;
        for(int n=1; n <= arg_length; n++) {
            unsigned int b = cpu_peek(cpu, cpu->pc + n);
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

void cpu_execute(Cpu *cpu, Opcode instruction) {
    int a, b;

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
        cpu_push_data(cpu, cpu->stack[cpu->data]);
        break;
    case DUP2:
        cpu_push_data(cpu, cpu->stack[cpu->data - 1]);
        cpu_push_data(cpu, cpu->stack[cpu->data - 1]);
        break;
    case SWAP:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_push_data(cpu, b);
        cpu_push_data(cpu, a);
        break;
    case PICK:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu->stack[cpu->data - b]);
        break;
    case HEIGHT:
        cpu_push_data(cpu, cpu->data + 1);
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
        b = cpu_pop_data(cpu);
        if (!cpu_pop_data(cpu)) { cpu->next_pc = cpu->pc + b; }
        break;
    case HLT:
        cpu->halted = 1;
        break;
    case LOAD:
        cpu_push_data(cpu, cpu_peek(cpu, cpu_pop_data(cpu)));
        break;
    case LOAD16:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_peek(cpu, b) | cpu_peek(cpu, b+1) << 8);
        break;
    case LOAD24:
        b = cpu_pop_data(cpu);
        cpu_push_data(cpu, cpu_peek(cpu, b) | cpu_peek(cpu, b+1) << 8 | cpu_peek(cpu, b+2) << 16);
        break;
    case STORE:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_poke(cpu, b, a);
        break;
    case STORE16:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_poke(cpu, b, a);
        cpu_poke(cpu, b+1, a >> 8);
        break;
    case STORE24:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        cpu_poke(cpu, b, a);
        cpu_poke(cpu, b+1, a >> 8);
        cpu_poke(cpu, b+2, a >> 16);
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
    case FRAME:
        cpu->stack[cpu->call - 2] = cpu_pop_data(cpu);
        break;
    case LOCAL:
        b = cpu_pop_data(cpu);
        if (cpu->stack[cpu->call - 2] > b) { // If we have this many locals
            cpu_push_data(cpu, cpu->stack[cpu->call - 3 - b]);
        } else { // Default to pushing 0
            cpu_push_data(cpu, 0);
        }
        break;
    case SETLOCAL:
        b = cpu_pop_data(cpu);
        a = cpu_pop_data(cpu);
        if ( cpu->stack[cpu->call - 2] > b) { // If we have this many locals
            cpu->stack[cpu->call - 3 - b] = a;
        }
        break;
    }
    cpu->pc = cpu->next_pc;
}

int cvemu_run(lua_State *L) {
    Cpu *cpu = checkCpu(L, 1);
    cpu_run(cpu);
    return 1;
}

void cpu_run(Cpu *cpu) {
    while (!cpu->halted) {
        cpu_execute(cpu, cpu_fetch(cpu));
        //self:tick_devices()
    }
}
