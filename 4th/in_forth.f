\ Needed words:
\ [ ] asm #asm , postpone (foundational compiler interface)
\ create does> immediate (foundational dictionary interface)
\ >r r> r@ rdrop rpick (because they aren't using the normal stack)
\ dec hex pad (because they modify global vars)
\ depth rdepth .s (because they use sdp)
\ \ ( ) s" ." (because they deal with parser state)
\ compare (because we need an asm one anyway and it's free)

\ New words:
\ &heap pushes the address of the heap pointer, so `here` is ``&heap @`
\ quit exists in both dictionaries, clears the stack (setsdp) and jmps to the main loop.
\ asm and #asm are immediate words which compile an opcode with or without an arg
\ ,asm and ,#asm are immediate words which compile the instructions to compile an opcode
\ continue compiles a jmp to a given word (a tail call)
\ ,brz ,brnz and ,jmpr are immediate words which compile those instructions, but with a 0 argument. The address of the argument is >r'd
\ ,ret compiles a ret with no argument. It's needed to define semicolon (see note 1)
\ resolve is an immediate word which pops the top address from the ctrl stack and writes `here` to it.

\ note 1: why do you need ,ret?
\ Because the defn for semicolon needs to postpone something to compile a ret, and you can't use ,asm
\ because you'd have to pass it a word argument ("ret"). The normal answer to this is to create a new
\ word, ": ,ret ,asm ret ; immediate", but you would need semicolon to exist in order to do that.

\ . word number
\ begin again until while repeat do ?do loop +loop unloop leave
\ /mod = < >
\ : variable
\ literal
\ recurse execute ' [']
\ negate abs even
\ u> u< <= >= 0> 0< 0= != u<= u>=
\ min max umin umax

create : ] create continue ] [
: ; postpone ,ret continue [ [ immediate

\ Control structure words
: exit ,ret ; immediate
: if ,brz ; immediate
: then resolve ; immediate
: else r> ,jmpr >r resolve ; immediate

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

\ Simple utils
: 2- 2 - ;
: 1- 1 - ;
: 2+ 2 + ;
: 1+ 1 + ;
; over 1 pick ;
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
: cell+ 3 allot ;
: cells 3 * allot ;

\ Things that require loops
: ?dup dup if dup then ;
: spaces 0 do space loop ;
: print begin dup c@ ?dup while emit 1 + repeat ;
