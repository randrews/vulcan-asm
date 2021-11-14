require './font'

local reg = {
    mode = 6, -- Bottom three bits are mode: 0x1 is low text / high gfx, 0x2 is low low-res / high high-res, 0x4 is low direct high paletted
    screen = 0x0000, -- byte address, start of screen
    palette = 0x10000 - 0x100, -- Palette is last page
    font = 0x10000 - 0x100 - 0x2000, -- Font address is 2k behind palette
    height = 60, -- Number of total rows
    width = 80, -- number of bytes per row (only 128 displayed ever, this includes scrolling margin)
    row_offset = 0, -- Offset in rows between screen start and start of display.
    col_offset = 0, -- Offset in pixels / bytes between start of row and start of display. stride=192, col_offset=32 gives a 128-wide display with 32 margin on either side to scroll to
    dirty = true -- This is not a real register, this is just whether we need to redraw the font buffer or not
}

local mem = {}

for i = 0, 0xffff do
    mem[i] = math.random(256) - 1
end

mem[reg.palette] = 0x0

-- for i = 0, 255 do
--     mem[reg.palette + i] = bit.lshift(math.floor(i / 64), 0)
-- end

-- for i = 0, 255 do
--     local x, y = (112 + i % 16), (112 + math.floor(i / 16))
--     mem[reg.screen + x + y * reg.width] = 0
-- end

for i = 0, 50 do
    local x, y = 5 + i, 25
    mem[reg.screen + x + (y - 1) * reg.width] = 0
    mem[reg.screen + x + y * reg.width] = 65
end

-- mem[reg.palette + 1] = 0xff
-- for i = 0, 160 do
--     mem[reg.screen + reg.width * (reg.height - 1) + i] = 1
-- end

local low_gfx_buf = love.graphics.newCanvas(128, 128)
local high_gfx_buf = love.graphics.newCanvas(160, 120)
local low_text_buf = love.graphics.newCanvas(320, 240)
local high_text_buf = love.graphics.newCanvas(640, 480)
local font_buf = love.graphics.newCanvas(128, 128)

low_gfx_buf:setFilter('nearest')
high_gfx_buf:setFilter('nearest')
low_text_buf:setFilter('nearest')
high_text_buf:setFilter('nearest')
font_buf:setFilter('nearest')

load_font(mem, reg.font)

love.math.setRandomSeed(love.timer.getTime())
love.window.setMode(640, 480, { resizable = true })

local fps = 0
local timer = 0

function to_rgb(byte)
    local red = bit.rshift(byte, 5)
    local green = bit.band(bit.rshift(byte, 2), 7)
    local blue = bit.lshift(bit.band(byte, 3), 1)
    if bit.band(blue, 0x02) > 0 then blue = blue + 1 end
    return { red / 8, green / 8, blue / 8 }
end

function love.draw()
    if reg.dirty then
        redraw_font_buf()
        reg.dirty = false
    end

    local buf
    if bit.band(reg.mode, 1) == 0 then -- Text mode
        buf = draw_text_mode()
    else -- Graphics mode
        buf = draw_graphics_mode()
    end

    love.graphics.push()
    love.graphics.setCanvas(nil)
    love.graphics.setColor(1, 1, 1)

    local win_w, win_h = love.window.getMode()
    local buf_w, buf_h = buf:getDimensions()
    local factor = math.min(math.floor(win_w / buf_w), math.floor(win_h / buf_h))
    local t, l = (win_w - buf_w * factor) / 2, (win_h - buf_h * factor) / 2
    love.graphics.draw(buf, t, l, 0, factor, factor)

    love.graphics.pop()
    love.graphics.print(fps, 10, 10)
end

function redraw_font_buf()
    for ch = 0, 0xff do
        redraw_font_ch(ch)
    end
end

function redraw_font_ch(ch)
    love.graphics.setCanvas(font_buf)
    love.graphics.setColor(0, 0, 0, 0)
    love.graphics.setBlendMode('replace') -- This, like canvases, is not part of graphics state, so we have to manually reset it.
    love.graphics.rectangle('fill', (ch % 16) * 8 + 0.5, math.floor(ch / 16) * 8 + 0.5, 8, 8) -- Clear the char back to transparent
    love.graphics.setBlendMode('alpha')

    for y = 0, 7 do
        local row = mem[reg.font + ch * 8 + y]
        for x = 0, 7 do
            if bit.band(row, 0x80) ~= 0 then love.graphics.setColor(1, 1, 1, 1)
            else love.graphics.setColor(0, 0, 0, 0) end
            love.graphics.points((ch % 16) * 8 + x + 0.5, math.floor(ch / 16) * 8 + y + 0.5)
            row = bit.band(bit.lshift(row, 1), 0xff)
        end
    end
    love.graphics.setCanvas(nil)
end

function select_buf()
    if bit.band(reg.mode, 1) == 0 then -- Text
        if bit.band(reg.mode, 2) == 0 then -- Low res
            return low_text_buf, 320, 240
        else -- High res
            return high_text_buf, 640, 480
        end
    else -- Graphics
        if bit.band(reg.mode, 2) == 0 then -- Low res
            return low_gfx_buf, 128, 128
        else -- High res
            return high_gfx_buf, 160, 120
        end
    end
end

function draw_text_mode()
    local buf, w, h = select_buf()
    local cw, ch = math.floor(w / 8), math.floor(h / 8)

    love.graphics.push()
    love.graphics.setCanvas(buf)
    for i = 0, cw * ch - 1 do -- For each character
        local x = i % cw -- x screen-char coord
        local y = math.floor(i / cw) -- y screen-char coord
        local row_start = reg.screen + ((y + reg.row_offset) % reg.height) * reg.width -- Row start address, for chars
        local a = row_start + (x + reg.col_offset) % reg.width -- Address of char
        local color_a = a + (reg.width * reg.height) -- Address of color byte

        local char_byte = mem[a % 0x10000]

        local color_byte = mem[color_a % 0x10000]

        local fg, bg
        if bit.band(reg.mode, 4) ~= 0 then -- Palette lookup if required
            fg, bg = to_rgb(mem[reg.palette + bit.band(color_byte, 0xf)]), to_rgb(mem[reg.palette + bit.rshift(color_byte, 4)])
        else
            fg, bg = to_rgb(color_byte), to_rgb(0)
        end

        draw_char(char_byte, x * 8, y * 8, fg, bg)
    end
    love.graphics.pop()
    return buf
end

function draw_char(char, px, py, fg, bg)
    local quad = love.graphics.newQuad((char % 16) * 8, math.floor(char / 16) * 8, 8, 8, font_buf)
    
    love.graphics.setColor(unpack(bg))
    love.graphics.rectangle('fill', px + 0.5, py + 0.5, 8, 8)
    love.graphics.setColor(unpack(fg))
    love.graphics.draw(font_buf, quad, px + 0.5, py + 0.5)
end

function draw_graphics_mode()
    local buf, w, h = select_buf()

    love.graphics.push()
    love.graphics.setCanvas(buf)
    for i = 0, w * h - 1 do
        local x = i % w -- x pixel coord
        local y = math.floor(i / w) -- y pixel coord
        local row_start = reg.screen + ((y + reg.row_offset) % reg.height) * reg.width -- Row start address
        local a = row_start + (x + reg.col_offset) % reg.width -- Address of pixel

        local byte = mem[a % 0x10000]

        if bit.band(reg.mode,4) ~= 0 then -- Palette lookup if required
            byte = mem[reg.palette + byte]
        end

        love.graphics.setColor(unpack(to_rgb(byte)))
        love.graphics.points(x + 0.5, y + 0.5)
    end

    love.graphics.pop()
    return buf
end

function love.update(dt)
    fps = math.floor(1.0 / dt)
    timer = timer + dt
    if timer > 0.1 then
        timer = 0
        local b = mem[reg.font + 65 * 8]
        if b == 0 then b = 1
        else b = (b * 2) % 256 end
        mem[reg.font + 65 * 8] = b
        redraw_font_ch(65)
        --reg.col_offset = reg.col_offset + 1
        --reg.row_offset = reg.row_offset + 1
    end
end

function love.keypressed(key, scan, isrepeat)
    love.event.quit()
end

local thread = love.thread.newThread('cpu_thread.lua')
thread:start()
