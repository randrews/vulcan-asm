w_negate: xor 0xffffff
    add 1
    ret

w_abs:
    dup
    alt 0
    brz @w_abs_end
    jmp w_negate
w_abs_end: ret

w_even:
    and 1
    not
    ret
