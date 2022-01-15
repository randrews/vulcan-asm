; Prints a number, using whatever the current itoa_hook is
print_number:
    loadw itoa_hook
    jmp

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

; Print the number on top of the stack, in hex
hex_itoa: ; ( num -- )
    push 32
    call allot ; Set aside a buffer of 32 chars
    dup
    swap 0
    store ; Store a null terminator as the first char
    add 1 ; Look at the next char
    pushr ; Put this on the r stack to be used later
    #while
        dup
    #do
        dup
        and 0xf ; ( num low-nibble )
        dup
        lt 10
        #if
            add 48 ; It's 0-9, so add a '0'
        #else
            add 87 ; It's a-f, so add an 'a' - 10
        #end
        peekr
        store
        popr
        add 1
        pushr
        div 16
    #end
    pop
    popr
    sub 1
    #while
        dup
        load
        call dupnz
    #do
        store 2
        sub 1
    #end
    pop
    push 32
    call free
    ret
