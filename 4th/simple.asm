; A bunch of very basic, simple words:
pad_word: push pad
    ret

w_add: add
    ret

w_sub: sub
    ret

w_mul: mul
    ret

w_div: div
    ret

w_mod: mod
    ret

w_eq: xor
    not
    ret

w_gt: gt
    ret

w_lt: lt
    ret

w_at: loadw
    ret

w_set: storew
    ret

w_byte_at: load
    ret

w_byte_set: store
    ret

w_drop: pop
    ret

w_dup: dup
    ret

w_dup2:
    pick 1
    pick 1
    ret
