    ;; vram starts at 0x01ac00:
    ;; Two buffers of 80x60x2 text screens: 0x01ac00 and 0x01d180
    ;; 2048 bytes of font ram: 0x01f700
    ;; 16 bytes of foreground palette: 0x01ff00
    ;; 16 bytes of background palette: 0x01ff10

    .org 0x100

    ;; Code goes here

    hlt
    
