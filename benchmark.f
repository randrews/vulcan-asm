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

1 log
20000 count
2 log

1 log
40000 count
2 log

endl " Done " puts
