; Tries to parse a number out of a string. There's a helper function,
; pos_is_number, that does a sequence of digits. This checks the first
; character against '-', and then calls that, and negative-izes if
; necessary.
is_number: ; ( ptr -- [num 1] -or- [0] )
    dup
    load ; ( ptr first-ch )
    xor 45 ; 45 is '-', ( ptr not-dash )
    brnz @pos_is_number ; We're done here, it's positive
    add 1
    call pos_is_number ; ( pos-num valid? )
    #if
        xor 0xffffff
        add 1
        ret 1
    #end
    pop
    ret 0

; The positive-only version of parsing a number. Negative-ness is
; handled by is_number, at this point we can assume that we just have
; a sequence of positive digits.
; TODO: refactor this to use macros
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
    pop
    ret 0
pos_is_number_done:
    pop
    popr
    ret 1

; Attempt to parse a hexadecimal number. This is a sequence of digits 0-9 or a-f or A-F
hex_is_number: ; ( ptr -- [num 1] -or- [0] )
    pushr 0
    #while
        dup
        load
        dup
        call word_char
    #do ; It's a word-char
        call parse_hex_digit
        #if ; It's a digit even!
            popr
            mul 16
            add
            pushr
            add 1
        #else ; Not a digit, not a \0...
            popr
            pop
            pop
            ret 0
        #end
    #end
    ; End of string, return the number
    pop
    pop
    popr
    ret 1

; Returns whether the byte at the top of the stack is a hex digit, and what it is if so
parse_hex_digit: ; ( byte -- [val 1] if a digit, or [0] if it isn't )
    dup
    call is_digit
    #if ; It's a 0-9
        sub 48 ; '0' ascii
        ret 1
    #else
        dup
        gt 96 ; ( ch is-lowercase )
        #if
            sub 32
        #end
        dup
        dup
        gt 64 ; at least 'A'
        swap
        lt 71 ; at most 'F'
        and ; ( ch is-AF )
        #if
            sub 55
            ret 1
        #end
    #end
    pop
    ret 0

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
    #if
        call word_char
        #unless
            add 1
            jmpr @skip_nonword
        #end
        ret
    #end
    ret


; Return a flag of whether two strings are equal
compare: ; ( str1 str2 -- equal? )
    pushr
    #while
        dup
        load
        peekr
        load
        xor
        not
    #do
        ; If we're here, they're equal chars, so first check if they're equal zeroes:
        dup
        load
        #unless
            popr
            pop
            pop
            ret 1
        #end
        ; They're the same, increment both pointers
        add 1
        popr
        add 1
        pushr
    #end
    popr
    pop
    pop
    ret 0
