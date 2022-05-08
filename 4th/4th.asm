.org 0x400 ; start here
stop:
    hlt ; And get out

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#include "utils.asm"
#include "dict_utils.asm"
#include "string.asm"
#include "compiler_utils.asm"
#include "runtime_words.asm"
#include "compile_words.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Interpret a line of input. The pointer to the (null-terminated) line is at the top of the stack.
; This cannot be put in the dictionary, because if it calls itself recursively it'll clobber the
; cursor, but it can be called from outside. It's the primary entry point to Forth.
eval: ; ( ptr -- ??? )
    call skip_nonword ; Skip any leading whitespace
    storew cursor ; Store the pointer in the cursor, so it's not polluting the stack during handleword calls
    #while ; While we're not at the end of the string
        loadw cursor
        load
    #do
        loadw cursor ; Copy the word we care about to the heap
        loadw heap_ptr
        call nova_word_to
        loadw cursor ; Advance cursor by the word we just copied and the following crap
        call skip_word
        call skip_nonword
        storew cursor
        loadw heap_ptr ; Load the address we just put the word at and execute it
        loadw handleword_hook
        call
    #end
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Copy the word at cursor to the heap, null-terminate it, advance cursor to the start
; of the next word (or the null terminator if this is the last word); do not advance heap.
nova_word: ; ( -- )
    loadw cursor
    loadw heap_ptr
    call nova_word_to
    loadw cursor
    call skip_word
    call skip_nonword
    storew cursor
    loadw heap_ptr ; But what if the word is empty string?
    load
    #unless
        push expected_word_err
        call print
        call cr
    #end
    ret

nova_word_to: ; ( src dest -- )
    pushr ; ( src ) [ dest ]
    #while
        dup
        load
        dup
        call word_char
    #do
        peekr
        store
        popr
        add 1
        pushr
        add 1
    #end
    pop ; drop the nonword-char ( src ) [ dest ]
    pop ; drop the now-useless src
    popr 0 ; ( 0 dest )
    store
    ret

; Creates a new dictionary entry, pointing at the (new) heap, for the following word
nova_create: ; ( -- )
    call nova_word ; consume a word and stick it on the heap
    loadw heap_ptr ; Load the heap ptr and advance it to the place right after the word's null-terminator
    call skip_word
    add 1
    dup ; ( def_ptr def_ptr )
    add 6 ; ( def_ptr new_heap )
    pick 1
    storew ; write the def address, ( def_ptr )
    loadw dictionary
    pick 1
    add 3
    storew ; point it at the dictionary
    loadw heap_ptr
    storew dictionary ; point the dictionary at it
    add 6
    storew heap_ptr ; advance the heap ptr
    ret

; Enter immediate mode or compile mode
nova_open_bracket: push immediate_handleword
    jmpr @+2
nova_close_bracket: push compile_handleword
    storew handleword_hook
    ret

; Compile a jmp to a word
nova_continue: ; ( -- )
    call nova_word
    loadw heap_ptr
    call tick ; ( ptr-to-word )
    call dupnz
    #if ; It's actually a word!
        push $JMP
        jmpr @compile_instruction_arg
    #else ; It's not a normal word, but could be a compile word
        loadw heap_ptr
        call compile_tick
        call dupnz
        #if ; Compile word, compile it anyway
            push $JMP
            jmpr @compile_instruction_arg
        #else ; This is just not a word at all
            loadw heap_ptr
            jmpr @missing_word
        #end
    #end

; compile-time word, causes the next word to be compiled instead of it
; being run. The corollary of that is that an immediate word, where we
; would normally run it (because we're in compile mode) we compile a call
; to it; a non-immediate word, we compile some code that will compile a
; call to it. For example: compiling "postpone emit" should result in
; push <emit>
; push $CALL
; call compile_instruction_arg
; ...being compiled into the current defn because when run that will
; compile a call to emit. But "postpone do" causes a call to "do" to be
; compiled, because when run that will call "do" (whereas normally we'd
; just call "do" right now because it's immediate).
nova_postpone:
    call nova_word
    loadw heap_ptr
    call tick ; ( ptr-to-word )
    call dupnz
    #if ; It's a normal word
        push $PUSH
        call compile_instruction_arg ; compile a push of that address
        push $CALL
        push $PUSH
        call compile_instruction_arg ; compile a push of $CALL
        push compile_instruction_arg
        push $CALL
        jmpr @compile_instruction_arg ; compile a call of compile_instruction_arg
    #else ; It's not a normal word, maybe a compile word?
        loadw heap_ptr
        call compile_tick
        call dupnz
        #if ; It's a compile word
            push $CALL
            jmpr @compile_instruction_arg ; Compile a call to it.
        #else ; It's not a compile word either, error out
            loadw heap_ptr
            jmpr @missing_word
        #end
    #end

; Compile a ret. Needed in order to define semicolon, because you need semicolon to define any
; other way of defining exit
nova_exit:
    push $RET
    jmpr @compile_instruction

; Immediate is a runtime word that moves the most recently defined word from the
; runtime dictionary to the compile-time one.
nova_immediate:
    loadw dictionary
    dup ; save a copy, we'll need to set compile_dictionary to this later
    call skip_word
    add 4 ; now we're pointing at the next word, meaning, the new dictionary ptr:
    dup
    loadw
    storew dictionary ; dictionary is now pointing at the right place
    loadw compile_dictionary
    swap
    storew ; This definition is now pointing at the old compile_dictionary
    storew compile_dictionary ; and compile_dictionary is pointing at it!
    ret

; Compiles the top of stack to the heap
nova_comma:
    loadw heap_ptr
    dup
    add 3
    storew heap_ptr
    storew
    ret

; This is a runtime word used for defining the behavior of created
; words. For example: ": foo create does> drop 12 ;" makes a word foo, used as:
; "foo blah". That call creates another word, blah, which when it's
; run pushes 12. So then, does> alters the head of the dictionary (because
; that was just create'd), to set its definition pointer to right after
; the does>, then compiles a push of the old value of the definition pointer.
; The expected result of this: ": foo create 15 , does> drop 12 ;" is this:
; > create a dictionary entry from the next word in input
; > push a 15 and compile it (the compile-time behavior of the new word)
; > push the address of label A
; > jmp to does_at_runtime (which reassigns the def ptr to lbl A)
; > return
; > label A:
; > popr the address of the 15 (where the heap originally was)
; > drop the address of the 15
; > push a 12 (runtime behavior of the new word)
; > return
does_word:
    loadw heap_ptr
    add 9 ; to account for the push itself, the call and the ret
    push $PUSH
    call compile_instruction_arg ; push the addr right after the does>
    push does_at_runtime
    push $JMP
    call compile_instruction_arg ; jmp does_at_runtime
    push $RET
    call compile_instruction ; return
    ret

; Runtime behavior of does>
; When we jmp here, the compile-time behavior has left the address
; we want for the runtime behavior of the new word at the top of stack.
; So, we need to reassign the def ptr of the new word to (eventually)
; lead there. But we need to save what it originally was, first! So we
; grab it and stick it in the R stack, then compile a whole new area
; which pushes the old ptr and then jmps after the does> addr.
does_at_runtime: ; ( does-addr -- )
    loadw dictionary
    call skip_word
    add 1 ; find the definition address
    dup
    loadw
    pushr ; stash old in the r stack
    loadw heap_ptr
    swap
    storew ; point it at the new definition
    popr
    push $PUSH
    call compile_instruction_arg ; compile pushing the old def ptr value
    push $JMP
    call compile_instruction_arg ; compile a jmp to after does>
    ret

mnemonics:
.db "push\0"
.db "add\0"
.db "sub\0"
.db "mul\0"
.db "div\0"
.db "mod\0"
.db "rand\0"
.db "and\0"
.db "or\0"
.db "xor\0"
.db "not\0"
.db "gt\0"
.db "lt\0"
.db "agt\0"
.db "alt\0"
.db "lshift\0"
.db "rshift\0"
.db "arshift\0"
.db "pop\0"
.db "dup\0"
.db "swap\0"
.db "pick\0"
.db "rot\0"
.db "jmp\0"
.db "jmpr\0"
.db "call\0"
.db "ret\0"
.db "brz\0"
.db "brnz\0"
.db "hlt\0"
.db "load\0"
.db "loadw\0"
.db "store\0"
.db "storew\0"
.db "inton\0"
.db "intoff\0"
.db "setiv\0"
.db "sdp\0"
.db "setsdp\0"
.db "pushr\0"
.db "popr\0"
.db "peekr\0"
.db "debug\0"
mnemonics_end:

nova_opcode_for_word: ; ( -- opcode ) -or- ( -- word-ptr -1 ) if it isn't a mnemonic
    call nova_word
    pushr 0
    loadw heap_ptr
    push mnemonics
    #until ; While our ptr into mnemonics is the different from the heap str
        pick 1
        pick 1
        call compare
    #do
        call skip_word
        add 1
        dup
        sub mnemonics_end
        #unless ; We're at the end and this isn't a mnemonic
            popr
            pop
            pop
            ret 0xffffff
        #end
        popr
        add 1
        pushr
    #end
    pop
    pop
    popr
    ret

nova_asm:
    call nova_opcode_for_word
    dup
    sub 0xffffff
    #if
        jmp compile_instruction
    #else
        pop
        jmp invalid_mnemonic
    #end

nova_arg_asm:
    call nova_opcode_for_word
    dup
    sub 0xffffff
    #if
        jmp compile_instruction_arg
    #else
        pop
        jmp invalid_mnemonic
    #end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Handle a word, in immediate mode. The word must be at ptr, and null-terminated
immediate_handleword: ; ( word-ptr -- ? )
    dup
    call tick
    call dupnz
    #if ; We found a dict entry for it! ( word-ptr fn-ptr )
        swap ; clear the now-unneeded word ptr off the stack
        pop
        jmp ; actually call the word
    #else ; No dict entry but it may still be a number ( word-ptr )
        dup
        loadw is_number_hook
        call
        #if ; It's a number
            swap
            pop
            ret
        #end ; This isn't a valid word OR a number, so, bail
    #end
    jmpr @missing_word

; The word handler for compile mode. This is called for each word in the input if we're in compile
; mode. We should take the word (which is at heap), look it up in the compile dictionary, and if
; it's there, call it. If it isn't, look it up in the runtime dictionary and compile a call to it.
; If it's not there either, try to see if it's a number and compile a push of it. If it's not a
; number then there's nothing we can do, so error with missing_word
compile_handleword: ; ( word-ptr -- ? )
    dup
    call compile_tick
    call dupnz
    #if ; We found it in the compile-mode dictionary! ( word-ptr fn-ptr )
        swap ; clear the now-unneeded word ptr off the stack
        pop
        jmp ; call the word
    #end
    dup ; No compile dict entry but it could be a normal word ( word-ptr )
    call tick
    call dupnz
    #if ; It's a normal word, we'll compile a call to it instead
        swap
        pop
        push $CALL
        jmpr @compile_instruction_arg
    #end
    dup ; It's not a normal word either, maybe it's a number
    loadw is_number_hook
    call
    #if ; It's a number
        swap ; Blow away the now-useless word ptr
        pop
        push $PUSH ; Compile a push of the number
        jmpr @compile_instruction_arg
    #end
    jmpr @missing_word ; This isn't a valid word OR a number, so, bail

; Word handler for line-comment mode (backslash to end of line). It doesn't do a whole lot...
linecomment: ; ( word-start-addr -- )
    pop
    ret

; Word handler for paren-comment mode (anything in parens).
parencomment: ; ( word-start-addr -- )
    ; first check for a blank word and skip:
    dup
    load
    brz @end_pop1 ; blank?
    ; Now call tick to try to find it in the dictionary
    call tick ; ( entry-addr )
    ; If it is another open paren, do it again:
    dup
    xor open_paren_word ; ( entry-addr diff )
    brnz @+3
    pop
    jmp open_paren_word
    ; If it is the close-paren stub, we call it:
    xor close_paren_stub ; ( diff )
    brnz @+2
    jmp close_paren_word
    ret ; Else just leave

; Called when we expected to find something in the dictionary and didn't
invalid_mnemonic:
    push invalid_mnemonic_str
    jmpr @+3
missing_word:
    push missing_word_str
    call print
    call print
    jmp cr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

data_start: ; Just a marker for the stats to measure how long the text section is

; Some strings for error messages and whatnot
missing_word_str: .db "Not a word: \0"
invalid_mnemonic_str: .db "Invalid mnemonic: \0"
unclosed_error: .db "Unclosed string\0"
expected_word_err: .db "Expected name, found end of input\0"
print_stack_start: .db "<< \0"
print_stack_end: .db ">>\0"

#include "dictionary.asm"

; Assorted support variables
heap_ptr: .db heap_start ; holds the address in which to start the next heap entry
handleword_hook: .db immediate_handleword ; The current function used to handle / compile words, switches based on mode
is_number_hook: .db is_number ; The current function used to parse numbers, switches with hex / dec
itoa_hook: .db itoa ; The current function used to print numbers, switches with hex / dec
line_len: .db 0
cursor: .db 0 ; During calls to handleword, this global points to the beginning of the word

; pointer to head of runtime dictionary
dictionary: .db dict_start

; pointer to head of compile-time dictionary
compile_dictionary: .db compile_dict_start

; Terminal input buffer
tib: .db 0
.org tib + 0x100

; Scratch pad buffer
pad: .db 0
.org pad + 0x100

; A stack for compiling control structures
c_stack_ptr: .db c_stack
c_stack: .db 0
.org c_stack + 96

; Things we define start here:
heap_start:
