;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial compile word dictionary:

d_if: .db "if\0"
.db if_word
.db d_then

d_then: .db "then\0"
.db then_word
.db d_else

d_else: .db "else\0"
.db else_word
.db d_compile_squote

d_compile_squote: .db "s\"\0"
.db compile_squote
.db d_compile_dotquote

d_compile_dotquote: .db ".\"\0"
.db compile_dotquote
.db d_begin

d_begin: .db "begin\0"
.db begin_word
.db d_again

d_again: .db "again\0"
.db again_word
.db d_exit

d_exit: .db "exit\0"
.db exit_word
.db d_until

d_until: .db "until\0"
.db until_word
.db d_while

d_while: .db "while\0"
.db while_word
.db d_repeat

d_repeat: .db "repeat\0"
.db repeat_word
.db d_do

d_do: .db "do\0"
.db do_word
.db d_pretest_do

d_pretest_do: .db "?do\0"
.db pretest_do_word
.db d_loop

d_loop: .db "loop\0"
.db loop_word
.db d_plusloop

d_plusloop: .db "+loop\0"
.db plusloop_word
.db d_open_bracket

d_open_bracket: .db "[\0"
.db open_bracket_word
.db d_does

d_does: .db "does>\0"
.db does_word
.db d_postpone

d_postpone: .db "postpone\0"
.db postpone_word
.db d_literal

d_literal: .db "literal\0"
.db literal_word
.db d_recurse

d_recurse: .db "recurse\0"
.db recurse_word
.db d_bracket_tick

d_bracket_tick: .db "[']\0"
.db compile_tick_word
.db d_semicolon

d_semicolon: .db ";\0"
.db semicolon_word
.db 0 ; sentinel for end of dictionary

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The initial runtime word dictionary:

d_foo: .db "foo\0"
.db foo
.db d_bar

d_bar: .db "bar\0"
.db bar
.db d_emit

d_emit: .db "emit\0"
.db putc
.db d_pad

d_pad: .db "pad\0"
.db pad_word
.db d_word

d_word: .db "word\0"
.db 0
.db d_dot

d_dot: .db ".\0"
.db itoa
.db d_cr

d_cr: .db "cr\0"
.db cr
.db d_plus

d_plus: .db "+\0"
.db w_add
.db d_minus

d_minus: .db "-\0"
.db w_sub
.db d_times

d_times: .db "*\0"
.db w_mul
.db d_slash

d_slash: .db "/\0"
.db w_div
.db d_mod

d_mod: .db "mod\0"
.db w_mod
.db d_eq

d_eq: .db "=\0"
.db w_eq
.db d_lt

d_lt: .db "<\0"
.db w_lt
.db d_gt

d_gt: .db ">\0"
.db w_gt
.db d_at

d_at: .db "@\0"
.db w_at
.db d_set

d_set: .db "!\0"
.db w_set
.db d_inc

d_inc: .db "+!\0"
.db w_inc
.db d_byte_at

d_byte_at: .db "c@\0"
.db w_byte_at
.db d_byte_set

d_byte_set: .db "c!\0"
.db w_byte_set
.db d_byte_inc

d_byte_inc: .db "c+!\0"
.db w_byte_inc
.db d_dup

d_dup: .db "dup\0"
.db w_dup
.db d_drop

d_drop: .db "drop\0"
.db w_drop
.db d_dup2

d_dup2: .db "dup2\0"
.db w_dup2
.db d_dupnz

d_dupnz: .db "?dup\0"
.db dupnz
.db d_dotquote

d_dotquote: .db ".\"\0"
.db dotquote
.db d_squote

d_squote: .db "s\"\0"
.db squote
.db d_colon

d_colon: .db ":\0"
.db colon_word
.db d_allot

d_allot: .db "allot\0"
.db allot
.db d_free

d_free: .db "free\0"
.db free
.db d_variable

d_variable: .db "variable\0"
.db variable_word
.db d_to_r

d_to_r: .db ">r\0"
.db push_c_addr
.db d_from_r

d_from_r: .db "r>\0"
.db pop_c_addr
.db d_peek_r

d_peek_r: .db "r@\0"
.db w_peek_r
.db d_rdrop

d_rdrop: .db "rdrop\0"
.db w_rdrop
.db d_rpick

d_rpick: .db "rpick\0"
.db w_rpick
.db d_unloop

d_unloop: .db "unloop\0"
.db unloop_word
.db d_leave

d_leave: .db "leave\0"
.db leave_word
.db d_close_bracket

d_close_bracket: .db "]\0"
.db close_bracket_word
.db d_create

d_create: .db "create\0"
.db create_word
.db d_comma

d_comma: .db ",\0"
.db comma_word
.db d_execute

d_execute: .db "execute\0"
.db w_execute
.db d_tick

d_tick: .db "'\0"
.db tick_word
.db d_immediate

d_immediate: .db "immediate\0"
.db immediate_word
.db 0
