.org 0x400 ; start here
;;;;; Start
    push on_key
    setiv 5
    setint 1
    call clear_screen
    call set_video
    push msg
    push screen
    call print_to

    push putc
    storew emit_hook
    push vemu_quit
    storew quit_vector
wfi_loop: hlt
    jmpr @wfi_loop

vemu_quit:
    call clear_tib
    jmpr @wfi_loop

;;;;;

screen: .equ 0x10000
reg: .equ 16
$lshift: .equ 0xe1 ; TODO vasm shouldn't allow syms that are also opcodes
$rshift: .equ 0xe5
enter: .equ 0x28
backspace: .equ 0x2a

default_table: .db "abcdefghijklmnopqrstuvwxyz1234567890???? -=[]\\?;'`,./"
shift_table: .db "ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()???? _+{}|?:\"~<>?"

screen_cursor: .db screen + 40 ; TODO vasm shouldn't allow redefining syms
msg: .db "Welcome to NovaForth\0"
okay: .db "ok\0"
current_table: .db default_table

set_video:
    push 30
    storew reg + 10
    push 40
    storew reg + 13
    ret

clear_screen:
    push screen
    #while
        dup
        lt screen + 40 * 30
    #do
        dup
        swap 0
        store

        dup
        add 40 * 30
        swap 0b10010010
        store

        add 1
    #end
    pop
    ret

print_to: ; ( msg addr -- ) TODO this should replace print in 4th
    pushr
    #while
        dup
        load
    #do
        dup
        load
        peekr
        store
        popr
        add 1
        pushr
        add 1
    #end
    pop
    popr
    pop
    ret

on_key:
    setint 1 ; this can be reentrant, doesn't hurt anything
    call is_press ; check for press
    #if
        call is_ret
        brnz @handle_enter
        call is_back
        brnz @handle_backspace
        call is_printable
        brnz @handle_char
        call is_shift
        brnz @set_shift
    ;   if backspace, clear cursor and dec
        pop
        ret
    #else
        call is_shift
        brnz @clear_shift
        pop
        ret
    #end
    ret

newline:
    loadw screen_cursor
    sub screen
    add 40
    dup
    gt 40 * 30 - 1
    #if
        pop
        push 40
    #else
        dup
        mod 40
        sub
    #end
    add screen
    storew screen_cursor
    ret

set_shift:
    push shift_table
    storew current_table
    ret

clear_shift:
    push default_table
    storew current_table
    ret

is_press: ; ( event -- key bool )
    dup
    and 0xff
    swap
    and 0xff00
    ret

is_ret:
    push enter
    jmp is_key

is_back:
    push backspace
    jmp is_key

is_shift: ; ( key -- 1 ) or ( key -- key 0 )
    push $lshift
    call is_key
    brz @+2
    ret 1
    push $rshift
    jmp is_key

is_key: ; ( key1 key2 -- 1 ) or ( key1 key2 -- key1 0 )
    swap
    dup
    pushr
    sub
    #unless ; they're equal
        popr
        pop
        ret 1
    #else ; they're not
        popr
        ret 0
    #end

is_printable: ; ( key -- ch 1 ) or ( key -- key 0 )
    dup
    dup
    gt 0x03
    swap
    lt 0x39
    and
    #if
        sub 0x04
        loadw current_table
        add
        load
        ret 1
    #end
    ret 0

; Print the character we just typed, then put it into tib,
; increment tib_cursor and re-null-term the string. 
handle_char: ; ( ch -- ) modifiers cursor too
    dup
    call putc
    loadw tib_cursor
    store
    loadw tib_cursor
    add 1
    dup
    swap 0
    store
    storew tib_cursor
    ret

; Backspace on the screen (bracketed to the beginning of
; the line), and backspace tib_cursor (bracketed to the
; start of tib)
handle_backspace:
    loadw screen_cursor
    sub screen
    dup
    mod 40
    #if
        sub 1
        add screen
        dup
        swap 32 ; a space
        store
        storew screen_cursor
    #else
        pop
    #end
    loadw tib_cursor
    gt tib
    #if
        loadw tib_cursor
        sub 1
        dup
        swap 0
        store
        storew tib_cursor
    #end
    ret

handle_enter:
    ; Separator before our result
    call advance_one
    ; Actually eval the tib
    push tib
    call eval
    ; If the eval was successful, we'll do this:
    ; clear the tib
    call clear_tib
    ; Tell the user we evaluated it
    call advance_one
    push okay
    call print
    ; Go to another line
    call newline
    ret

putc: ; ( ch -- ) (also modifies cursor)
    dup
    xor 10 ; newline
    #if ; normal char, emit it
        loadw screen_cursor
        dup
        pushr
        store
        popr
        add 1
        storew screen_cursor
        ret
    #end
    jmp newline

; Print a space (by ticking cursor forward some)
advance_one:
    loadw screen_cursor
    add 1
    storew screen_cursor
    ret

clear_tib:
    push tib
    storew tib_cursor
    push 0
    store tib
    ret

; Terminal input buffer
tib: .db 0
.org tib + 0x100
tib_cursor: .db tib

#include "4th.asm"
