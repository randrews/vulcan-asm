#include "magic.asm"

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

dupnz: ; if TOS is nonzero, dup it
    dup
    brz @dupnz_done
    dup
dupnz_done:
    ret

; returns whether this character is a word char (nonzero) or a separator between words (space, cr, tab, control chars...)
word_char: ; ( ch -- bool )
    gt 32
    ret

; returns whether this character is a digit 0-9
is_digit: ; ( ch -- bool )
    dup
    gt 47 ; it's at least '0'
    swap
    lt 58 ; it's at most '9'
    and
    ret
