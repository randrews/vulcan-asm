#include "numbers.asm"
#include "simple.asm"

; Runtime dotquote: read a string to the pad and print it
dotquote:
    push pad
    call read_quote_string
    brz @end_ret
    push pad
    call print
    ret

; This is a runtime word used for defining the behavior of created
; words. For example: ": foo create does> drop 12 ;" makes a word foo, used as:
; "foo blah". That call creates another word, blah, which when it's
; run pushes 12. So then, does> alters the head of the dictionary (because
; that was just create'd), to set its definition pointer to right after
; the does>, then compiles a push of the old value of the definition pointer.
; The expected result of this: ": foo create 15 , does> drop 12 ;" is this:
; > create a dictionary entry from the next word in input
; > push a 15 and compile it (the compile-time behavior of the new word)
; > push the address of label A
; > jmp to does_at_runtime (which reassigns the def ptr to lbl A)
; > return
; > label A:
; > popr the address of the 15 (where the heap originally was)
; > drop the address of the 15
; > push a 12 (runtime behavior of the new word)
; > return
does_word:
    loadw heap_ptr
    add 9 ; to account for the push itself, the call and the ret
    push $PUSH
    call compile_instruction_arg ; push the addr right after the does>
    push does_at_runtime
    push $JMP
    call compile_instruction_arg ; jmp does_at_runtime
    push $RET
    call compile_instruction ; return
    ret

; Runtime behavior of does>
; When we jmp here, the compile-time behavior has left the address
; we want for the runtime behavior of the new word at the top of stack.
; So, we need to reassign the def ptr of the new word to (eventually)
; lead there. But we need to save what it originally was, first! So we
; grab it and stick it in the R stack, then compile a whole new area
; which pushes the old ptr and then jmps after the does> addr.
does_at_runtime: ; ( does-addr -- )
    loadw dictionary
    call skip_word
    add 1 ; find the definition address
    dup
    loadw
    pushr ; stash old in the r stack
    loadw heap_ptr
    swap
    storew ; point it at the new definition
    popr
    push $PUSH
    call compile_instruction_arg ; compile pushing the old def ptr value
    push $JMP
    call compile_instruction_arg ; compile a jmp to after does>
    ret

; Creates a new dictionary entry, pointing at the (new) heap, for the following word
create_word:
    call word_to_heap
    call new_dict
    ret

; Starts a new definition of a normal runtime word
colon_word:
    call create_word
    jmp close_bracket_word

; Compiles the top of stack to the heap
comma_word:
    loadw heap_ptr
    dup
    add 3
    storew heap_ptr
    storew
    ret

; Increment heap_ptr by a number of bytes and return the old heap ptr
; (in other words, allocate an array on the heap)
allot: ; ( num -- ptr )
    loadw heap_ptr
    pick 1
    pick 1
    add
    storew heap_ptr
    swap
    pop
    ret

; Decrement heap_ptr by a number of bytes (in other words, free an array
; allocated on the top of the heap)
; TODO this shouldn't exist
free: ; ( num -- )
    loadw heap_ptr
    swap
    sub
    storew heap_ptr
    ret

; Emit a single ASCII character
putc:
    store 2
    ret

; Increment the word whose address is at TOS
w_inc:
    dup
    pushr
    loadw
    add
    popr
    storew
    ret

; Increment the byte whose address is at TOS (overflow doesn't affect next byte)
w_byte_inc:
    dup
    pushr
    load
    add
    popr
    store
    ret

; The R stack is provided mostly for convenience, because it can't be the actual
; CPU return stack for reasons. But since we never use it in compile mode and we
; never use the c_stack except in compile mode, they're the same stack:
w_peek_r:
    loadw c_stack_ptr
    sub 3
    loadw
    ret

; Drop from the R stack
w_rdrop:
    call pop_c_addr
    pop
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
