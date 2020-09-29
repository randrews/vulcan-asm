Display = {}

function Display.new(double)
    local instance = setmetatable({}, { __index = Display })
    local err = nil

    instance.start_addr = 0x01a000
    instance.active = true

    if not Display.initialized then
        local ret, err = SDL.init(SDL.flags.Video)
        if not ret then error(err) end

        Display.image, err = SDL.image.load('font.png')
        if not Display.image then error(err) end

        Display.initialized = true
    end

    local props = { title = 'Vulcan', width = 640, height = 480 }
    if double then
        props.width = props.width * 2
        props.height = props.height * 2
    end

    instance.mem = {}
    for n = 0, (40*30*2) - 1 do
        instance.mem[n] = math.floor(math.random() * 256)
    end

    instance.window = SDL.createWindow(props)

    instance.renderer, err = SDL.createRenderer(instance.window, -1)
    if not instance.renderer then error(err) end

    instance.font, err = instance.renderer:createTextureFromSurface(Display.image)
    if not instance.font then error(err) end

    if double then
        instance.renderer:setLogicalSize(640, 480)
    end

    return instance
end

function Display:install(cpu)
    -- Two buffers of 40x30x2 text screens
    -- 2048 bytes of font ram (future)
    -- 16 bytes of foreground palette (future)
    -- 16 bytes of background palette (future)

    local end_addr = self.start_addr + 40*30*2
    cpu:install_device(self.start_addr, end_addr,
                       { poke = function(addr, val) self:refresh_address(addr, val) end,
                         tick = function() self:loop() end,
                         reset = function() self:refresh() end })
    self.cpu = cpu
end

function Display.to_rgb(byte)
    local red = (byte >> 5)
    local green = (byte >> 2) & 7
    local blue = (byte & 3) << 1
    if blue & 0x02 then blue = blue + 1 end
    return (red << 21) + (green << 13) + (blue << 5)
end

function Display:char(c, x, y, fg, bg)
    local src = { w=8, h=8, x=(c%64)*8, y=math.floor(c/64)*8 }
    local dest = { w=16, h=16, x=x*16, y=y*16 }
    self.font:setColorMod(Display.to_rgb(fg))
    self.renderer:setDrawColor(Display.to_rgb(bg))
    self.renderer:fillRect(dest)
    self.renderer:copy(self.font, src, dest)
    self.renderer:present()
end

function Display:loop()
    local halted, int_enabled = self.cpu:flags()
    if halted then
        local event = SDL.waitEvent()
        self:handle_event(event)
    elseif int_enabled then
        local event = SDL.waitEvent(0)
        if event then self:handle_event(event) end
    end
end

function Display:handle_event(event)
    if event.type == SDL.event.Quit then
        self.active = false
    elseif event.type == SDL.event.KeyDown or event.type == SDL.event.KeyUp then
        local key = self:to_key(event.keysym.scancode)
        if key then
            self.cpu:interrupt(key, event.state, 2)
        end
    end
end

-- Convert an SDL keyboard scancode to a Vulcan-keyboard scancode
function Display:to_key(scancode)
    if scancode >= SDL.scancode.A and scancode <= SDL.scancode.Z then
        return scancode + 93
    elseif scancode >= SDL.scancode['1'] and scancode <= SDL.scancode['9'] then
        return scancode + 49 - SDL.scancode['1']
    elseif scancode == SDL.scancode['0'] then
        return 48
    elseif scancode == SDL.scancode.Space then
        return 0
    elseif scancode == SDL.scancode.Return then
        return 0xff
    elseif scancode == SDL.scancode.RightShift then
        return 0x0200
    elseif scancode == SDL.scancode.LeftShift then
        return 0x0100
    else
        return nil
    end
end

function Display:palette(num)
    local pico_palette = { 0x00, 0x05, 0x65, 0x11, 0xa8, 0x49, 0xeb, 0xff, 0xe1, 0xf4, 0xfc, 0x1c, 0x37, 0x8e, 0xee, 0xfa }
    return pico_palette[num]
end

function Display:refresh()
    self.active = true

    for y=0, 29 do
        for x=0, 39 do
            local char = self.mem[x + 40 * y]
            local color = self.mem[x + 40 * y + 1200]
            local fg_color = self:palette(1 + (color & 0x0f))
            local bg_color = self:palette(1 + (color >> 4))
            self:char(char, x, y, fg_color, bg_color)
        end
    end
end

function Display:refresh_address(addr, val)
    self.mem[addr] = val
    local offset = addr % 1200
    local char = self.mem[offset]
    local color = self.mem[offset + 1200]
    local fg_color = self:palette(1 + (color & 0x0f))
    local bg_color = self:palette(1 + (color >> 4))
    self:char(char, offset % 40, math.floor(offset / 40), fg_color, bg_color)
end

return Display
