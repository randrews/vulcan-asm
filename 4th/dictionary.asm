;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial compile word dictionary:

compile_dict_start:

.db "exit\0"
.db nova_exit
.db $+1

.db "[\0"
.db nova_open_bracket
.db $+1

.db "continue\0"
.db nova_continue
.db $+1

.db "does>\0"
.db does_word
.db $+1

.db "postpone\0"
.db nova_postpone
.db $+1

.db "[']\0"
.db nova_bracket_tick
.db $+1

.db "literal\0"
.db nova_literal
.db $+1

.db ";\0"
.db nova_semicolon
.db $+1

.db "s\"\0"
.db nova_compile_squote
.db $+1

.db ".\"\0"
.db nova_compile_dotquote
.db $+1

.db "$\0"
.db nova_compile_opcode
.db $+1

.db "{\0"
.db nova_compile_open_brace
.db $+1

.db "}\0"
.db nova_close_brace
.db $+1

.db "\\\0"
.db backslash
.db $+1

.db "(\0"
.db open_paren
.db $+1

.db ")\0"
.db close_paren_stub
.db 0 ; Sentinel for end of dictionary

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial runtime word dictionary:

dict_start:

; First, a bunch of single-opcode words. These are here
; even though they could be created in a prelude, simply
; because it's shorter to define them here:
.db "+\0"
.db $+2
.db $+3
add
ret

.db "-\0"
.db $+2
.db $+3
sub
ret

.db "*\0"
.db $+2
.db $+3
mul
ret

.db "/\0"
.db $+2
.db $+3
div
ret

.db "%\0"
.db $+2
.db $+3
mod
ret

.db "pop\0"
.db $+2
.db $+3
pop
ret

.db "dup\0"
.db $+2
.db $+3
dup
ret

.db "swap\0"
.db $+2
.db $+3
swap
ret

.db "pick\0"
.db $+2
.db $+3
pick
ret

.db "rot\0"
.db $+2
.db $+3
rot
ret

.db "@\0"
.db $+2
.db $+3
loadw
ret

.db "!\0"
.db $+2
.db $+3
storew
ret

.db "c@\0"
.db $+2
.db $+3
load
ret

.db "c!\0"
.db $+2
.db $+3
store
ret

.db ">\0"
.db $+2
.db $+3
agt
ret

.db "<\0"
.db $+2
.db $+3
alt
ret

.db "=\0"
.db $+2
.db $+4
xor
not
ret

.db "&\0"
.db $+2
.db $+3
and
ret

.db "|\0"
.db $+2
.db $+3
or
ret

.db "^\0"
.db $+2
.db $+3
xor
ret

.db "not\0"
.db $+2
.db $+3
not
ret

.db "execute\0"
.db $+2
.db $+2
jmp

; Now the normal builtin, atomic words:
.db "]\0"
.db nova_close_bracket
.db $+1

.db "create\0"
.db nova_create
.db $+1

.db ",\0"
.db nova_comma
.db $+1

.db "'\0"
.db nova_tick
.db $+1

.db ":\0"
.db nova_colon
.db $+1

.db "immediate\0"
.db nova_immediate
.db $+1

.db "$\0"
.db nova_opcode
.db $+1

.db "asm\0"
.db compile_instruction
.db $+1

.db "#asm\0"
.db compile_instruction_arg
.db $+1

.db ">asm\0"
.db nova_asm_to
.db $+1

.db "word\0"
.db nova_word_to_pad
.db $+1

.db "pad\0"
.db $+2
.db $+2
ret pad

.db "number\0"
.db nova_number
.db $+1

.db "hex\0"
.db nova_hex
.db $+1

.db "dec\0"
.db nova_dec
.db $+1

.db "?dup\0"
.db dupnz
.db $+1

.db ".\0"
.db print_number
.db $+1

.db "s\"\0"
.db nova_squote
.db $+1

.db ".\"\0"
.db nova_dotquote
.db $+1

.db "emit\0"
.db nova_emit
.db $+1

.db "print\0"
.db print
.db $+1

.db "compare\0"
.db compare
.db $+1

.db ".s\0"
.db nova_print_stack
.db $+1

.db ">r\0"
.db nova_pushr
.db $+1

.db "r>\0"
.db nova_popr
.db $+1

.db "r@\0"
.db nova_peekr
.db $+1

.db "rpick\0"
.db nova_rpick
.db $+1

.db "&heap\0"
.db $+2
.db $+2
ret heap

.db "here\0"
.db nova_here
.db $+1

.db "resolve\0"
.db nova_resolve
.db $+1

.db "{\0"
.db nova_immediate_open_brace
.db $+1

.db "quit\0"
.db quit
.db $+1

.db "\\\0"
.db backslash
.db $+1

.db "(\0"
.db open_paren
.db $+1

.db ")\0"
.db close_paren_stub
.db 0
