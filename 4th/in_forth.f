\ if then else
\ s" ." . pad word number
\ begin again until while repeat do ?do loop +loop unloop leave
\ ; exit
\ /mod = < >
: ?dup dup if dup then ;
: dup2 1 pick 1 pick ;
: emit 2 c! ;
: +! dup @ rot + swap ! ;
: c+! dup c@ rot + swap c! ;

\ foo bar
\ : allot free variable
\ [ ] , does> create postpone immediate literal
\ >r r> r@ rdrop rpick
\ recurse execute ' [']
\ negate abs even
: 2- 2 - ;
: 1- 1 - ;
: 2+ 2 + ;
: 1+ 1 + ;

\ depth rdepth
; over 1 pick ;
: nip swap drop ;
: -rot rot rot ;
: tuck dup -rot ;

\ here
\ u> u< <= >= 0> 0< 0= != u<= u>=
\ \ ( )
\ dec hex .s
: space 32 emit ;
: cr 10 emit ;
: spaces 0 do space loop ;
: print begin dup c@ ?dup while emit 1 + repeat ;

\ not ror rol
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

\ min max umin umax

\ compare

: cell+ 3 allot ;
: cells 3 * allot ;
