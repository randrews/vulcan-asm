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
  local str !
  begin
    str @ 0xff and while
    str @ putc
    str 1 + str!
  again ;

" Hello, world! " puts

: count ( max -- )
  0 local sum !
  0 for n
    sum n + sum!
  loop ;

: log ( n -- )
  200 ! ;

1 log
10000 count
2 log

endl " Done " puts

endl

\ : keypress 3 log if putc else drop then inton 4 log ;

: printable? ( code -- bool )
  dup 0x300 and swap ( is-shift? code )
  0xff = ( is-shift? enter? )
  or not ;

variable r-shift
variable l-shift
: symbols " )!@#$%^&*( " ;

: is-number? ( key -- bool )
  dup 47 > swap 58 < and ;

: is-letter? ( key -- bool )
  dup 96 > swap 123 < and ;

: shiftify ( key -- char )
  r-shift @ l-shift @ or if \ if shifted?
     dup is-number? if 48 - symbols + @b exit end
     dup is-letter? if 32 - exit end
  end ;

: handle-key ( code up/down -- )
  when then \ if it's a press
    when dup printable? then
      shiftify putc \ echo printable chars
    when 1 then
      dup 0xff = if endl end \ next line on enter
      dup 0x100 = if 1 r-shift ! end \ set r-shift flag
      dup 0x200 = if 1 l-shift ! end \ set r-shift flag
      drop
    end
  when 1 then \ it's a release
    dup 0x100 = if 0 r-shift ! end \ set r-shift flag
    dup 0x200 = if 0 l-shift ! end \ set r-shift flag
    drop
  end ;

: int-vector ( ??? device -- )
  when dup 2 = then \ keyboard?
    drop handle-key
  when 1 then
    drop drop drop
  end
  inton ;

: re-enable inton ;
: fast drop 200 !b inton ;
setiv int-vector
\ setiv fast
inton
