w_negate: xor 0xffffff
    add 1
    ret

w_abs:
    dup
    alt 0
    brz @+2
    jmp w_negate
    ret
