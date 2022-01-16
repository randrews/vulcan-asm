input_number:
    call word_to_heap
    loadw heap_ptr
    loadw is_number_hook
    call
    ret

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
        rshift 4
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

; Print the current stack contents, in order from 256 up, separated by spaces
; TODO this depends on a 256-based stack and will need to be changed if you call setsdp
print_stack: ; ( -- )
    push print_stack_start
    call print
    sdp
    sub 6
    pushr
    pop
    push 256
    #while
        dup
        peekr
        lt
    #do
        dup
        loadw
        loadw itoa_hook
        call
        push 32
        store 2
        add 3
    #end
    popr
    pop
    pop
    push print_stack_end
    call print
    ret

; Roll left (moving high bit to low)
rol: ; ( n -- n2 )
    dup
    lshift 1
    swap
    and 0x800000
    #if
    or 1
    #end
    ret

; Roll right (moving low bit to high)
ror: ; ( n -- n2 )
    dup
    rshift 1
    swap
    and 1
    #if
    or 0x800000
    #end
    ret

; Select one of a / b to leave on the stack, depending on whether
; [a b comparator] returns nonzero. This is the guts of min / max /
; umin / umax
select_num: ; ( a b comparator -- n )
    pushr
    pick 1
    pick 1
    popr
    call
    brnz @+2
    swap
    pop
    ret
