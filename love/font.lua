function load_font(mem, addr)
    local i = 0
    local function char(bytes)
        for n = 0, 7 do
            mem[addr + i + n] = bytes[n + 1]
        end
        i = i + 8
    end

    char { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x7e, 0x81, 0xa5, 0x81, 0xbd, 0x99, 0x81, 0x7e }
    char { 0x7c, 0xfe, 0xd6, 0xba, 0xc6, 0xfe, 0x7c, 0x00 }
    char { 0xc6, 0xee, 0xfe, 0xfe, 0x7c, 0x38, 0x10, 0x00 }
    char { 0x10, 0x38, 0x7c, 0xfe, 0x7c, 0x38, 0x10, 0x00 }
    char { 0x10, 0x38, 0x10, 0xee, 0xee, 0x10, 0x38, 0x00 }
    char { 0x38, 0x7c, 0xfe, 0xfe, 0x6c, 0x10, 0x38, 0x00 }
    char { 0x00, 0x18, 0x3c, 0x7e, 0x3c, 0x18, 0x00, 0x00 }
    char { 0xff, 0xe7, 0xc3, 0x81, 0xc3, 0xe7, 0xff, 0xff }
    char { 0x00, 0x18, 0x3c, 0x66, 0x66, 0x3c, 0x18, 0x00 }
    char { 0xff, 0xe7, 0xc3, 0x99, 0x99, 0xc3, 0xe7, 0xff }
    char { 0x1e, 0x0e, 0x1e, 0x36, 0x78, 0xcc, 0xcc, 0x78 }
    char { 0x7e, 0xc3, 0xc3, 0x7e, 0x18, 0x7e, 0x18, 0x18 }
    char { 0x1e, 0x1a, 0x1e, 0x18, 0x18, 0x70, 0xf0, 0x60 }
    char { 0x3e, 0x3e, 0x36, 0x36, 0xf6, 0x66, 0x1e, 0x0c }
    char { 0xdb, 0x3c, 0x66, 0xe7, 0x66, 0x3c, 0xdb, 0x00 }
    char { 0x80, 0xc0, 0xf0, 0xf8, 0xf0, 0xc0, 0x80, 0x00 }
    char { 0x02, 0x06, 0x1e, 0x3e, 0x1e, 0x06, 0x02, 0x00 }
    char { 0x18, 0x3c, 0x7e, 0x18, 0x7e, 0x3c, 0x18, 0x00 }
    char { 0x66, 0x66, 0x66, 0x66, 0x66, 0x00, 0x66, 0x00 }
    char { 0x7f, 0xdb, 0x7b, 0x3b, 0x1b, 0x1b, 0x1b, 0x00 }
    char { 0x3c, 0x66, 0x38, 0x6c, 0x6c, 0x38, 0xcc, 0x78 }
    char { 0x00, 0x00, 0x00, 0x00, 0xfe, 0xfe, 0xfe, 0x00 }
    char { 0x18, 0x3c, 0x7e, 0x18, 0x7e, 0x3c, 0x18, 0x7e }
    char { 0x18, 0x3c, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x00 }
    char { 0x18, 0x18, 0x18, 0x18, 0x7e, 0x3c, 0x18, 0x00 }
    char { 0x00, 0x18, 0x1c, 0xfe, 0x1c, 0x18, 0x00, 0x00 }
    char { 0x00, 0x30, 0x70, 0xfe, 0x70, 0x30, 0x00, 0x00 }
    char { 0x00, 0x00, 0xc0, 0xc0, 0xc0, 0xfe, 0x00, 0x00 }
    char { 0x00, 0x24, 0x66, 0xff, 0x66, 0x24, 0x00, 0x00 }
    char { 0x00, 0x10, 0x38, 0x7c, 0x7c, 0xfe, 0x00, 0x00 }
    char { 0x00, 0xfe, 0x7c, 0x7c, 0x38, 0x10, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x18, 0x3c, 0x3c, 0x18, 0x18, 0x00, 0x18, 0x00 }
    char { 0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x6c, 0x6c, 0xfe, 0x6c, 0xfe, 0x6c, 0x6c, 0x00 }
    char { 0x18, 0x7e, 0xc0, 0x7c, 0x06, 0xfc, 0x18, 0x00 }
    char { 0x00, 0xc6, 0x0c, 0x18, 0x30, 0x60, 0xc6, 0x00 }
    char { 0x38, 0x6c, 0x38, 0x76, 0xcc, 0xcc, 0x76, 0x00 }
    char { 0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x18, 0x30, 0x60, 0x60, 0x60, 0x30, 0x18, 0x00 }
    char { 0x60, 0x30, 0x18, 0x18, 0x18, 0x30, 0x60, 0x00 }
    char { 0x00, 0xee, 0x7c, 0xfe, 0x7c, 0xee, 0x00, 0x00 }
    char { 0x00, 0x18, 0x18, 0x7e, 0x18, 0x18, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30, 0x00 }
    char { 0x00, 0x00, 0x00, 0xfe, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x38, 0x00 }
    char { 0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x80, 0x00 }
    char { 0x7c, 0xc6, 0xce, 0xde, 0xf6, 0xe6, 0x7c, 0x00 }
    char { 0x18, 0x78, 0x18, 0x18, 0x18, 0x18, 0x7e, 0x00 }
    char { 0x7c, 0xc6, 0x0c, 0x18, 0x30, 0x66, 0xfe, 0x00 }
    char { 0x7c, 0xc6, 0x06, 0x3c, 0x06, 0xc6, 0x7c, 0x00 }
    char { 0x0c, 0x1c, 0x3c, 0x6c, 0xfe, 0x0c, 0x0c, 0x00 }
    char { 0xfe, 0xc0, 0xfc, 0x06, 0x06, 0xc6, 0x7c, 0x00 }
    char { 0x7c, 0xc6, 0xc0, 0xfc, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0xfe, 0xc6, 0x06, 0x0c, 0x18, 0x18, 0x18, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0x7c, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0x7e, 0x06, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0x1c, 0x1c, 0x00, 0x00, 0x1c, 0x1c, 0x00 }
    char { 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30 }
    char { 0x0c, 0x18, 0x30, 0x60, 0x30, 0x18, 0x0c, 0x00 }
    char { 0x00, 0x00, 0xfe, 0x00, 0x00, 0xfe, 0x00, 0x00 }
    char { 0x60, 0x30, 0x18, 0x0c, 0x18, 0x30, 0x60, 0x00 }
    char { 0x7c, 0xc6, 0x06, 0x0c, 0x18, 0x00, 0x18, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0xde, 0xdc, 0xc0, 0x7e, 0x00 }
    char { 0x38, 0x6c, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0x00 }
    char { 0xfc, 0x66, 0x66, 0x7c, 0x66, 0x66, 0xfc, 0x00 }
    char { 0x3c, 0x66, 0xc0, 0xc0, 0xc0, 0x66, 0x3c, 0x00 }
    char { 0xf8, 0x6c, 0x66, 0x66, 0x66, 0x6c, 0xf8, 0x00 }
    char { 0xfe, 0xc2, 0xc0, 0xf8, 0xc0, 0xc2, 0xfe, 0x00 }
    char { 0xfe, 0x62, 0x60, 0x7c, 0x60, 0x60, 0xf0, 0x00 }
    char { 0x7c, 0xc6, 0xc0, 0xc0, 0xde, 0xc6, 0x7c, 0x00 }
    char { 0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0x00 }
    char { 0x3c, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0x3c, 0x18, 0x18, 0x18, 0xd8, 0xd8, 0x70, 0x00 }
    char { 0xc6, 0xcc, 0xd8, 0xf0, 0xd8, 0xcc, 0xc6, 0x00 }
    char { 0xf0, 0x60, 0x60, 0x60, 0x60, 0x62, 0xfe, 0x00 }
    char { 0xc6, 0xee, 0xfe, 0xd6, 0xd6, 0xc6, 0xc6, 0x00 }
    char { 0xc6, 0xe6, 0xe6, 0xf6, 0xde, 0xce, 0xc6, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0xfc, 0x66, 0x66, 0x7c, 0x60, 0x60, 0xf0, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xd6, 0x7c, 0x06 }
    char { 0xfc, 0xc6, 0xc6, 0xfc, 0xd8, 0xcc, 0xc6, 0x00 }
    char { 0x7c, 0xc6, 0xc0, 0x7c, 0x06, 0xc6, 0x7c, 0x00 }
    char { 0x7e, 0x5a, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00 }
    char { 0xc6, 0xc6, 0xd6, 0xd6, 0xfe, 0xee, 0xc6, 0x00 }
    char { 0xc6, 0x6c, 0x38, 0x38, 0x38, 0x6c, 0xc6, 0x00 }
    char { 0x66, 0x66, 0x66, 0x3c, 0x18, 0x18, 0x3c, 0x00 }
    char { 0xfe, 0x86, 0x0c, 0x18, 0x30, 0x62, 0xfe, 0x00 }
    char { 0x7c, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7c, 0x00 }
    char { 0xc0, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x02, 0x00 }
    char { 0x7c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x7c, 0x00 }
    char { 0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff }
    char { 0x30, 0x30, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0xe0, 0x60, 0x7c, 0x66, 0x66, 0x66, 0xfc, 0x00 }
    char { 0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc6, 0x7c, 0x00 }
    char { 0x1c, 0x0c, 0x7c, 0xcc, 0xcc, 0xcc, 0x7e, 0x00 }
    char { 0x00, 0x00, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00 }
    char { 0x1c, 0x36, 0x30, 0xfc, 0x30, 0x30, 0x78, 0x00 }
    char { 0x00, 0x00, 0x76, 0xce, 0xc6, 0x7e, 0x06, 0x7c }
    char { 0xe0, 0x60, 0x7c, 0x66, 0x66, 0x66, 0xe6, 0x00 }
    char { 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0x0c, 0x00, 0x1c, 0x0c, 0x0c, 0x0c, 0xcc, 0x78 }
    char { 0xe0, 0x60, 0x66, 0x6c, 0x78, 0x6c, 0xe6, 0x00 }
    char { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x1c, 0x00 }
    char { 0x00, 0x00, 0x6c, 0xfe, 0xd6, 0xd6, 0xc6, 0x00 }
    char { 0x00, 0x00, 0xdc, 0x66, 0x66, 0x66, 0x66, 0x00 }
    char { 0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0x00, 0xdc, 0x66, 0x66, 0x7c, 0x60, 0xf0 }
    char { 0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0x1e }
    char { 0x00, 0x00, 0xdc, 0x66, 0x60, 0x60, 0xf0, 0x00 }
    char { 0x00, 0x00, 0x7c, 0xc0, 0x7c, 0x06, 0x7c, 0x00 }
    char { 0x30, 0x30, 0xfc, 0x30, 0x30, 0x36, 0x1c, 0x00 }
    char { 0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x76, 0x00 }
    char { 0x00, 0x00, 0xc6, 0xc6, 0x6c, 0x38, 0x10, 0x00 }
    char { 0x00, 0x00, 0xc6, 0xc6, 0xd6, 0xfe, 0x6c, 0x00 }
    char { 0x00, 0x00, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0x00 }
    char { 0x00, 0x00, 0xc6, 0xc6, 0xce, 0x76, 0x06, 0x7c }
    char { 0x00, 0x00, 0xfc, 0x98, 0x30, 0x64, 0xfc, 0x00 }
    char { 0x0e, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0e, 0x00 }
    char { 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00 }
    char { 0x70, 0x18, 0x18, 0x0e, 0x18, 0x18, 0x70, 0x00 }
    char { 0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x10, 0x38, 0x38, 0x6c, 0x6c, 0xfe, 0x00 }
    char { 0x3c, 0x66, 0xc0, 0x66, 0x3c, 0x18, 0xcc, 0x78 }
    char { 0x00, 0xc6, 0x00, 0xc6, 0xc6, 0xce, 0x76, 0x00 }
    char { 0x0e, 0x00, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00 }
    char { 0x7c, 0xc6, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0xc6, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0xe0, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0x38, 0x38, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0x00, 0x00, 0x7c, 0xc0, 0x7c, 0x18, 0x6c, 0x38 }
    char { 0x7c, 0xc6, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00 }
    char { 0xc6, 0x00, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00 }
    char { 0xe0, 0x00, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00 }
    char { 0x66, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0x7c, 0xc6, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0xe0, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0xc6, 0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0xc6, 0x00 }
    char { 0x38, 0x38, 0x00, 0x7c, 0xc6, 0xfe, 0xc6, 0x00 }
    char { 0x0e, 0x00, 0xfe, 0xc0, 0xf8, 0xc0, 0xfe, 0x00 }
    char { 0x00, 0x00, 0x6c, 0x9a, 0x7e, 0xd8, 0x6e, 0x00 }
    char { 0x7e, 0xd8, 0xd8, 0xfe, 0xd8, 0xd8, 0xde, 0x00 }
    char { 0x7c, 0xc6, 0x00, 0x7c, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0xc6, 0x00, 0x7c, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0xe0, 0x00, 0x7c, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x7c, 0xc6, 0x00, 0xc6, 0xc6, 0xce, 0x76, 0x00 }
    char { 0x00, 0xe0, 0x00, 0xc6, 0xc6, 0xce, 0x76, 0x00 }
    char { 0x00, 0xc6, 0x00, 0xc6, 0xce, 0x76, 0x06, 0x7c }
    char { 0xc6, 0x38, 0x6c, 0xc6, 0xc6, 0x6c, 0x38, 0x00 }
    char { 0xc6, 0x00, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0x18, 0x7e, 0xd8, 0xd8, 0x7e, 0x18, 0x00 }
    char { 0x38, 0x6c, 0x60, 0xf0, 0x66, 0xf6, 0x6c, 0x00 }
    char { 0xc3, 0x66, 0x3c, 0x7e, 0x18, 0x3c, 0x18, 0x00 }
    char { 0xfc, 0xc6, 0xfc, 0xcc, 0xde, 0xcc, 0xce, 0x00 }
    char { 0x0c, 0x1e, 0x18, 0x7e, 0x18, 0x18, 0xd8, 0x70 }
    char { 0x0e, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x7e, 0x00 }
    char { 0x1c, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00 }
    char { 0x00, 0x0e, 0x00, 0x7c, 0xc6, 0xc6, 0x7c, 0x00 }
    char { 0x00, 0x0e, 0x00, 0xcc, 0xcc, 0xdc, 0x76, 0x00 }
    char { 0x00, 0xfc, 0x00, 0xbc, 0x66, 0x66, 0xe6, 0x00 }
    char { 0xfe, 0x00, 0xc6, 0xe6, 0xf6, 0xce, 0xc6, 0x00 }
    char { 0x38, 0x6c, 0x3e, 0x00, 0x7e, 0x00, 0x00, 0x00 }
    char { 0x7c, 0xc6, 0x7c, 0x00, 0x7c, 0x00, 0x00, 0x00 }
    char { 0x18, 0x00, 0x18, 0x30, 0x60, 0x66, 0x3c, 0x00 }
    char { 0x00, 0x00, 0x00, 0x7c, 0x60, 0x60, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x7c, 0x0c, 0x0c, 0x00, 0x00 }
    char { 0xc0, 0xcc, 0xd8, 0x30, 0x7c, 0x36, 0x0c, 0x3e }
    char { 0xc0, 0xcc, 0xd8, 0x30, 0x6c, 0x3c, 0x7e, 0x0c }
    char { 0x18, 0x00, 0x18, 0x18, 0x3c, 0x3c, 0x18, 0x00 }
    char { 0x00, 0x36, 0x6c, 0xd8, 0x6c, 0x36, 0x00, 0x00 }
    char { 0x00, 0xd8, 0x6c, 0x36, 0x6c, 0xd8, 0x00, 0x00 }
    char { 0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88 }
    char { 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa }
    char { 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77 }
    char { 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x18, 0x18, 0xf8, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18 }
    char { 0x36, 0x36, 0x36, 0x36, 0xf6, 0x36, 0x36, 0x36 }
    char { 0x00, 0x00, 0x00, 0x00, 0xfe, 0x36, 0x36, 0x36 }
    char { 0x00, 0x00, 0xf8, 0x18, 0xf8, 0x18, 0x18, 0x18 }
    char { 0x36, 0x36, 0xf6, 0x06, 0xf6, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36, 0x36 }
    char { 0x00, 0x00, 0xfe, 0x06, 0xf6, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0xf6, 0x06, 0xfe, 0x00, 0x00, 0x00 }
    char { 0x36, 0x36, 0x36, 0x36, 0xfe, 0x00, 0x00, 0x00 }
    char { 0x18, 0x18, 0xf8, 0x18, 0xf8, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0xf8, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x18, 0x18, 0x1f, 0x00, 0x00, 0x00 }
    char { 0x18, 0x18, 0x18, 0x18, 0xff, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0xff, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x18, 0x18, 0x1f, 0x18, 0x18, 0x18 }
    char { 0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00 }
    char { 0x18, 0x18, 0x18, 0x18, 0xff, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18 }
    char { 0x36, 0x36, 0x36, 0x36, 0x37, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0x37, 0x30, 0x3f, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x3f, 0x30, 0x37, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0xf7, 0x00, 0xff, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0xff, 0x00, 0xf7, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0x37, 0x30, 0x37, 0x36, 0x36, 0x36 }
    char { 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00 }
    char { 0x36, 0x36, 0xf7, 0x00, 0xf7, 0x36, 0x36, 0x36 }
    char { 0x18, 0x18, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00 }
    char { 0x36, 0x36, 0x36, 0x36, 0xff, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0xff, 0x00, 0xff, 0x18, 0x18, 0x18 }
    char { 0x00, 0x00, 0x00, 0x00, 0xff, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0x36, 0x36, 0x3f, 0x00, 0x00, 0x00 }
    char { 0x18, 0x18, 0x1f, 0x18, 0x1f, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x1f, 0x18, 0x1f, 0x18, 0x18, 0x18 }
    char { 0x00, 0x00, 0x00, 0x00, 0x3f, 0x36, 0x36, 0x36 }
    char { 0x36, 0x36, 0x36, 0x36, 0xff, 0x36, 0x36, 0x36 }
    char { 0x18, 0x18, 0xff, 0x18, 0xff, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x18, 0x18, 0xf8, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x1f, 0x18, 0x18, 0x18 }
    char { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff }
    char { 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff }
    char { 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0 }
    char { 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f, 0x0f }
    char { 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x66, 0xdc, 0xd8, 0xdc, 0x66, 0x00 }
    char { 0x00, 0x78, 0xcc, 0xf8, 0xcc, 0xc6, 0xcc, 0x00 }
    char { 0x00, 0xfe, 0x62, 0x60, 0x60, 0x60, 0xe0, 0x00 }
    char { 0x00, 0xfe, 0x6c, 0x6c, 0x6c, 0x6c, 0x6c, 0x00 }
    char { 0xfe, 0xc6, 0x60, 0x30, 0x60, 0xc6, 0xfe, 0x00 }
    char { 0x00, 0x7e, 0xd8, 0xcc, 0xcc, 0xd8, 0x70, 0x00 }
    char { 0x00, 0x66, 0x66, 0x66, 0x66, 0x7c, 0xc0, 0x00 }
    char { 0x00, 0x76, 0xdc, 0x18, 0x18, 0x18, 0x38, 0x00 }
    char { 0xfe, 0x38, 0x6c, 0xc6, 0x6c, 0x38, 0xfe, 0x00 }
    char { 0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0x6c, 0x38, 0x00 }
    char { 0x38, 0x6c, 0xc6, 0xc6, 0x6c, 0x6c, 0xee, 0x00 }
    char { 0x3e, 0x60, 0x38, 0x66, 0xc6, 0xcc, 0x78, 0x00 }
    char { 0x00, 0x00, 0x7e, 0xdb, 0xdb, 0x7e, 0x00, 0x00 }
    char { 0x06, 0x7c, 0xde, 0xf6, 0xe6, 0x7c, 0xc0, 0x00 }
    char { 0x38, 0x60, 0xc0, 0xf8, 0xc0, 0x60, 0x38, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x00 }
    char { 0x00, 0xfe, 0x00, 0xfe, 0x00, 0xfe, 0x00, 0x00 }
    char { 0x18, 0x18, 0x7e, 0x18, 0x18, 0x00, 0x7e, 0x00 }
    char { 0x30, 0x18, 0x0c, 0x18, 0x30, 0x00, 0x7e, 0x00 }
    char { 0x0c, 0x18, 0x30, 0x18, 0x0c, 0x00, 0x7e, 0x00 }
    char { 0x0c, 0x1e, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18 }
    char { 0x18, 0x18, 0x18, 0x18, 0x18, 0x78, 0x30, 0x00 }
    char { 0x00, 0x00, 0x18, 0x00, 0x7e, 0x00, 0x18, 0x00 }
    char { 0x00, 0x76, 0xdc, 0x00, 0x76, 0xdc, 0x00, 0x00 }
    char { 0x7c, 0xc6, 0xc6, 0x7c, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00 }
    char { 0x1f, 0x18, 0x18, 0x18, 0xf8, 0x38, 0x18, 0x00 }
    char { 0xd8, 0x6c, 0x6c, 0x6c, 0x00, 0x00, 0x00, 0x00 }
    char { 0x70, 0xd8, 0x30, 0xf8, 0x00, 0x00, 0x00, 0x00 }
    char { 0x00, 0x00, 0x7c, 0x7c, 0x7c, 0x7c, 0x00, 0x00 }
    char { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }

end
