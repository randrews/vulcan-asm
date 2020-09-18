: screen 0x001a000 ;

: clear-screen ( -- )
    40 30 * 1 - 0 for offset
      0 screen offset + !b \ clear characters
      0x07 screen offset 1200 + + !b \ set color to fg-white, bg-black
    loop
;

: wait \ wait forever
    begin again ;

clear-screen
\ wait

variable cursor
0 cursor !

: 1+!
    dup @ 1 + swap ! ;

: putc ( ch -- )
    screen cursor @ + !
    cursor 1+! ;

: keypress ( key state -- )
    if putc else drop then
    inton ;

setiv keypress
inton