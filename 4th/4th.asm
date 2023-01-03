
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#include "utils.asm"
#include "dict_utils.asm"
#include "string.asm"
#include "compiler_utils.asm"
#include "numbers.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Interpret a line of input. The pointer to the (null-terminated) line is at the top of the stack.
; This cannot be put in the dictionary, because if it calls itself recursively it'll clobber the
; cursor, but it can be called from outside. It's the primary entry point to Forth.
eval: ; ( ptr -- ??? )
    ; First, if the last line left us in linecomment, get out of it:
    loadw handleword_hook
    xor linecomment
    #unless
        call nova_popr
        storew handleword_hook
    #end
    call skip_nonword ; Skip any leading whitespace
    storew cursor ; Store the pointer in the cursor, so it's not polluting the stack during handleword calls
    #while ; While we're not at the end of the string
        loadw cursor
        load
    #do
        loadw cursor ; Copy the word we care about to the heap
        push eval_word_buffer
        call nova_word_to
        loadw cursor ; Advance cursor by the word we just copied and the following crap
        call skip_word
        call skip_nonword
        storew cursor
        push eval_word_buffer ; Load the address we just put the word at and execute it
        loadw handleword_hook
        call
    #end
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Copy the word at cursor to the heap, null-terminate it, advance cursor to the start
; of the next word (or the null terminator if this is the last word); do not advance heap.
nova_word: ; ( -- )
    loadw cursor
    loadw heap
    call nova_word_to
    loadw cursor
    call skip_word
    call skip_nonword
    storew cursor
    loadw heap ; But what if the word is empty string?
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

nova_number:
    call nova_word
    loadw heap
    loadw is_number_hook
    call
    ret

; Creates a new dictionary entry, pointing at the (new) heap, for the following word
nova_create: ; ( -- )
    call nova_word ; consume a word and stick it on the heap
    loadw heap ; Load the heap ptr and advance it to the place right after the word's null-terminator
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
    loadw heap
    storew dictionary ; point the dictionary at it
    add 6
    storew heap ; advance the heap ptr
    ret

; Enter immediate mode or compile mode
nova_open_bracket: push immediate_handleword
    jmpr @+2
nova_close_bracket: push compile_handleword
    storew handleword_hook
    ret

;;; ; Compile a jmp to a word

nova_continue:
    call nova_tick
    push $JMP
    jmpr @compile_instruction_arg

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
    loadw heap
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
        loadw heap
        call compile_tick
        call dupnz
        #if ; It's a compile word
            push $CALL
            jmpr @compile_instruction_arg ; Compile a call to it.
        #else ; It's not a compile word either, error out
            loadw heap
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
    loadw heap
    dup
    add 3
    storew heap
    storew
    ret

; Normal interface for defining words
nova_colon:
    call nova_create
    jmp nova_close_bracket

; Normal interface for ending word definitions
nova_semicolon:
    push $RET
    call compile_instruction
    jmp nova_open_bracket

; Copy a word of input to the pad and return the pad address
nova_word_to_pad:
    loadw cursor
    push pad
    call nova_word_to
    loadw cursor
    call skip_word
    call skip_nonword
    storew cursor
    ret pad

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
    loadw heap
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
    loadw heap
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
.db "copy\0"
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
    loadw heap
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

; This is a hideous optimization thing. You have been warned:
; We need to call opcode for word and check the return value: if
; it's -1, that's an error, so we need to call invalid_mnemonic and
; then return. This pattern was all over the asm* words. But, the
; caller itself needs to do that return, so that if there's an error
; the rest of our caller doesn't happen. So, we'll try to fetch an
; opcode and check for a -1, and if we get one, we'll popr/pop and
; then return.
nova_safe_opcode:
    call nova_opcode_for_word
    dup
    xor -1
    #unless ; Thaaaat's not an opcode...
        pop ; toss the worthless error code
        popr ; get rid of our return address with a popr / pop, so we're
        pop  ; now actually returning from the caller's frame...
        jmp invalid_mnemonic ; and tail-call to invalid_mnemonic
    #end
    ret ; We actually got an opcode, just return it

; Don't try to optimize this away; see nova_safe_opcode. We need the
; extra frame, or a line like `$ blah 3` won't run the rest of the line
; after the error.
nova_opcode:
    call nova_safe_opcode
    ret

nova_compile_opcode:
    call nova_safe_opcode
    jmp nova_literal

; Read a mnemonic and compile that instruction with a 0 arg. The address of the arg
; gets >r'd, for later resolve-calling
nova_asm_to: ; ( opcode -- )
    loadw heap
    add 1
    call nova_pushr ; heap + 1 is our arg address, >r it
    swap 0
    jmp compile_instruction_arg ; Go ahead and compile the jmp-or-whatever

nova_here:
    loadw heap
    ret

find_word:
    call nova_word
    loadw heap
    call tick
    call dupnz
    #unless
        loadw heap
        call compile_tick
    #end
    ret

nova_tick:
    call find_word
    call dupnz
    #unless
        loadw heap
        jmp missing_word
    #end
    ret

nova_bracket_tick:
    call find_word
    call dupnz
    #unless
        loadw heap
        jmp missing_word
    #end
    ; Intentionally falls through to nova_literal!

; Compile-time word that reads a word from the stack at compile time and pushes it
; to the stack at runtime (which is to say, read a word at compile and compile a
; $PUSH of that word
nova_literal:
    push $PUSH
    jmp compile_instruction_arg

; Switch is_number_hook and itoa_hook between hex and dec mode
nova_dec:
    push is_number
    push itoa
    jmpr @+4
nova_hex:
    push hex_is_number
    push hex_itoa
    storew itoa_hook
    storew is_number_hook
    ret

; Fetch a single char from the input buffer, advancing the cursor
; If the cursor is already at the end (null term) don't advance it
nova_char: ; ( -- ch )
    loadw cursor
    load
    call dupnz
    #if
        loadw cursor
        add 1
        storew cursor
        ret
    #end
    ret 0

; Copies a string (until the first double quote) to the destination
; and null-terminates it. Increments cursor accordingly. Returns
; either the address after the string for success or 0 if it was unterminated.
nova_quote_string_to: ; ( dest -- flag )
    pushr
    #while
        call nova_char
        dup
        dup
        gt 0
        swap
        xor 34 ; ascii double quote
        gt 0
        and ; It's not a null-term and it's not a double quote
    #do
        peekr
        store
        popr
        add 1
        pushr
    #end
    #unless ; Unterminated string!
        popr
        pop
        push unclosed_error
        call print
        ret 0
    #end
    loadw cursor ; Skip any junk after the close quote; cursor always points at a valid word
    call skip_nonword
    storew cursor
    popr ; Yoink out our running pointer to the dest so we can null-term it
    dup ; ( here here )
    swap 0
    store ; null-term the string
    add 1 ; Increment it so we return the point after the string (counting its null-term)
    ret

; Compiles a string to the heap and pushes a pointer to it
nova_squote: ; ( -- addr )
    loadw heap
    dup
    pushr
    call nova_quote_string_to
    call dupnz
    #if
        storew heap
        popr
    #else
        popr
        pop
    #end
    ret

; The s-quote equivalent in compile mode:
nova_compile_squote:
    loadw heap
    pushr
    push $JMPR
    call push_jump ; compile a jmpr to get us past the string
    call nova_squote ; ( addr )
    ;;;
    loadw heap ; squote might have failed and not actually compiled anything
    sub 4          ; (because of an unterminated string) We'll handle that:
    peekr          ; Detect if our saved heap is the current heap - 4, meaning
    xor            ; that all we've compiled is that jmp...
    #unless
        popr ; So just restore that saved heap
        storew heap
        ret
    #end
    ;;;
    call nova_resolve ; Jump to right after the null-terminator
    ; compile a push with the string start
    push $PUSH ; ( addr $push )
    call compile_instruction_arg
    popr
    pop
    ret

; Read a quote string to the pad and then print it
nova_dotquote:
    push pad
    call nova_quote_string_to
    #if
        push pad
        jmp print
    #end
    ret

; The dot-quote equivalent in compile mode:
nova_compile_dotquote:
    loadw heap ; store the heap at start
    pushr
    call nova_compile_squote
    loadw heap ; see if nova_compile_squote actually changed it
    popr
    xor
    #if ; we actually compiled something, compile a call to print
        push print
        push $CALL
        jmp compile_instruction_arg
    #end
    ret

; Print the current stack contents, in order from 256 up, separated by spaces
; TODO this depends on a 256-based stack and will need to be changed if you call setsdp
nova_print_stack: ; ( -- )
    push print_stack_start
    call print
    sdp
    sub 6
    pushr
    pop
    push 256
    #while
        dup
        peekr
        lt
    #do
        dup
        loadw
        loadw itoa_hook
        call
        push 32
        call nova_emit
        add 3
    #end
    popr
    pop
    pop
    push print_stack_end
    call print
    ret

; The R stack is built manually with these fns, because it can't be the actual
; CPU return stack for reasons.

; The equivalent of peekr
nova_peekr:
    loadw r_stack_ptr
    sub 3
    loadw
    ret

; Pick from the R stack
nova_rpick: ; ( i -- c_stack[i] ) where the top of the R stack is '0 rpick'
    loadw r_stack_ptr
    swap
    add 1
    mul 3
    sub
    loadw
    ret

; Equivalent of pushr
nova_pushr: ; ( val -- )
    loadw r_stack_ptr
    dup
    add 3
    storew r_stack_ptr
    storew
    ret

; Equivalent of popr
nova_popr: ; ( -- val )
    loadw r_stack_ptr
    sub 3
    dup
    storew r_stack_ptr
    loadw
    ret

nova_emit:
    loadw emit_hook
    jmp

; For a temporary function, we compile it to the heap
; and then move the heap back to the start (so it gets
; overwritten if we need the memory)
nova_immediate_open_brace:
    ; store heap addr
    loadw heap
    storew lambda_start_ptr
    ; enter compile mode
    jmp nova_close_bracket

; But, if we do this in compile mode, then we want to
; make a local function: something compiled that can be
; called, whose address is left on the stack
nova_compile_open_brace:
    push $JMPR ; Jmp over the lambda
    call push_jump
    loadw heap
    call nova_pushr ; Store start address of lambda
    ; increment nesting count
    loadw lambda_nesting_level
    add 1
    storew lambda_nesting_level
    ret

nova_close_brace:
    loadw lambda_nesting_level
    call dupnz
    #if ; we entered this from compile mode
        ; decrement nesting level
        sub 1
        storew lambda_nesting_level
        ; compile a ret
        push $RET
        call compile_instruction
        ; Get the lambda addr and temp store it
        call nova_popr
        pushr
        call nova_resolve ; Resolve the earlier jmp so we jmp over the lambda
        ; Compile a push of the lambda address
        popr
        push $PUSH
        call compile_instruction_arg
        ret
    #else
        push $RET
        call compile_instruction
        loadw lambda_start_ptr
        dup
        storew heap
        jmp nova_open_bracket
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
    dup
    load
    #unless ; Is the word just blank?
        pop
        ret
    #end
    call tick ; ( entry-addr-or-0 )
    dup
    xor open_paren
    #unless ; Is the new word "("?
        pop
        jmp open_paren
    #end
    xor close_paren_stub
    #unless ; Is it the ")" stub?
        jmp close_paren ; Call close_paren
    #end
    ret ; It was something else (or zero) so just ignore it, it's a comment

; Store the current handleword_hook in the R stack, put parencomment in its place.
; It won't matter because it's not like anything's gonna be looking in the rstack
; while we eval a comment.
open_paren:
    loadw handleword_hook
    call nova_pushr
    push parencomment
    storew handleword_hook
    ret

; Store the current handleword_hook in the C stack,
; put parencomment in its place.
; We also have a "stub" word which is what the dict actually
; points to, so that a mismatched close paren doesn't end
; up actually doing anything (it's only callable from / by
; parencomment)
close_paren:
    call nova_popr
    storew handleword_hook
close_paren_stub:
    ret

; Store the current handleword_hook in the C stack,
; put linecomment in its place. When handleline starts,
; if it sees that handleword_hook is linecomment, it'll
; pop the old one back out.
backslash:
    loadw handleword_hook
    call nova_pushr
    push linecomment
    storew handleword_hook
    ret

; Called when we expected to find something in the dictionary and didn't
invalid_mnemonic:
    push invalid_mnemonic_str
    jmpr @+3
missing_word:
    push missing_word_str
    call print
    call print
    call cr ; Runs through to quit!
quit: ; Break out of whatever we were doing and return to the main loop:
    push 0x400
    setsdp 0x100 ; Reset the dp / sp to default values
    push r_stack
    storew r_stack_ptr ; Clear the Nova rstack
    call nova_open_bracket ; Get us out of compile mode if we're in it
    loadw quit_vector
    jmp ; Go back to the prompt. This will eventually be a prompt.

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
heap: .db heap_start ; holds the address in which to start the next heap entry
handleword_hook: .db immediate_handleword ; The current function used to handle / compile words, switches based on mode
is_number_hook: .db is_number ; The current function used to parse numbers, switches with hex / dec
itoa_hook: .db itoa ; The current function used to print numbers, switches with hex / dec
line_len: .db 0
cursor: .db 0 ; During calls to handleword, this global points to the beginning of the word
lambda_start_ptr: .db 0 ; After definition of a lambda, reset heap ptr to here
lambda_nesting_level: .db 0 ; Nesting level of lambdas; 0 means not in a compile-mode lambda

; pointer to head of runtime dictionary
dictionary: .db dict_start

; pointer to head of compile-time dictionary
compile_dictionary: .db compile_dict_start

; where to jump when they call `quit`
quit_vector: .db 0x400

; the place to call to emit a character
emit_hook: .db emit

; Scratch pad buffer
pad: .db 0
.org pad + 0x100

; A buffer to hold the single word currently being evaluated:
; We need a separate buffer for this because of anonymous fns;
; we no longer want to carelessly overwrite the bottom of the heap when it might contain
; a temporary brace-function. One semi-bad side effect of this is that we can no longer
; handle a word longer than 32 chars, but what can you do?
eval_word_buffer: .db 0
.org eval_word_buffer + 32

; A stack for compiling control structures
r_stack_ptr: .db r_stack
r_stack: .db 0
.org r_stack + 96

; Things we define start here:
heap_start:
