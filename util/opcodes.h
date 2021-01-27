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
    JMP = 23,
    JMPR = 24,
    CALL = 25,
    RET = 26,
    BRZ = 27,
    BRNZ = 28,
    HLT = 29,
    LOAD = 30,
    LOAD16 = 31,
    LOAD24 = 32,
    STORE = 33,
    STORE16 = 34,
    STORE24 = 35,
    INTON = 36,
    INTOFF = 37,
    SETIV = 38,
    SP = 39,
    DP = 40,
    SETSDP = 41,
    INCSP = 42,
    DECSP = 43,
    DEBUG = 44
} Opcode;
