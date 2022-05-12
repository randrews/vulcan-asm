\ Needed words:
\ DONE: [ ] asm #asm >asm , postpone exit literal (foundational compiler interface)
\ DONE: create does> immediate ' ['] (foundational dictionary interface)
\ DONE: word number (foundational parser interface)
\ DONE: >r r> r@ rpick (because they aren't using the normal stack)
\ DONE: dec hex pad (because they modify global vars)
\ DONE: .s (because it uses sdp)
\ DONE: \ ) ( s" ." (because they deal with parser state)
\ DONE: . print compare ?dup (because we need asm ones anyway and it's free)

\ New words:
\ DONE: quit clears the return stack (setsdp), resets hooks, and jmps to the main loop.
\ DONE: &heap pushes the address of the heap pointer, so `here` is ``&heap @`
\ DONE: $ turns a mnemonic into an opcode. In normal mode it returns an opcode; in immediate in compiles a push of the opcode
\ DONE: asm is a word which compiles an opcode without an arg
\ DONE: #asm compiles an opcode with an arg, ( arg op -- )
\ DONE: >asm is a word taking an opcode which compiles that instruction, but with a 0 argument. The address of the argument is >r'd
\ DONE: continue compiles a jmp to a given word (a tail call)
\ DONE: resolve is an immediate word which pops the top address from the ctrl stack and writes `here` to it as a relative address

\ asm words:
\   asm compiles an opcode with no arg
\   #asm compiles an opcode with an arg
\   >asm compiles an opcode and >r's the address of its arg

\ note 1: why do you need exit?
\ Because the defn for semicolon needs to postpone something to compile a ret, and you can't use ,asm
\ because you'd have to pass it a word argument ("ret"). The normal answer to this is to create a new
\ word, ": exit ,asm ret ; immediate", but you would need semicolon to exist in order to do that.

\ begin again until while repeat do ?do loop +loop
\ /mod
\ variable
\ literal
\ negate abs even
\ <= >= 0> 0< 0= != u<= u>=
\ min max umin umax

create : ] create continue ] [
: ; postpone exit continue [ [ immediate
create execute $jmp asm 

\ Control structure words
: if >asm brz ; immediate
: then resolve ; immediate
: else r> >asm jmpr >r resolve ; immediate
: variable create 0 , does> ;

\ Counted loops, clean up the R stack if we want to early return
\ Removes the loop counter things from the R stack
: unloop r> r> drop drop ;

\ Counted loops, cause an early return on the next test
\ Sets the loop index equal to the counter
: leave r> drop r@ >r ;

\ Single-opcode words
: and asm and ;
: arshift asm arshift ;
: drop asm pop ;
: dup asm dup ;
: lshift asm lshift ;
: mod asm mod ;
: or asm or ;
: pick asm pick ;
: rot asm rot ;
: rshift asm rshift ;
: swap asm swap ;
: xor asm xor ;
: + asm add ;
: - asm sub ;
: * asm mul ;
: / asm div ;
: @ asm loadw ;
: ! asm storew ;
: c@ asm load ;
: c! asm store ;
: > asm agt ;
: < asm alt ;
: u> asm gt ;
: u< asm lt ;

\ Simple utils
\ : 2- 2 - ;
\ : 1- 1 - ;
\ : 2+ 2 + ;
\ : 1+ 1 + ;
\ : even 1 and asm not ;
: rdrop r> drop ;
: over 1 pick ;
: nip swap drop ;
: -rot rot rot ;
: tuck dup -rot ;
: emit 2 c! ;
: space 32 emit ;
: cr 10 emit ;
: +! dup @ rot + swap ! ;
: here &heap @ ;
: dup2 1 pick 1 pick ;
: allot &heap +! here ;
: negate -1 xor 1+ ;
: free negate &heap +! here ;
: c+! dup c@ rot + swap c! ;
: not -1 xor ;
: false 0 ;
: true 1 ;
: ror dup 1 rshift swap 23 lshift or ;
: rol dup 23 rshift swap 1 lshift or ;
\ : cell+ 3 allot ;
\ : cells 3 * allot ;
: = xor asm not ;

\ Things that require loops
: abs dup 0 < if negate then ;
: spaces 0 do space loop ;
