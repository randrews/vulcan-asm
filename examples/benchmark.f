: screen 0x001a000 ;

: clear-screen ( -- )
    40 30 * 1 - 0 for offset
      0 screen offset + !b \ clear characters
      0x07 screen offset 1200 + + !b \ set color to fg-white, bg-black
    loop
;

clear-screen

variable cursor
0 cursor !

: 1+! ( var -- ) dup @ 1 + swap ! ;

: putc ( ch -- )
  screen cursor @ + !b
  cursor 1+! ;

: endl ( -- )
  cursor @ 40 + dup 40 mod - cursor ! ;

: puts ( str -- )
  local str str!
  begin
  str @ 0xff and while
  str @ putc
  str 1 + str!
  again ;

" Hello, world! " puts

: count ( max -- )
  local sum
  0 for n
  sum n + sum!
  loop ;

: log ( n -- )
  200 ! ;

1 log
10000 count
2 log

( 1 log
20000 count
2 log

1 log
40000 count
2 log )

endl " Done " puts

endl

\ : keypress 3 log if putc else drop then inton 4 log ;

: printable? ( code -- bool )
  dup 0x300 and swap ( is-shift? code )
  0xff = ( is-shift? enter? )
  or not ;

variable r-shift
variable l-shift

: is-number? ( key -- bool )
  dup 47 > swap 58 < and ;

: is-letter? ( key -- bool )
  dup 96 > swap 123 < and ;

: shiftify ( key -- char )
  r-shift @ l-shift @ or if \ if shifted?
     \ dup is-number? if 16 - exit then
     dup is-letter? if 32 - exit then
  then ;

: handle-key ( code up/down -- )
   if \ if it's a press
        dup printable? if
           shiftify putc \ echo printable chars
        else
           dup 0xff = if endl then \ next line on enter
           dup 0x100 = if 1 r-shift ! then \ set r-shift flag
           dup 0x200 = if 1 l-shift ! then \ set r-shift flag
           drop
        then
   else \ it's a release
       dup 0x100 = if 0 r-shift ! then \ set r-shift flag
       dup 0x200 = if 0 l-shift ! then \ set r-shift flag
       drop
   then ;

: int-vector ( ??? device -- )
    dup 2 = if \ keyboard?
        drop handle-key
    else
        drop drop drop
    then
    inton ;



: re-enable inton ;
: fast drop 200 !b inton ;
setiv int-vector
\ setiv fast
inton
