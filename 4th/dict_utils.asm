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
    call skip_word
    add 4
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

; Store the current handleword_hook in the C stack,
; put linecomment in its place. When handleline starts,
; if it sees that handleword_hook is linecomment, it'll
; pop the old one back out.
backslash_word:
    loadw handleword_hook
    call push_c_addr
    push linecomment
    storew handleword_hook
    ret

; Store the current handleword_hook in the C stack,
; put parencomment in its place.
open_paren_word:
    loadw handleword_hook
    call push_c_addr
    push parencomment
    storew handleword_hook
    ret

; Store the current handleword_hook in the C stack,
; put parencomment in its place.
; We also have a "stub" word which is what the dict actually
; points to, so that a mismatched close paren doesn't end
; up actually doing anything (it's only callable from / by
; parencomment)
close_paren_word:
    call pop_c_addr
    storew handleword_hook
close_paren_stub:
    ret
