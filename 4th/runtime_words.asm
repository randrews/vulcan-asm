#include "numbers.asm"

; Runtime dotquote: read a string to the pad and print it
dotquote:
    push pad
    call read_quote_string
    brz @end_ret
    push pad
    call print
    ret

; The R stack is provided mostly for convenience, because it can't be the actual
; CPU return stack for reasons. But since we never use it in compile mode and we
; never use the c_stack except in compile mode, they're the same stack:
w_peek_r:
    loadw c_stack_ptr
    sub 3
    loadw
    ret

; Pick from the R stack
w_rpick: ; ( i -- c_stack[i] ) where the top of the R stack is '0 rpick'
    loadw c_stack_ptr
    swap
    add 1
    mul 3
    sub
    loadw
    ret

; Compiles a string to the heap and pushes a pointer to it
squote: ; ( -- addr )
    loadw heap_ptr
    dup
    call read_quote_string
    call dupnz
    brz @end_ret
    add 1
    storew heap_ptr
    ret

tick_word:
    call word_to_heap
    loadw heap_ptr
    jmp tick
