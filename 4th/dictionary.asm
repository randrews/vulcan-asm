;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial compile word dictionary:

d_if: .db "if\0"
.db if_word
.db $+1

.db "then\0"
.db then_word
.db $+1

.db "else\0"
.db else_word
.db $+1

.db "s\"\0"
.db compile_squote
.db $+1

.db ".\"\0"
.db compile_dotquote
.db $+1

.db "begin\0"
.db begin_word
.db $+1

.db "again\0"
.db again_word
.db $+1

.db "exit\0"
.db exit_word
.db $+1

.db "until\0"
.db until_word
.db $+1

.db "while\0"
.db while_word
.db $+1

.db "repeat\0"
.db repeat_word
.db $+1

.db "do\0"
.db do_word
.db $+1

.db "?do\0"
.db pretest_do_word
.db $+1

.db "loop\0"
.db loop_word
.db $+1

.db "+loop\0"
.db plusloop_word
.db $+1

.db "[\0"
.db open_bracket_word
.db $+1

.db "does>\0"
.db does_word
.db $+1

.db "postpone\0"
.db postpone_word
.db $+1

.db "literal\0"
.db literal_word
.db $+1

.db "recurse\0"
.db recurse_word
.db $+1

.db "[']\0"
.db compile_tick_word
.db $+1

.db "\\\0"
.db backslash_word
.db $+1

.db "(\0"
.db open_paren_word
.db $+1

.db ")\0"
.db close_paren_stub
.db $+1

.db ";\0"
.db semicolon_word
.db 0 ; sentinel for end of dictionary

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial runtime word dictionary:

d_foo: .db "foo\0"
.db foo
.db $+1

d_bar: .db "bar\0"
.db bar
.db $+1

.db "emit\0"
.db putc
.db $+1

.db "pad\0"
.db pad_word
.db $+1

.db "word\0"
.db 0
.db $+1

.db ".\0"
.db print_number
.db $+1

.db "cr\0"
.db cr
.db $+1

.db "+\0"
.db w_add
.db $+1

.db "-\0"
.db w_sub
.db $+1

.db "*\0"
.db w_mul
.db $+1

.db "/\0"
.db w_div
.db $+1

.db "mod\0"
.db w_mod
.db $+1

.db "=\0"
.db w_eq
.db $+1

.db "<\0"
.db w_alt
.db $+1

.db ">\0"
.db w_agt
.db $+1

.db "u<\0"
.db w_lt
.db $+1

.db "u>\0"
.db w_gt
.db $+1

.db "u<=\0"
.db $+2
.db $+4
gt
not
ret

.db "u>=\0"
.db $+2
.db $+4
lt
not
ret

.db "<=\0"
.db $+2
.db $+4
agt
not
ret

.db ">=\0"
.db $+2
.db $+4
alt
not
ret

.db "0>\0"
.db $+2
.db $+4
alt 0
not
ret

.db "0<\0"
.db $+2
.db $+3
alt 0
ret

.db "0=\0"
.db $+2
.db $+3
not
ret

.db "!=\0"
.db $+2
.db $+5
xor
not
not
ret

.db "@\0"
.db w_at
.db $+1

.db "!\0"
.db w_set
.db $+1

.db "+!\0"
.db w_inc
.db $+1

.db "c@\0"
.db w_byte_at
.db $+1

.db "c!\0"
.db w_byte_set
.db $+1

.db "c+!\0"
.db w_byte_inc
.db $+1

.db "dup\0"
.db w_dup
.db $+1

.db "drop\0"
.db w_drop
.db $+1

.db "dup2\0"
.db w_dup2
.db $+1

.db "?dup\0"
.db dupnz
.db $+1

.db ".\"\0"
.db dotquote
.db $+1

.db "s\"\0"
.db squote
.db $+1

.db ":\0"
.db colon_word
.db $+1

.db "allot\0"
.db allot
.db $+1

.db "free\0"
.db free
.db $+1

.db "variable\0"
.db variable_word
.db $+1

.db ">r\0"
.db push_c_addr
.db $+1

.db "r>\0"
.db pop_c_addr
.db $+1

.db "r@\0"
.db w_peek_r
.db $+1

.db "rdrop\0"
.db w_rdrop
.db $+1

.db "rpick\0"
.db w_rpick
.db $+1

.db "unloop\0"
.db unloop_word
.db $+1

.db "leave\0"
.db leave_word
.db $+1

.db "]\0"
.db close_bracket_word
.db $+1

.db "create\0"
.db create_word
.db $+1

.db ",\0"
.db comma_word
.db $+1

.db "execute\0"
.db w_execute
.db $+1

.db "'\0"
.db tick_word
.db $+1

.db "immediate\0"
.db immediate_word
.db $+1

.db "negate\0"
.db w_negate
.db $+1

.db "abs\0"
.db w_abs
.db $+1

.db "nip\0"
.db $+2
.db $+4
swap
pop
ret

.db "rot\0"
.db $+2
.db $+3
rot
ret

.db "-rot\0"
.db $+2
.db $+4
rot
rot
ret

.db "swap\0"
.db $+2
.db $+3
swap
ret

.db "tuck\0"
.db $+2
.db $+5
dup
rot
rot
ret

.db "over\0"
.db $+2
.db $+3
pick 1
ret

.db "pick\0"
.db $+2
.db $+3
pick
ret

.db "depth\0"
.db $+2
.db $+7
sdp ; TODO this depends on a 0x100-based stack; if we ever do `setsdp` this will be wrong
swap
pop
sub 256 + 3 * 2 ; The two additional cells are the two new ones `sdp` added
div 3
ret

.db "rdepth\0"
.db $+2
.db $+5
loadw c_stack_ptr
sub c_stack
div 3
ret

.db "here\0"
.db $+2
.db $+3
loadw heap_ptr
ret

.db "hex\0"
.db $+2
.db $+6
push hex_is_number
storew is_number_hook
push hex_itoa
storew itoa_hook
ret

.db "dec\0"
.db $+2
.db $+6
push is_number
storew is_number_hook
push itoa
storew itoa_hook
ret

.db ".s\0"
.db print_stack
.db $+1

.db "\\\0"
.db backslash_word
.db $+1

.db "(\0"
.db open_paren_word
.db $+1

.db ")\0"
.db close_paren_stub
.db $+1

.db "even\0"
.db $+2
.db $+4
and 1
not
ret

.db "2-\0"
.db $+2
.db $+3
sub 2
ret

.db "1-\0"
.db $+2
.db $+3
sub 1
ret

.db "2+\0"
.db $+2
.db $+3
add 2
ret

.db "1+\0"
.db $+2
.db $+3
add 1
ret

.db "arshift\0"
.db $+2
.db $+3
arshift
ret

.db "rshift\0"
.db $+2
.db $+3
rshift
ret

.db "lshift\0"
.db $+2
.db 0
lshift
ret
