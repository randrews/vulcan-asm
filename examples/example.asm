.org 0x400 ; start here
    push 1
loop:
    dup
    store 0x02 ; write it to output
    add 1
    dup
    gt 10 ; have we done it 10 times yet?
    brz @loop
    hlt
