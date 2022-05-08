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

.db "\\\0"
.db backslash
.db $+1

.db "(\0"
.db open_paren
.db $+1

.db ")\0"
.db close_paren_stub
.db 0 ; Sentinel for end of dictionary

;;;;; .db ".\"\0"
;;;;; .db compile_dotquote
;;;;; .db $+1
;;;;; 
;;;;; .db "begin\0"
;;;;; .db begin_word
;;;;; .db $+1
;;;;; 
;;;;; .db "again\0"
;;;;; .db again_word
;;;;; .db $+1
;;;;;
;;;;; .db "until\0"
;;;;; .db until_word
;;;;; .db $+1
;;;;; 
;;;;; .db "while\0"
;;;;; .db while_word
;;;;; .db $+1
;;;;; 
;;;;; .db "repeat\0"
;;;;; .db repeat_word
;;;;; .db $+1
;;;;; 
;;;;; .db "do\0"
;;;;; .db do_word
;;;;; .db $+1
;;;;; 
;;;;; .db "?do\0"
;;;;; .db pretest_do_word
;;;;; .db $+1
;;;;; 
;;;;; .db "loop\0"
;;;;; .db loop_word
;;;;; .db $+1
;;;;; 
;;;;; .db "+loop\0"
;;;;; .db plusloop_word
;;;;; .db $+1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial runtime word dictionary:

dict_start:
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

.db "asm\0"
.db nova_asm
.db $+1

.db "#asm\0"
.db nova_arg_asm
.db $+1

.db "pad\0"
.db $+2
.db $+2
ret pad

.db "word\0"
.db nova_word_to_pad
.db $+1

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

.db "\\\0"
.db backslash
.db $+1

.db "(\0"
.db open_paren
.db $+1

.db ")\0"
.db close_paren_stub
.db 0

;;;;; .db "compare\0"
;;;;; .db compare
;;;;; .db $+1
;;;;; 
;;;;; .db ".\"\0"
;;;;; .db dotquote
;;;;; .db $+1
;;;;; 
;;;;; .db ">r\0"
;;;;; .db push_c_addr
;;;;; .db $+1
;;;;; 
;;;;; .db "r>\0"
;;;;; .db pop_c_addr
;;;;; .db $+1
;;;;; 
;;;;; .db "r@\0"
;;;;; .db w_peek_r
;;;;; .db $+1
;;;;; 
;;;;; .db "rpick\0"
;;;;; .db w_rpick
;;;;; .db $+1
;;;;;
;;;;; .db "here\0"
;;;;; .db $+2
;;;;; .db $+3
;;;;; loadw heap_ptr
;;;;; ret
;;;;; 
;;;;; .db ".s\0"
;;;;; .db print_stack
;;;;; .db $+1
;;;;; 
;;;;; .db "print\0"
;;;;; .db print
;;;;; .db $+1
