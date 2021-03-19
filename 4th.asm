; Magic numbers:
$CALL: .equ 26
$PUSH: .equ 0
$RET: .equ 27

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



dupz: ; if TOS is zero, dup it
    dup
    brnz @dupz_done
    dup
dupz_done:
    ret




; Print a null-term string
print: ; ( addr -- )
    dup
    load
    call dupnz
    brz @print_done
    store 0x02
    add 1
    jmpr @print
print_done:
    pop
    ret



; Print a carriage return
cr: ; ( -- )
    push 10
    store 0x02
    ret



; Check whether two null terminated strings are equal
streq: ; ( str1 str2 -- bool )
    ; check if two chars are equal
    2dup
    load
    swap
    load
    sub
    brnz @streq_done_ne
    ; they're both equal, is either one zero?
    dup
    load
    brz @streq_done_eq
    ; inc both pointers
    add 1
    swap
    add 1
    jmpr @streq
streq_done_eq:
    pop
    pop
    ret 1
streq_done_ne:
    pop
    pop
    ret 0




; Check whether two words (terminated by any non-word-character) are equal
wordeq: ; ( str1 str2 -- bool )
    ; check if both chars are nonword
    2dup
    load
    call word_char
    swap
    load
    call word_char
    or
    brz @wordeq_done_eq ; both are nonword so we're done
    ; check if both chars are equal
    2dup
    load
    swap
    load
    sub
    brnz @wordeq_done_ne
    ; they're both equal, inc both pointers
    add 1
    swap
    add 1
    jmpr @wordeq
wordeq_done_eq:
    pop
    pop
    ret 1
wordeq_done_ne:
    pop
    pop
    ret 0





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
    brz @advance_entry_end
    loadw
    ret
advance_entry_end:
    ret 0




; Find dictionary entry for word
find_in_dict: ; ( ptr dict -- addr )
    call dupnz
    brz @find_in_dict_not_found
    2dup
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
find_in_dict_not_found:
    pop
    ret 0




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
    brz @skip_word_done
    add 1
    jmpr @skip_word
skip_word_done:
    ret



; Takes a pointer to a nonword-char, returns a pointer to the
; first word-char after it, or the first zero / EOS
skip_nonword: ; ( ptr -- first-word )
    dup
    load ; ( ptr ch )
    call dupnz
    brz @skip_nonword_done
    call word_char
    brnz @skip_nonword_done
    add 1
    jmpr @skip_nonword
skip_nonword_done:
    ret




handleline: ; ( -- )
    push line_buf
    call skip_nonword
    storew cursor ; cursor points at the beginning of a word
handleline_loop:
    loadw cursor
    loadw handleword_hook
    call ; Call the current hook to handle words (either handleword or compileword)
    loadw cursor
    call skip_word ; Advance past this word
    load
    brz @handleline_done ; after this word is an EOS, so we're done
    ; Now on to the next word
    loadw cursor
    call skip_word
    call skip_nonword
    storew cursor ; cursor is now the start of the next word
    jmpr @handleline_loop
handleline_done:
    ret



; Finds the first occurrence of val at or after start, or returns 0 if it encounters a null
; terminator first
find_byte: ; ( val start -- addr-or-zero )
    dup
    load
    call dupnz
    brz @find_byte_eos
    pick 2
    sub
    call dupnz
    brz @find_byte_found
    pop
    add 1
    jmpr @find_byte
find_byte_found:
    swap
    pop
    ret
find_byte_eos:
    pop
    pop
    ret 0


; Reads from the input line a string, starting with the first word character after cursor
; and ending with the first quote (ascii 34). Places on the stack the address of the first word
; character and the address of the quote, or just zero if there is no quote
read_string: ; ( addr -- start end ), or if unclosed ( addr -- 0 )
    call skip_nonword
    dup
    swap 34
    call find_byte ; ( start end? ) Find where we should end, or zero
    call dupnz
    brz @read_string_unclosed
    ret
read_string_unclosed:
    pop
    ret 0



dotquote:
    loadw cursor
    call skip_word ; advance past the ." itself
    call read_string ; ( start end ) or ( 0 )
    call dupnz
    brz @dotquote_unclosed
    pushr
dotquote_loop:
    dup
    popr
    dup
    pushr
    sub
    brz @dotquote_done
    dup
    load
    store 2
    add 1
    jmpr @dotquote_loop
dotquote_done:
    popr
    pop
    storew cursor
    ret
dotquote_unclosed:
    push unclosed_error
    call print
    push 0
    storew line_buf
    push line_buf
    storew cursor
    ret



; Copies a region of memory to another region of memory. Copies start..(end-1) to dest..etc
copy_region: ; ( start end dest -- )
    pushr
    swap ; ( end start ) [ dest ]
copy_region_loop:
    2dup
    sub
    brz @copy_region_done
    dup
    load ; ( end start byte ) [ dest ]
    popr
    dup
    add 1
    pushr ; ( end start byte dest ) [ dest+1 ]
    store
    add 1
    jmpr @copy_region_loop
copy_region_done:
    popr
    pop
    pop
    pop
    ret



; Reads a word and adds it to the dictionary with a null definition. Returns the address of
; the definition
word_to_dict: ; ( word-addr -- def-addr )
    dup
    call skip_word
    2dup
    loadw heap_ptr
    call copy_region ; ( word-start word-end )
    swap
    sub
    loadw heap_ptr
    add ; ( dictionary-word-null )
    dup
    swap 0
    store ; null terminate the string
    add 1
    dup
    swap 0
    storew ; write the (null) ptr to the definition
    dup
    add 3 ; ( def-addr next-addr )
    loadw dictionary
    swap 
    storew ; make this point to the first dict entry
    loadw heap_ptr
    storew dictionary
    dup
    add 6
    storew heap_ptr ; move the heap ptr forward
    ; Return the definition ptr
    ret




colon_word:
    loadw cursor
    call skip_word ; skip the colon itself
    call skip_nonword ; skip the space before the word name
    dup
    load
    call word_char
    brz @colon_word_err ; Make sure we were actually given a name
    dup
    storew cursor ; tell handleline we've eaten these words
    call word_to_dict ; stick the new word in the dictionary
    loadw heap_ptr
    swap
    storew ; Store the current heap_ptr as the definition
    call enter_compile_mode
    ret
colon_word_err:
    pop
    push expected_word_err
    call print
    call cr
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
    brz @compileword_blank
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
    call missing_word ; actually, we need to check for a compile-only word here
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
compileword_blank:
    pop
    ret
compileword_number:
    swap
    pop
    push $PUSH 
    call compile_instruction_arg
    ret




; NEEDS A TEST
compile_instruction_arg: ; ( arg opcode -- )
    lshift 2
    or 3 ; tell it we have a three byte arg
    loadw heap_ptr ; ( arg instr-byte heap_ptr )
    dup
    add 4
    storew heap_ptr ; Increment the ptr ( arg instr-byte heap_ptr )
    2dup
    store
    add 1
    swap
    pop ; ( arg heap_ptr+1 )
    storew
    ret




; TODO: NEEDS A TEST
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
    brz @handleword_blank
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
handleword_done:
    ret
handleword_blank:
    pop
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
    2dup
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

missing_word:
    push missing_word_str
    call print
    call print
    call cr
    ret





;;;;;;;;;;;;;;;;;;




missing_word_str: .db "That word wasn't found: \0"
unclosed_error: .db "Unclosed string\0"
expected_word_err: .db "Expected word, found end of input\0"
foo_str: .db "You called foo\0"
bar_str: .db "Bar was called, probably by you!\0"

;;;;;;;;;;;;;;;;;;

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
.db d_dotquote

d_dotquote: .db ".\"\0"
.db dotquote
.db d_colon

d_colon: .db ":\0"
.db colon_word
.db d_allot

d_allot: .db "allot\0"
.db allot
.db d_free

d_free: .db "free\0"
.db free
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
compile_dictionary: .db d_semicolon

line_buf: .db 0
.org line_buf + 0x100

heap_start: