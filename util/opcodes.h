#pragma once

typedef enum Opcode {
    PUSH = 0,
    ADD = 1,
    SUB = 2,
    MUL = 3,
    DIV = 4,
    MOD = 5,
    RAND = 6,
    AND = 7,
    OR = 8,
    XOR = 9,
    NOT = 10,
    GT = 11,
    LT = 12,
    AGT = 13,
    ALT = 14,
    LSHIFT = 15,
    RSHIFT = 16,
    ARSHIFT = 17,
    POP = 18,
    DUP = 19,
    SWAP = 20,
    PICK = 21,
    ROT = 22,
    JMP = 23,
    JMPR = 24,
    CALL = 25,
    RET = 26,
    BRZ = 27,
    BRNZ = 28,
    HLT = 29,
    LOAD = 30,
    LOADW = 31,
    STORE = 32,
    STOREW = 33,
    SETINT = 34,
    SETIV = 35,
    SDP = 36,
    SETSDP = 37,
    PUSHR = 38,
    POPR = 39,
    PEEKR = 40,
    DEBUG = 41
} Opcode;
