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
    call wordeq ; ( ptr eq? )
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



; returns whether this character is a word char (nonzero) or a separator between words (space, cr, tab)
word_char: ; ( ch -- bool )
    dup
    brz @word_char_no
    dup
    sub 10 ; cr
    brz @word_char_no
    dup
    sub 13 ; cr
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
    call word_char
    brz @is_number_done
    jmpr @is_number_loop
is_number_bad:
    ret 0
is_number_done:
    pop
    load24 is_number_num
    ret 1
is_number_num: .db 0




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
    dup
    store24 handleline_current
    store24 handleline_start
handleline_loop:
    load24 handleline_start
    call skip_word
    store24 handleline_current
    load24 handleline_start
    call handleword ; Call the word
    load24 handleline_current
    load
    brz @handleline_done ; this is an EOS, so we're done
    ; Now on to the next word
    load24 handleline_current
    call skip_nonword
    store24 handleline_start
    jmpr @handleline_loop
handleline_done:
    ret
handleline_current: .db 0
handleline_start: .db 0





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
    call print
    call cr
    ret
missing_word_str: .db "That word wasn't found: \0"





;;;;;;;;;;;;;;;;;;





dictionary_end_ptr: .db dictionary_end ; holds the address of the current dictionary end sentinel
line_len: .db 0
line_buf: .db 0
.org line_buf + 0x100

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
dictionary_end:
.db 0 ; sentinel for end of dictionary

heap: .org dictionary + 0x4000 ; 16k set aside for words and definitions