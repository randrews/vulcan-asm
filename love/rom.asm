.org 0x400
    loadw screen
    pushr
    push 0
clear_loop:
    push 65
    pick 1
    peekr
    add
    store
    add 2
    dup
    xor 2400
    brnz @clear_loop
    popr
    pop
    hlt

mode: .equ 10 ; Bottom three bits are mode: 0x1 is low text / high gfx, 0x2 is low low-res / high high-res, 0x4 is low direct high paletted
screen: .equ 11 ; byte address, start of screen
palette: .equ 14 ; Palette is last page
font: .equ 17 ; Font address is 2k behind palette
height: .equ 20 ; Number of total rows
width: .equ 23 ; number of bytes per row (only 128 displayed ever, this includes scrolling margin)
row_offset: .equ 26 ; Offset in rows between screen start and start of display.
col_offset: .equ 29 ; Offset in pixels / bytes between start of row and start of display
