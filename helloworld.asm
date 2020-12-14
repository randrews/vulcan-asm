vram:   .equ 0x01a000

    .org 50
str: .db "Hello, there!\0"

    .org 0x100

    call clear
    push str
    push 0
    push 0
    call print

    setiv onkeypress
    inton
    hlt

    ;; --------------------------------------------------

onkeypress:
    hlt
    
    ;; --------------------------------------------------

print:                          ; (addr x y -- )
    mul 80
    add
    add vram                    ; addr start
printloop:
    pick 1
    load                        ; addr start byte
    dup
    brz @done
    pick 1
    store                       ; addr start
    add 1
    swap
    add 1
    swap
    jmpr @printloop
done:   ret

    ;; --------------------------------------------------

clear:  call clear_text
    call clear_colors
    ret

    ;; --------------------------------------------------

clear_text:  push 1200
clear_text_loop: dup
    brz @clear_text_done        ; Check for done
    sub 1                       ; Decrement offset
    dup                         ; num_left offset
    add vram                    ; num_left addr
    push 0
    swap                        ; num_left 0 addr
    store                       ; num_left
    jmpr @clear_text_loop
clear_text_done: pop
    ret

    ;; --------------------------------------------------

clear_colors:   push 1200
clear_colors_loop:  dup
    brz @clear_colors_done
    sub 1
    dup
    add vram + 1200
    push 0x07
    swap
    store
    jmpr @clear_colors_loop
clear_colors_done:  pop
    ret
