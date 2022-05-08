;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial compile word dictionary:

compile_dict_start:
;;;;; .db "s\"\0"
;;;;; .db compile_squote
;;;;; .db $+1
;;;;; 
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

.db "exit\0"
.db nova_exit
.db $+1

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

.db "[\0"
.db nova_open_bracket
.db $+1

.db "continue\0"
.db nova_continue
.db $+1

;;;;; .db "does>\0"
;;;;; .db does_word
;;;;; .db $+1

.db "postpone\0"
.db nova_postpone
.db $+1

;;;;; .db "continue\0"
;;;;; .db continue_word
;;;;; .db $+1
;;;;; 
;;;;; .db "literal\0"
;;;;; .db literal_word
;;;;; .db $+1
;;;;; 
;;;;; .db "[']\0"
;;;;; .db compile_tick_word
;;;;; .db $+1
;;;;; 
;;;;; .db "\\\0"
;;;;; .db backslash_word
;;;;; .db $+1
;;;;; 
;;;;; .db "(\0"
;;;;; .db open_paren_word
;;;;; .db $+1

.db ")\0"
.db close_paren_stub
.db 0 ; Sentinel for end of dictionary

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial runtime word dictionary:

dict_start:
;;;;; .db "pad\0"
;;;;; .db $+2
;;;;; .db $+2
;;;;; ret pad
;;;;; 
;;;;; .db "word\0"
;;;;; .db $+2
;;;;; .db $+4
;;;;; call word_to_pad
;;;;; push pad
;;;;; ret
;;;;; 
;;;;; .db "number\0"
;;;;; .db input_number
;;;;; .db $+1
;;;;; 
;;;;; .db ".\0"
;;;;; .db print_number
;;;;; .db $+1
;;;;; 
;;;;; .db "compare\0"
;;;;; .db compare
;;;;; .db $+1
;;;;; 
;;;;; .db "?dup\0"
;;;;; .db dupnz
;;;;; .db $+1
;;;;; 
;;;;; .db ".\"\0"
;;;;; .db dotquote
;;;;; .db $+1
;;;;; 
;;;;; .db "s\"\0"
;;;;; .db squote
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

.db "]\0"
.db nova_close_bracket
.db $+1

.db "create\0"
.db nova_create
.db $+1

;;;;; .db ",\0"
;;;;; .db comma_word
;;;;; .db $+1
;;;;; 
;;;;; .db "'\0"
;;;;; .db tick_word
;;;;; .db $+1

.db "immediate\0"
.db nova_immediate
.db $+1

.db "asm\0"
.db compile_instruction
.db $+1

;;;;; .db "depth\0"
;;;;; .db $+2
;;;;; .db $+7
;;;;; sdp ; TODO this depends on a 0x100-based stack; if we ever do `setsdp` this will be wrong
;;;;; swap
;;;;; pop
;;;;; sub 256 + 3 * 2 ; The two additional cells are the two new ones `sdp` added
;;;;; div 3
;;;;; ret
;;;;; 
;;;;; .db "rdepth\0"
;;;;; .db $+2
;;;;; .db $+5
;;;;; loadw c_stack_ptr
;;;;; sub c_stack
;;;;; div 3
;;;;; ret
;;;;; 
;;;;; .db "here\0"
;;;;; .db $+2
;;;;; .db $+3
;;;;; loadw heap_ptr
;;;;; ret
;;;;; 
;;;;; .db "hex\0"
;;;;; .db $+2
;;;;; .db $+6
;;;;; push hex_is_number
;;;;; storew is_number_hook
;;;;; push hex_itoa
;;;;; storew itoa_hook
;;;;; ret
;;;;; 
;;;;; .db "dec\0"
;;;;; .db $+2
;;;;; .db $+6
;;;;; push is_number
;;;;; storew is_number_hook
;;;;; push itoa
;;;;; storew itoa_hook
;;;;; ret
;;;;; 
;;;;; .db ".s\0"
;;;;; .db print_stack
;;;;; .db $+1
;;;;; 
;;;;; .db "print\0"
;;;;; .db print
;;;;; .db $+1
;;;;; 
;;;;; .db "\\\0"
;;;;; .db backslash_word
;;;;; .db $+1
;;;;; 
;;;;; .db "(\0"
;;;;; .db open_paren_word
;;;;; .db $+1

.db ")\0"
.db close_paren_stub
.db 0

; Store the current handleword_hook in the C stack,
; put linecomment in its place. When handleline starts,
; if it sees that handleword_hook is linecomment, it'll
; pop the old one back out.
backslash_word:
    loadw handleword_hook
    call push_c_addr
    push linecomment
    storew handleword_hook
    ret

; Store the current handleword_hook in the C stack,
; put parencomment in its place.
open_paren_word:
    loadw handleword_hook
    call push_c_addr
    push parencomment
    storew handleword_hook
    ret

; Store the current handleword_hook in the C stack,
; put parencomment in its place.
; We also have a "stub" word which is what the dict actually
; points to, so that a mismatched close paren doesn't end
; up actually doing anything (it's only callable from / by
; parencomment)
close_paren_word:
    call pop_c_addr
    storew handleword_hook
close_paren_stub:
    ret
