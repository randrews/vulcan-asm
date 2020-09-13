: screen 0x001ac00 ;

: clear-screen ( -- )
    80 60 * 2 * 1 - 0 for offset
    0 screen offset :@ + !b
loop ;

: wait \ wait forever
    begin again ;

clear-screen
\ wait