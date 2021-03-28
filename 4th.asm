; Magic numbers:
$PUSH: .equ 0
$JMPR: .equ 24
$CALL: .equ 25
$RET: .equ 26
$BRZ: .equ 27
$BRNZ: .equ 28

.org 0x400 ; start here
    setiv oninterrupt
    inton
stop:
    hlt

dupnz: ; if TOS is nonzero, dup it
    dup
    brz @dupnz_done
    dup
dupnz_done:
    ret

; We often need to pop 1-2 times and then ret, in a brnz / brz.
; Rather than repeat that everywhere, we'll abstract it and branch
; to one of these three:
end_pop3r: pop
end_pop2r: popr
end_pop2: pop
end_pop1: pop
end_ret: ret

; ...And this is like that, but returns 0 or 1:
end0_pop2: pop
end0_pop1: pop
end0_ret: ret 0
end1_pop2: pop
end1_pop1: pop
end1_ret: ret 1

; Print a null-term string
print: ; ( addr -- )
    dup
    load
    call dupnz
    brz @end_pop1
    store 0x02
    add 1
    jmpr @print



; Print a carriage return
cr: ; ( -- )
    push 10
    store 0x02
    ret



; Check whether two null terminated strings are equal
streq: ; ( str1 str2 -- bool )
    ; check if two chars are equal
    pick 1
    pick 1
    load
    swap
    load
    sub
    brnz @end0_pop2
    ; they're both equal, is either one zero?
    dup
    load
    brz @end1_pop2
    ; inc both pointers
    add 1
    swap
    add 1
    jmpr @streq




; Check whether two words (terminated by any non-word-character) are equal
wordeq: ; ( str1 str2 -- bool )
    ; check if both chars are nonword
    pick 1
    pick 1
    load
    call word_char
    swap
    load
    call word_char
    or
    brz @end1_pop2 ; both are nonword so we're done
    ; check if both chars are equal
    pick 1
    pick 1
    load
    swap
    load
    sub
    brnz @end0_pop2
    ; they're both equal, inc both pointers
    add 1
    swap
    add 1
    jmpr @wordeq





; advance a pointer to the next dictionary entry
advance_entry: ; ( ptr -- next_ptr )
    dup
    load ; ( ptr *ptr )
    brz @advance_entry_done
    add 1
    jmpr @advance_entry
advance_entry_done:
    add 4
    call dupnz
    brz @end0_ret
    loadw
    ret




; Find dictionary entry for word
find_in_dict: ; ( ptr dict -- addr )
    call dupnz
    brz @end0_pop1 ; not found
    pick 1
    pick 1
    call wordeq ; ( ptr dict eq? )
    brz @find_in_dict_next
    swap
    pop
    call skip_word
    add 1
    loadw
    ret
find_in_dict_next: ; ( ptr dict )
    call advance_entry
    jmpr @find_in_dict




tick:
    loadw dictionary
    call find_in_dict
    ret

compile_tick:
    loadw compile_dictionary
    call find_in_dict
    ret



; returns whether this character is a word char (nonzero) or a separator between words (space, cr, tab, control chars...)
word_char: ; ( ch -- bool )
    gt 32
    ret



is_digit: ; ( ch -- bool )
    dup
    gt 47 ; it's at least '0'
    swap
    lt 58 ; it's at most '9'
    and
    ret




; Tries to parse a number out of a string
is_number: ; ( ptr -- num valid? )
    pushr 0
is_number_loop:
    dup
    load
    call is_digit
    brz @is_number_bad
    dup
    load
    sub 48
    popr
    mul 10
    add
    pushr
    add 1
    dup
    load
    call word_char
    brz @is_number_done
    jmpr @is_number_loop
is_number_bad:
    popr
    pop
    ret 0
is_number_done:
    pop
    popr
    ret 1




;;;;;;;;;;;;;;;;;;



oninterrupt:
    dup
    sub 65
    brz @onkeypress
    inton ; this isn't an interrupt we recognize, not much we can do here except leave it on the stack and continue on
    hlt



onkeypress:
    pop ; we know the top value is a 65, because this is the isr for 65
    dup
    sub 10
    brz @onkeypress_handleline
    push line_buf
    load line_len
    add
    store
    load line_len
    add 1
    store line_len
onkeypress_done:
    inton
    ret
onkeypress_handleline:
    pop ; drop the newline
    ; null-term the line
    push 0
    push line_buf
    load line_len
    add
    store
    ; reset line_len
    push 0
    store line_len
    ; handle the now null-termed line
    call handleline
    jmpr @onkeypress_done




; Takes a pointer to the start of a word, returns a pointer to the
; first nonword-char after it
skip_word: ; ( ptr -- first-nonword )
    dup
    load ; ( ptr ch )
    call word_char
    brz @end_ret
    add 1
    jmpr @skip_word



; Takes a pointer to a nonword-char, returns a pointer to the
; first word-char after it, or the first zero / EOS
skip_nonword: ; ( ptr -- first-word )
    dup
    load ; ( ptr ch )
    call dupnz
    brz @end_ret
    call word_char
    brnz @end_ret
    add 1
    jmpr @skip_nonword



handleline: ; ( -- )
    push line_buf
    storew cursor
handleline_loop:
    call word_to_pad
    load pad
    brz @end_ret
    push pad
    loadw handleword_hook
    call
    jmpr @handleline_loop



; Copies the first word starting at / after the cursor from line_buf
; to the pad, and null-terminates it
word_to_pad: ; ( -- )
    loadw cursor
    call skip_nonword
    push pad
    push word_char
    call copy_string
    pop
    storew cursor
    ret


; returns true if the character is either zero or a quotation mark
until_double_quote: ; ( ch -- bool )
    dup
    xor 34 ; ascii double quote
    brz @until_double_quote_false
    swap 0
    brz @until_double_quote_false
    pop
    ret 1
until_double_quote_false:
    pop
    ret 0

; Reads from the input line a string, starting with the first word character after cursor
; and ending with a double quote. Copies it to the pad, null-terminates it, and
; advances cursor to right after the closing quote. Leaves on the stack the address of the
; null terminator, or a zero if the string is unclosed (in addition to printing an error)
read_quote_string: ; ( dest -- end-addr )
    loadw cursor
    call skip_nonword
    swap
    push until_double_quote
    call copy_string ; ( src-end dest-end )
    swap ; ( dest-end src-end )
    dup
    load
    brz @read_string_unclosed
    add 1
    storew cursor
    ret
read_string_unclosed:
    push unclosed_error
    call print
    push 0
    store line_buf
    push line_buf
    storew cursor
    jmpr @end0_pop2


dotquote:
    push pad
    call read_quote_string
    brz @end_ret
    push pad
    call print
    ret

; Copy a string to somewhere else, given a function to test whether a given
; character is the end of the string. Calls test for each character and copies
; each one for which it returns false, then adds a null terminator and returns
; the addresses of the first character it didn't copy in both buffers: for src,
; the address of the first test-true char; for dest, the address of the null
; terminator.
copy_string: ; ( src dest test -- src_end dest_end )
    pushr ; push the test fn to the return stack
copy_string_loop:
    pick 1
    load
    dup ; ( src dest ch ch )
    peekr
    call ; ( src dest ch valid? )
    brnz @copy_string_valid
    ; it's invalid, change it to write a zero instead
    pop
    push 0
copy_string_valid:
    ; it's valid, or we just made it a zero
    dup ; ( src dest ch ch )
    pick 2
    store ; ( src dest ch )
    brz @copy_string_done
    add 1
    swap
    add 1
    swap
    jmpr @copy_string_loop
copy_string_done:
    popr
    pop
    ret

; Makes a new dictionary entry for the word on the pad, with a null definition. Returns the
; address of the definition
word_to_dict: ; ( -- def-addr )
    push pad
    loadw heap_ptr
    push word_char
    call copy_string
    swap
    pop ; toss the src pointer
    add 1
    dup
    swap 0
    storew ; store the null definition ptr
    dup
    add 3
    loadw dictionary
    swap
    storew ; store the ptr to the dictionary
    loadw heap_ptr
    storew dictionary ; make dictionary point to thie
    dup
    add 6
    storew heap_ptr ; move the heap ptr forward
    ret



; Takes the word currently at the start of the pad, makes a dictionary entry for it, and points that
; definition at the current heap ptr
new_dict_from_pad:
    load pad
    brz @new_dict_from_pad_err ; Make sure we were actually given a name
    call word_to_dict ; stick the new word in the dictionary
    loadw heap_ptr
    swap
    storew ; Store the current heap_ptr as the definition
    ret
new_dict_from_pad_err:
    push expected_word_err
    call print
    call cr
    ret


colon_word:
    call word_to_pad
    call new_dict_from_pad
    call enter_compile_mode
    ret


semicolon_word:
    push $RET
    call compile_instruction
    call enter_interpret_mode
    ret


enter_compile_mode:
    push 1
    store current_mode
    push compileword
    storew handleword_hook
    ret



enter_interpret_mode:
    push 0
    store current_mode
    push handleword
    storew handleword_hook
    ret




compileword:
    ; first check for a blank word and skip:
    dup
    load
    brz @end_pop1 ; blank?
    ; Now call compile_tick to try to find it in the dictionary of special compiled words
    dup ; ( addr addr )
    call compile_tick ; ( addr entry-addr )
    call dupnz
    brnz @compileword_compiled_found ; found something
    ; wasn't there, call normal tick to try to find it in the dictionary
    dup ; ( addr addr )
    call tick ; ( addr entry-addr )
    call dupnz
    brnz @compileword_found ; found something
    ; It wasn't in the dictionary, is it a number?
    dup
    call is_number
    brnz @compileword_number
    ; It wasn't a number either, drop the garbage:
    pop
    ; And complain:
    call missing_word
    ret
compileword_compiled_found:
    swap
    pop
    call
    ret
compileword_found:
    swap
    pop
    push $CALL
    call compile_instruction_arg
    ret
compileword_number:
    swap
    pop
    push $PUSH
    call compile_instruction_arg
    ret




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




compile_instruction: ; ( opcode -- )
    lshift 2
    loadw heap_ptr ; ( instr-byte heap_ptr )
    dup
    add 1
    storew heap_ptr ; Increment the ptr ( instr-byte heap_ptr )
    store
    ret




handleword: ; ( <args for word> word-start-addr -- <word return stack> )
    ; first check for a blank word and skip:
    dup
    load
    brz @end_pop1 ; blank?
    ; Now call tick to try to find it in the dictionary
    dup ; ( addr addr )
    call tick ; ( addr entry-addr )
    call dupnz
    brnz @handleword_found ; found something
    ; It wasn't in the dictionary, is it a number?
    dup
    call is_number
    brnz @handleword_number
    ; It wasn't a number either, drop the garbage:
    pop
    ; And complain:
    call missing_word
    ret
handleword_found:
    swap
    pop
    call
    ret
handleword_number:
    swap
    pop
    ret

;;;;;;;;;;;;;;;;;;

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
free: ; ( num -- )
    loadw heap_ptr
    swap
    sub
    storew heap_ptr
    ret




itoa: ; ( num -- )
    push 32
    call allot
    dup
    swap 0
    store
    add 1
    pushr
itoa_loop:
    dup ; ( num num ) [ arr ]
    mod 10
    dup
    add 48 ; ( num mod ch )
    peekr ; ( num mod ch arr ) [ arr ]
    store
    popr ; ( num mod arr ) [ ]
    add 1
    pushr ; ( num mod ) [ arr+1 ]
    sub
    div 10
    dup
    brnz @itoa_loop
    pop
    ; Got the array of digits in reverse order, print them out:
    popr
    sub 1
itoa_print_loop:
    dup
    load
    store 2
    sub 1
    dup
    load
    brnz @itoa_print_loop
    pop
    push 32
    call free
    ret

foo:
    push foo_str
    call print
    call cr
    ret

bar:
    push bar_str
    call print
    call cr
    ret

putc:
    store 2
    ret

pad_word: push pad
    ret

w_add: add
    ret

w_sub: sub
    ret

w_mul: mul
    ret

w_div: div
    ret

w_mod: mod
    ret

w_eq: xor
    not
    ret

w_gt: gt
    ret

w_lt: lt
    ret

w_at: loadw
    ret

w_set: storew
    ret

w_inc:
    dup
    pushr
    loadw
    add
    popr
    storew
    ret

w_byte_at: load
    ret

w_byte_set: store
    ret

w_byte_inc:
    dup
    pushr
    load
    add
    popr
    store
    ret

w_dup: dup
    ret

w_dup2:
    pick 1
    pick 1
    ret

missing_word:
    push missing_word_str
    call print
    call print
    call cr
    ret



; Pushes an address of an unresolved pointer to the control stack
push_c_addr: ; ( addr -- )
    loadw c_stack_ptr
    dup
    add 3
    storew c_stack_ptr
    storew
    ret


; Pushes an address of an unresolved pointer to the control stack
pop_c_addr: ; ( -- addr )
    loadw c_stack_ptr
    sub 3
    dup
    storew c_stack_ptr
    loadw
    ret



push_jump: ; ( opcode -- )
    push 0
    swap
    call compile_instruction_arg
    loadw heap_ptr
    sub 3
    call push_c_addr
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



; A normal branch-if-zero to wherever the 'then' or 'else' ends up
if_word:
    push $BRZ
    call push_jump
    ret

; An unconditional jump to the next 'then', followed by targeting the
; previous 'if'
else_word:
    loadw heap_ptr
    add 4
    call resolve_c_addr
    push $JMPR
    call push_jump
    ret

; Resolve the last address to jump here
then_word:
    loadw heap_ptr
    call resolve_c_addr
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

begin_word:
    loadw heap_ptr
    call push_c_addr
    ret

again_word:
    call pop_c_addr
    loadw heap_ptr
    sub
    push $JMPR
    call compile_instruction_arg
    ret

exit_word:
    push $RET
    call compile_instruction
    ret

until_word:
    call pop_c_addr
    loadw heap_ptr
    sub
    push $BRZ
    call compile_instruction_arg
    ret

while_word:
    ; Compile an unresolved brz
    push $BRZ
    call push_jump
    ret

repeat_word:
    ; temporarily store while's thing
    call pop_c_addr
    pushr
    ; Now top of c stack is the begin, so, jmpr to that
    call pop_c_addr
    loadw heap_ptr
    sub
    push $JMPR
    call compile_instruction_arg
    ; put while's thing back
    popr
    call push_c_addr
    ; resolve while's brz:
    loadw heap_ptr
    call resolve_c_addr
    ret

; This takes a name (word_to_pad / new_dict_from_pad, just like colon_word) and
; creates a word for it that, when called, pushes the address of a variable to the stack.
; That address is the byte right after the word itself, and there are three bytes reserved
; there. It also initializes the variable to zero.
variable_word:
    call word_to_pad
    call new_dict_from_pad
    loadw heap_ptr
    add 5 ; 4 bytes for the push, 1 bytes for the ret
    push $PUSH
    call compile_instruction_arg
    push $RET
    call compile_instruction
    loadw heap_ptr
    dup
    add 3
    storew heap_ptr
    swap 0
    storew
    ret

;;;;;;;;;;;;;;;;;;

missing_word_str: .db "That word wasn't found: \0"
unclosed_error: .db "Unclosed string\0"
expected_word_err: .db "Expected name, found end of input\0"
foo_str: .db "You called foo\0"
bar_str: .db "Bar was called, probably by you!\0"

;;;;;;;;;;;;;;;;;;

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
.db d_semicolon

d_semicolon: .db ";\0"
.db semicolon_word
.db 0 ; sentinel for end of dictionary

;;;;;;;;;;;;;;;;;;

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
.db d_dup2

d_dup2: .db "dup2\0"
.db w_dup2
.db d_dupnz

d_dupnz: .db "dup?\0"
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
.db 0

; Assorted support variables
heap_ptr: .db heap_start ; holds the address in which to start the next heap entry
current_mode: .db 0 ; 0 for interpreter ("calculator") mode, 1 for compile mode
handleword_hook: .db handleword ; The current function used to handle / compile words, switches based on mode
line_len: .db 0
cursor: .db 0 ; During calls to handleword, this global points to the beginning of the word

; pointer to head of dictionary
dictionary: .db d_foo

; words only available while compiling and which take precedence over the normal dict in that case
compile_dictionary: .db d_if

; A buffer for line input
line_buf: .db 0
.org line_buf + 0x100

; Scratch pad buffer
pad: .db 0
.org pad + 0x100

; A stack for compiling control structures
c_stack_ptr: .db c_stack
c_stack: .db 0
.org c_stack + 96

heap_start: