; Assumes there's currently a word on the heap, writes two pointers after it: one to the (new) heap,
; and one to the current dictionary head. Then makes the dictionary point at the start of that word.
; This is usually used as: call word_to_heap, call new_dict, and you have added that word to the
; dictionary pointing at the new heap start.
new_dict:
    loadw heap
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
    loadw heap
    storew dictionary ; point the dictionary at it
    add 6
    storew heap ; advance the heap ptr
    ret
new_dict_error:
    pop
    push expected_word_err
    call print
    call cr
    ret

; Compiles a full 4-byte instruction to the heap given an arg and an opcode
compile_instruction_arg: ; ( arg opcode -- )
    lshift 2
    or 3 ; tell it we have a three byte arg
    loadw heap ; ( arg instr-byte heap )
    dup
    add 4
    storew heap ; Increment the ptr ( arg instr-byte heap )
    pick 1
    pick 1
    store
    add 1
    swap
    pop ; ( arg heap+1 )
    storew
    ret

; Compiles an argument-less 1-byte instruction to the heap
compile_instruction: ; ( opcode -- )
    lshift 2
    loadw heap ; ( instr-byte heap )
    dup
    add 1
    storew heap ; Increment the ptr ( instr-byte heap )
    store
    ret

; Compiles an instruction with an unresolved argument to the heap. Usually used
; for compiling jumps / branches
push_jump: ; ( opcode -- )
    swap 0
    call compile_instruction_arg
    loadw heap
    sub 3
    jmp nova_pushr

; Resolve the top arg-address on the control stack to the current heap addr. Meaning,
; write the relative value of the current heap to that address
nova_resolve: ; ( -- )
    loadw heap
    loadw r_stack_ptr
    sub 3
    dup ; ( heap cstack-3 cstack-3 )
    storew r_stack_ptr
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
