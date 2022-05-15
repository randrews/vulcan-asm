; We often need to pop 1-2 times and then ret a flag, in a brnz / brz.
; Rather than repeat that everywhere, we'll abstract it and branch
; to one of these three:
end0_pop2: pop
end0_pop1: pop
ret 0
end1_pop2: pop
pop
ret 1

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
