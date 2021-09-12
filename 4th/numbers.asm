; Print the number on top of the stack, in decimal, with a
; leading '-' if it's negative
itoa: ; ( num -- )
    dup
    alt 0 ; We less than 0?
    brz @itoa_pos
    xor 0xffffff ; Less than zero, so negate it
    add 1
    push 45 ; 45 is '-', print a leading dash
    store 2
itoa_pos: ; ( num -- )
    push 32
    call allot
    dup
    swap 0
    store
    add 1
    pushr
itoa_loop:
    dup ; ( num num ) [ arr ]
    mod 10
    dup
    add 48 ; ( num mod ch )
    peekr ; ( num mod ch arr ) [ arr ]
    store
    popr ; ( num mod arr ) [ ]
    add 1
    pushr ; ( num mod ) [ arr+1 ]
    sub
    div 10
    dup
    brnz @itoa_loop
    pop
    ; Got the array of digits in reverse order, print them out:
    popr
    sub 1
itoa_print_loop:
    dup
    load
    store 2
    sub 1
    dup
    load
    brnz @itoa_print_loop
    pop
    push 32
    call free
    ret
