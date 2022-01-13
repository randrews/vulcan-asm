; Tries to parse a number out of a string. There's a helper function,
; pos_is_number, that does a sequence of digits. This checks the first
; character against '-', and then calls that, and negative-izes if
; necessary.
is_number: ; ( ptr -- num valid? )
    dup
    load ; ( ptr first-ch )
    xor 45 ; 45 is '-', ( ptr not-dash )
    brnz @pos_is_number ; We're done here, it's positive
    add 1
    call pos_is_number ; ( pos-num valid? )
    dup
    brz @is_number_bad
    swap
    xor 0xffffff
    add 1
    swap
is_number_bad:
    ret

; The positive-only version of parsing a number. Negative-ness is
; handled by is_number, at this point we can assume that we just have
; a sequence of positive digits.
pos_is_number: ; ( ptr -- num valid? )
    pushr 0
pos_is_number_loop:
    dup
    load
    call is_digit
    brz @pos_is_number_bad
    dup
    load
    sub 48 ; '0' ascii
    popr
    mul 10
    add
    pushr
    add 1
    dup
    load
    call word_char
    brz @pos_is_number_done
    jmpr @pos_is_number_loop
pos_is_number_bad:
    popr
    pop
    ret 0
pos_is_number_done:
    pop
    popr
    ret 1

; Takes a pointer to the start of a word, returns a pointer to the
; first nonword-char after it
skip_word: ; ( ptr -- first-nonword )
    #while
    dup
    load
    call word_char
    #do
    add 1
    #end
    ret

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

; Copies the first word starting at / after the cursor from line_buf
; to the destination, and null-terminates it
word_to: ; ( dest -- )
    loadw cursor
    call skip_nonword
    swap
    push word_char
    call copy_string
    pop
    storew cursor
    ret

; Copies the first word starting at / after the cursor from line_buf
; to the pad, and null-terminates it
word_to_pad: ; ( -- )
    push pad
    jmp word_to

; Copies the first word starting at / after the cursor from line_buf
; to the bottom of the heap, and null-terminates it. This does NOT
; advance heap_ptr! The idea is that this is immediately sent to tick
; to recognize the word, which will be written over by whatever the
; word does.
word_to_heap: ; ( -- )
    loadw heap_ptr
    jmp word_to

; returns false if the character is either zero or a quotation mark
until_double_quote: ; ( ch -- bool )
    dup
    xor 34 ; ascii double quote
    gt 0 ; ( ch isnt-quote )
    swap
    gt 0 ; ( isnt-quote isnt-zero )
    and
    ret

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
