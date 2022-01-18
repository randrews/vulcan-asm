\ Needed words:
\ [ ] asm #asm , postpone (foundational compiler interface)
\ create does> immediate (foundational dictionary interface)
\ >r r> r@ rdrop rpick (because they aren't using the normal stack)
\ dec hex pad (because they modify global vars)
\ depth rdepth .s (because they use sdp)
\ \ ( ) s" ." (because they deal with parser state)

\ New words:
\ &heap pushes the address of the heap pointer, so `here` is ``&heap @`
: here &heap @ ;

\ if then else
\ . word number
\ begin again until while repeat do ?do loop +loop unloop leave
\ ; exit
\ /mod = < >
: ?dup dup if dup then ;
: dup2 1 pick 1 pick ;
: emit 2 c! ;
: +! dup @ rot + swap ! ;
: c+! dup c@ rot + swap c! ;

\ : variable
create : ] create postpone ] [
: allot &heap +! here ;
: free negate &heap +! here ;

\ literal
\ recurse execute ' [']
\ negate abs even
: 2- 2 - ;
: 1- 1 - ;
: 2+ 2 + ;
: 1+ 1 + ;

; over 1 pick ;
: nip swap drop ;
: -rot rot rot ;
: tuck dup -rot ;

: space 32 emit ;
: cr 10 emit ;
: spaces 0 do space loop ;
: print begin dup c@ ?dup while emit 1 + repeat ;

: not -1 xor ;
: xor asm xor ;
: or asm or ;
: and asm and ;
: pick asm pick ;
: dup asm dup ;
: drop asm pop ;
: swap asm swap ;
: arshift asm arshift ;
: rshift asm rshift ;
: lshift asm lshift ;
: rot asm rot ;
: + asm add ;
: - asm sub ;
: * asm mul ;
: / asm div ;
: mod asm mod ;
: @ asm loadw ;
: ! asm storew ;
: c@ asm load ;
: c! asm store ;
: false 0 ;
: true 1 ;
: ror dup 1 rshift swap 23 lshift or ;
: rol dup 23 rshift swap 1 lshift or ;

\ u> u< <= >= 0> 0< 0= != u<= u>=
\ min max umin umax

\ compare

: cell+ 3 allot ;
: cells 3 * allot ;
