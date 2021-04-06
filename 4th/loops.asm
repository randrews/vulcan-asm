; Uncounted loops: begin marks the current location...
begin_word:
    loadw heap_ptr
    call push_c_addr
    ret

; Uncounted loops: ...and again jumps back to it
again_word:
    call pop_c_addr
    loadw heap_ptr
    sub
    push $JMPR
    call compile_instruction_arg
    ret

; Uncounted loops: until is like again, but only until TOS is nonzero
until_word:
    call pop_c_addr
    loadw heap_ptr
    sub
    push $BRZ
    call compile_instruction_arg
    ret

; Uncounted loops: while is an unresolved brz...
while_word:
    ; Compile an unresolved brz
    push $BRZ
    call push_jump
    ret

; Uncounted loops: ...to the following repeat, which will either bust out of
; the loop or jump back to the begin. So, begin ... while ... repeat
repeat_word:
    ; temporarily store while's thing
    call pop_c_addr
    pushr
    ; Now top of c stack is the begin, so, jmpr to that
    call pop_c_addr
    loadw heap_ptr
    sub
    push $JMPR
    call compile_instruction_arg
    ; put while's thing back
    popr
    call push_c_addr
    ; resolve while's brz:
    loadw heap_ptr
    call resolve_c_addr
    ret


; Counted loops: utility to compile instructions to >r loop limit / index:
compile_loop_counters:
    push $SWAP
    call compile_instruction
    push push_c_addr
    push $CALL
    pick 1
    pick 1
    call compile_instruction_arg
    call compile_instruction_arg
    ret

; Counted loops: limit index do .. loop
; Compiles a swap and two to_rs to initialize the loop, then stores the address
; for loop / +loop to jump back to.
do_word:
    call compile_loop_counters
    push 0
    call push_c_addr ; push a placeholder 0, because ?do puts a brz there
    loadw heap_ptr
    call push_c_addr ; Push the loop start address
    ret

; Counted loops: limit index ?do .. loop (same thing but runs the test first)
; Compiles a call to pretest_loop and then a brz to an unresolved address
pretest_do_word:
    call compile_loop_counters
    push 0
    push $PUSH
    call compile_instruction_arg ; The pretest doesn't increment the counter
    push test_loop
    push $CALL
    call compile_instruction_arg ; call test_loop at the start
    push 0
    push $BRZ
    call compile_instruction_arg ; and brz to the end of the loop
    loadw heap_ptr
    sub 3
    call push_c_addr ; which we'll have to resolve later
    loadw heap_ptr
    call push_c_addr ; and now we have a loop start address
    ret

; loop_word compiles a call to this; it increments the index by TOS and leaves a
; flag indicating whether to jump back to the loop start.
test_loop: ; ( incr -- repeat? )
    call pop_c_addr
    add
    call pop_c_addr ; ( index limit ), nothing on R
    dup
    call push_c_addr
    pick 1
    call push_c_addr ; ( index limit ), recreated R
    swap
    gt
    ret

; Counted loops: limit index do ... loop
; Increments the counter and tests whether to continue the loop. Then, checks the top of
; the c stack: if it's nonzero, resolve it to heap_ptr (to make ?do work)
loop_word:
    push 1
    push $PUSH
    call compile_instruction_arg ; if (only if) this is not +loop, push a default 1
plusloop_word:
    push test_loop
    push $CALL
    call compile_instruction_arg ; call test_loop to see if we should continue
    call pop_c_addr
    loadw heap_ptr
    sub
    push $BRNZ
    call compile_instruction_arg ; brnz back to the start of the body
    ; this is the end of loop that ?do should be brz-ing to:
    call w_peek_r ; checking the top of the c stack, this is nonzero if we used ?do:
    brz @loop_word_posttest
    loadw heap_ptr
    call resolve_c_addr
    jmpr @loop_word_cleanup
loop_word_posttest:
    call pop_c_addr
    pop
loop_word_cleanup:
    push unloop_word
    push $CALL
    call compile_instruction_arg ; call unloop to clean up the counters
    ret

; Counted loops, clean up the R stack if we want to early return
; Removes the loop counter things from the R stack
unloop_word:
    call pop_c_addr
    pop
    call pop_c_addr
    pop
    ret

; Counted loops, cause an early return on the next test
; Sets the loop index equal to the counter
leave_word:
    call pop_c_addr
    pop
    call w_peek_r
    call push_c_addr
    ret
