; Assumes there's currently a word on the heap, writes two pointers after it: one to the (new) heap,
; and one to the current dictionary head. Then makes the dictionary point at the start of that word.
; This is usually used as: call word_to_heap, call new_dict, and you have added that word to the
; dictionary pointing at the new heap start.
new_dict:
    loadw heap_ptr
    dup
    load
    brz @new_dict_error
    call skip_word
    add 1
    dup ; ( def_ptr def_ptr )
    add 6
    pick 1
    storew ; write the def address, ( def_ptr )
    loadw dictionary
    pick 1
    add 3
    storew ; point it at the dictionary
    loadw heap_ptr
    storew dictionary ; point the dictionary at it
    add 6
    storew heap_ptr ; advance the heap ptr
    ret
new_dict_error:
    pop
    push expected_word_err
    call print
    call cr
    ret

open_bracket_word: push handleword ; Set the current mode to interpret
    jmpr @+2
close_bracket_word: push compileword ; Set the current mode to compile
    storew handleword_hook
    ret

; Compiles a full 4-byte instruction to the heap given an arg and an opcode
compile_instruction_arg: ; ( arg opcode -- )
    lshift 2
    or 3 ; tell it we have a three byte arg
    loadw heap_ptr ; ( arg instr-byte heap_ptr )
    dup
    add 4
    storew heap_ptr ; Increment the ptr ( arg instr-byte heap_ptr )
    pick 1
    pick 1
    store
    add 1
    swap
    pop ; ( arg heap_ptr+1 )
    storew
    ret

; Compiles an argument-less 1-byte instruction to the heap
compile_instruction: ; ( opcode -- )
    lshift 2
    loadw heap_ptr ; ( instr-byte heap_ptr )
    dup
    add 1
    storew heap_ptr ; Increment the ptr ( instr-byte heap_ptr )
    store
    ret

; Compiles an instruction with an unresolved argument to the heap. Usually used
; for compiling jumps / branches
push_jump: ; ( opcode -- )
    push 0
    swap
    call compile_instruction_arg
    loadw heap_ptr
    sub 3
    call push_c_addr
    ret

; Pushes an address of an unresolved pointer to the control stack
push_c_addr: ; ( addr -- )
    loadw c_stack_ptr
    dup
    add 3
    storew c_stack_ptr
    storew
    ret

; Pops the top of the control stack back to the data stack
pop_c_addr: ; ( -- addr )
    loadw c_stack_ptr
    sub 3
    dup
    storew c_stack_ptr
    loadw
    ret

; Resolve the top address on the control stack to the current top of stack address
resolve_c_addr: ; ( heap-addr -- )
    loadw c_stack_ptr
    sub 3
    dup ; ( heap cstack-3 cstack-3 )
    storew c_stack_ptr
    loadw ; ( heap arg-addr )
    dup
    sub 1 ; ( heap arg-addr instr-addr )
    pick 2
    swap
    sub ; ( heap arg-addr offset )
    swap
    storew
    pop
    ret
