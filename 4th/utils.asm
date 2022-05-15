#include "magic.asm"

; Emit a single character to stdout
emit: ; ( ch -- )
    loadw emit_cursor
    dup
    add 1
    storew emit_cursor
    add 0x10000
    store
    ret
emit_cursor: .db 0 ; The length of the string in the output buffer


; Print a null-term string
print: ; ( addr -- )
    #while
        dup
        load
        call dupnz
    #do
        call nova_emit
        add 1
    #end
    pop
    ret

; Print a carriage return
cr: ; ( -- )
    push 10
    call nova_emit
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
