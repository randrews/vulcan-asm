create : ] create continue ] [
create execute ] asm jmp [
: ; postpone exit continue [ [ immediate

: if ,brz ; immediate
: then resolve ; immediate
: else r> ,jmpr >r resolve ; immediate
: variable create 0 , does> ;
: unloop r> r> drop drop ;
: leave r> drop r@ >r ;

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
: = xor asm not ;
: abs dup 0 < if negate then ;
: spaces 0 do space loop ;
