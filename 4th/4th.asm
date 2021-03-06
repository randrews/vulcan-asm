.org 0x400 ; start here
    setiv oninterrupt ; Set the interrupt handler
    inton
stop:
    hlt ; And get out

oninterrupt:
    dup
    sub 65
    brz @onkeypress
    inton ; this isn't an interrupt we recognize, not much we can do here except leave it on the stack and continue on
    hlt

; Called as an ISR every time a key is pressed. Most keys are just tacked on to line_buf. If they
; press enter, we call handleline to interpret the line of input.
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#include "utils.asm"
#include "dict_utils.asm"
#include "string.asm"
#include "compiler_utils.asm"
#include "runtime_words.asm"
#include "compile_words.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Interpret a line of input. The line is in line_buf and we're starting from the beginning of it.
; We might have been left in either mode by the previous line, so we'll just loop through the
; words, copy each one to the heap (ignoring whitespace), and call whatever the current handler is.
handleline: ; ( -- )
    push line_buf
    storew cursor
handleline_loop:
    call word_to_heap
    loadw heap_ptr
    load
    brz @end_ret
    loadw heap_ptr
    loadw handleword_hook
    call
    jmpr @handleline_loop

; The word handler for compile mode. This is called for each word in the input if we're in compile
; mode. We should take the word (which is at heap), look it up in the compile dictionary, and if
; it's there, call it. If it isn't, look it up in the runtime dictionary and compile a call to it.
; If it's not there either, try to see if it's a number and compile a push of it. If it's not a
; number then there's nothing we can do, so error with missing_word
compileword:
    ; first check for a blank word and skip:
    dup
    load
    brz @end_pop1 ; blank?
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
    call missing_word
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
compileword_number:
    swap
    pop
    push $PUSH
    call compile_instruction_arg
    ret

; The word handler for interpret mode. This is called for each word in the input that we're in
; interpret mode for. The word is already copied to heap, so we look it up in the runtime dictionary,
; and if we find it call it. If not, try to parse it as a number, and push it. If it's not a number
; either, then complain about the error with missing_word.
handleword: ; ( <args for word> word-start-addr -- <word return stack> )
    ; first check for a blank word and skip:
    dup
    load
    brz @end_pop1 ; blank?
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
    ret
handleword_number:
    swap
    pop
    ret

; Called when we expected to find something in the dictionary and didn't
missing_word:
    push missing_word_str
    call print
    call print
    call cr
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; These two were used before most of it was written, as test words.
; TODO dump both these
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
foo_str: .db "You called foo\0"
bar_str: .db "Bar was called, probably by you!\0"

;;;;;;;;;;;;;;;;;;

data_start: ; Just a marker for the stats to measure how long the text section is

; Some strings for error messages and whatnot
missing_word_str: .db "That word wasn't found: \0"
unclosed_error: .db "Unclosed string\0"
expected_word_err: .db "Expected name, found end of input\0"

#include "dictionary.asm"

; Assorted support variables
heap_ptr: .db heap_start ; holds the address in which to start the next heap entry
handleword_hook: .db handleword ; The current function used to handle / compile words, switches based on mode
line_len: .db 0
cursor: .db 0 ; During calls to handleword, this global points to the beginning of the word

; pointer to head of runtime dictionary
dictionary: .db d_foo

; pointer to head of compile-time dictionary
compile_dictionary: .db d_if

; A buffer for line input
line_buf: .db 0
.org line_buf + 0x100

; Scratch pad buffer
pad: .db 0
.org pad + 0x100

; A stack for compiling control structures
c_stack_ptr: .db c_stack
c_stack: .db 0
.org c_stack + 96

; Things we define start here:
heap_start:
