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
