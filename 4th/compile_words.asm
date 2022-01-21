#include "loops.asm"

; The s-quote equivalent in compile mode:
compile_squote:
    push $JMPR
    call push_jump ; compile a jmpr to get us past the string
    call squote ; ( addr )
    loadw heap_ptr
    call resolve_c_addr ; Jump to right after the null-terminator
    ; compile a push with the string start
    push $PUSH ; ( addr $push )
    call compile_instruction_arg
    ret

; The dot-quote equivalent in compile mode:
compile_dotquote:
    call compile_squote
    ; compile a call to print
    push print
    push $CALL
    call compile_instruction_arg
    ret

; Compile a ret, for an early return (to escape from a begin / again maybe)
exit_word:
    push $RET
    call compile_instruction
    ret

; compile-time word, causes the next word to be compiled instead of it
; being run. The corollary of that is that an immediate word, where we
; would normally run it (because we're in compile mode) we compile a call
; to it; a non-immediate word, we compile some code that will compile a
; call to it. For example: compiling "postpone emit" should result in
; push <emit>
; push $CALL
; call compile_instruction_arg
; ...being compiled into the current defn because when run that will
; compile a call to emit. But "postpone do" causes a call to "do" to be
; compiled, because when run that will call "do" (whereas normally we'd
; just call "do" right now because it's immediate).
postpone_word:
    call word_to_heap
    loadw heap_ptr
    call tick
    call dupnz
    brz @postpone_word_immediate
    ; we have a word, it's a valid normal word, its call addr is at top of stack
    push $PUSH
    call compile_instruction_arg ; compile a push of that address
    push $CALL
    push $PUSH
    call compile_instruction_arg ; compile a push of $CALL
    push compile_instruction_arg
    push $CALL
    call compile_instruction_arg ; compile a push of compile_instruction_arg
    ret
postpone_word_immediate:
    ; Uh oh, this wasn't in the dictionary. Let's check the compile dictionary in
    ; case it's an immediate word:
    loadw heap_ptr
    call compile_tick
    call dupnz
    brnz @postpone_word_found_immediate
    ; Oh dear, it wasn't in either dictionary, time to error out:
    loadw heap_ptr
    jmp missing_word_str
postpone_word_found_immediate:
    ; It was in the compile dictionary so we're going to compile a call to it.
    push $CALL
    jmp compile_instruction_arg

; Immediate is a runtime word that moves the most recently defined word from the
; runtime dictionary to the compile-time one.
immediate_word:
    loadw dictionary
    dup ; save a copy, we'll need to set compile_dictionary to this later
    call skip_word
    add 4 ; now we're pointing at the next word, meaning, the new dictionary ptr:
    dup
    loadw
    storew dictionary ; dictionary is now pointing at the right place
    loadw compile_dictionary
    swap
    storew ; This definition is now pointing at the old compile_dictionary
    storew compile_dictionary ; and compile_dictionary is pointing at it!
    ret

; Compile-time word that reads a word from the stack at compile time and pushes it
; to the stack at runtime (which is to say, read a word at compile and compile a
; $PUSH of that word
literal_word:
    push $PUSH
    call compile_instruction_arg
    ret

compile_tick_word:
    call word_to_heap
    loadw heap_ptr
    call tick
    push $PUSH
    jmp compile_instruction_arg

; Reads a word from either dictionary (but preferentially the runtime one) and
; compiles a jmp to that word. This can be used to create a tail-call but is
; also required to define semicolon
continue_word:
    call word_to_heap
    loadw heap_ptr
    call compile_tick
    call dupnz
    #if
    jmpr @continue_compile
    #else
    loadw heap_ptr
    call tick
    call dupnz
    #if
    jmpr @continue_compile
    #else
    jmp missing_word_str
    #end
    #end
continue_compile:
    push $JMP
    call compile_instruction_arg ; compile a jmp to that word
    ret
