.org 0x400 ; start here
    jmp start



; Print a string of a certain length
nprint: ; ( addr len -- )
    store24 nprint_len
    push 0
    store24 nprint_off
nprint_loop:
    load24 nprint_off
    load24 nprint_len
    sub
    brz @nprint_done
    dup
    load24 nprint_off
    add
    load
    store 0x02
    load24 nprint_off
    add 1
    store24 nprint_off
    jmpr @nprint_loop
nprint_done:
    pop
    ret



; Print a null-term string
print: ; ( addr -- )
    dup
    load
    dup
    brz @print_done
    store 0x02
    add 1
    jmpr @print
print_done:
    pop
    pop
    ret



; Print a carraige return
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
    not
    brz @streq_done_ne
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



; advance a pointer to the next dictionary entry
advance_entry: ; ( ptr -- next_ptr )
    dup
    load ; ( ptr *ptr )
    brz @advance_entry_done
    add 1
    jmpr @advance_entry
advance_entry_done:
    add 4
    ret



; Find dictionary entry for word
tick: ; ( ptr -- addr )
    push dictionary
    store24 tick_current
tick_loop:
    dup ; ( ptr ptr )
    load24 tick_current ; ( ptr ptr tc )
    dup ; ( ptr ptr tc tc )
    load ; ( ptr ptr tc *tc )
    brz @tick_missing_word
    call streq ; ( ptr eq? )
    brz @tick_retry
    pop ; ( ) This WAS the right entry!
    load24 tick_current
    call advance_entry
    sub 3
    load24
    ret
tick_retry:
    load24 tick_current ; ( ptr tc )
    call advance_entry
    store24 tick_current ; ( ptr )
    jmpr @tick_loop
tick_missing_word:
    pop
    pop
    pop
    ret 0
tick_current: .db 0




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
    call word_char
    brz @onkeypress_handleword 
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
onkeypress_handleword:
    pop ; drop the newline or whatever it is
    call handleword
    jmpr @onkeypress_done


; returns whether this character is a word char (nonzero) or a separator between words (space, cr, tab)
word_char: ; ( ch -- bool )
    dup
    sub 10 ; cr
    brz @word_char_no
    dup
    sub 32 ; spc
    brz @word_char_no
    dup
    sub 9 ; tab
    brz @word_char_no
    pop
    ret 1
word_char_no:
    pop
    ret 0



is_digit: ; ( ch -- bool )
    dup
    gt 47 ; it's at least '0'
    swap
    lt 58 ; it's at most '9'
    and
    ret




; Tries to parse a number out of a string
is_number: ; ( ptr -- num valid? )
    push 0
    store24 is_number_num
is_number_loop:
    dup
    load
    call is_digit
    brz @is_number_bad
    dup
    load
    sub 48
    load24 is_number_num
    mul 10
    add
    store24 is_number_num
    add 1
    dup
    load
    brz @is_number_done
    jmpr @is_number_loop
is_number_bad:
    ret 0
is_number_done:
    pop
    load24 is_number_num
    ret 1
is_number_num: .db 0



itoa: ; ( num -- )
    push itoa_arr
    store24 itoa_end
itoa_loop:
    dup ; ( num num )
    mod 10
    dup
    add 48 ; ( num mod ch )
    load24 itoa_end
    store
    load24 itoa_end
    add 1
    store24 itoa_end
    sub
    div 10
    dup
    brnz @itoa_loop
    pop
    ; Got the array of digits in reverse order, print them out:
    load24 itoa_end
    sub 1
itoa_print_loop:
    dup
    load
    store 2
    sub 1
    dup
    gt itoa_arr - 1
    brnz @itoa_print_loop
    pop
    ret
itoa_end: .db 0
itoa_arr: .db 0
.org itoa_arr + 32 ; set aside some space


handleword:
    ; null-term the word
    push 0
    push line_buf
    load line_len
    add
    store
    ; reset line_len
    push 0
    store line_len
    ; handle the now null-termed word
    ; first check for a blank word and skip:
    load line_buf
    brz @handleword_done
    ; Now call tick to try to find it in the dictionary
    push line_buf
    call tick
    dup
    brnz @handleword_found ; found something
    ; It wasn't in the dictionary, is it a number?
    pop
    push line_buf
    call is_number
    brnz @handleword_done
    call cr
    ; It wasn't a number either, drop the garbage:
    pop
    ; And complain:
    call missing_word
    jmpr @handleword_done
handleword_found:
    call
handleword_done:
    inton
    ret



start:
    setiv oninterrupt
    inton
    hlt




;;;;;;;;;;;;;;;;;;




foo:
    push foo_str
    call print
    call cr
    ret
foo_str: .db "You called foo\0"




bar:
    push bar_str
    call print
    call cr
    ret
bar_str: .db "Bar was called, probably by you!\0"



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
    push line_buf
    call print
    call cr
    ret
missing_word_str: .db "That word wasn't found: \0"





;;;;;;;;;;;;;;;;;;





you_entered: .db "You entered: \0"
nprint_off: .db 0
nprint_len: .db 0
line_buf: .db 0
.org line_buf + 0x100
line_len: .db 0

dictionary:
.db "foo\0"
.db foo
.db "bar\0"
.db bar
.db "emit\0"
.db putc
.db ".\0"
.db itoa
.db "cr\0"
.db cr
.db "+\0"
.db w_add
.db "-\0"
.db w_sub
.db "*\0"
.db w_mul
.db "/\0"
.db w_div
.db "mod\0"
.db w_mod
.db 0 ; sentinel for end of dictionary