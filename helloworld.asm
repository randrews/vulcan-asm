vram:   .equ 0x01ac00

    .org 50
str: .db "Hello, there!\0"

    .org 0x100

    push str
    push 0
    push 0
    call print

loop:   jmp loop

    hlt
    
print:                          ; (addr x y -- )
    mul 80
    add
    add vram                    ; addr start
printloop:
    pick 1
    load                        ; addr start byte
    dup
    brnz 3
    ret
    pick 1
    store                       ; addr start
    add 1
    swap
    add 1
    swap
    jmp printloop
