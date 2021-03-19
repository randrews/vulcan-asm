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
    DUP2 = 20,
    SWAP = 21,
    PICK = 22,
    ROT = 23,
    JMP = 24,
    JMPR = 25,
    CALL = 26,
    RET = 27,
    BRZ = 28,
    BRNZ = 29,
    HLT = 30,
    LOAD = 31,
    LOADW = 32,
    STORE = 33,
    STOREW = 34,
    INTON = 35,
    INTOFF = 36,
    SETIV = 37,
    SDP = 38,
    SETSDP = 39,
    PUSHR = 40,
    POPR = 41,
    PEEKR = 42,
    DEBUG = 43
} Opcode;
