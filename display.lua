Display = {}

function Display.new(double)
    local instance = setmetatable({}, { __index = Display })
    local err = nil

    instance.start_addr = 0x01ac00
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
    -- Two buffers of 80x60x2 text screens: 0x01ac00 and 0x01d180
    -- 2048 bytes of font ram: 0x01f700 (future)
    -- 16 bytes of foreground palette: 0x01ff00 (future)
    -- 16 bytes of background palette: 0x01ff10 (future)

    local end_addr = self.start_addr + 80*60*2*2 
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
    local dest = { w=8, h=8, x=x*8, y=y*8 }
    self.font:setColorMod(Display.to_rgb(fg))
    self.renderer:setDrawColor(Display.to_rgb(bg))
    self.renderer:fillRect(dest)
    self.renderer:copy(self.font, src, dest)
    self.renderer:present()
end

function Display:loop()
    if self.cpu.halted then
        SDL.waitEvent()
    end

    for event in SDL.pollEvent() do
        if event.type == SDL.event.Quit then
            self.active = false
            self.cpu:interrupt(0)
        elseif event.type == SDL.event.KeyDown or event.type == SDL.event.KeyUp then
            self.cpu:interrupt(event.keysym.sym, event.state, 1)
        end
    end
end

function Display:palette(num)
    local pico_palette = { 0x00, 0x05, 0x65, 0x11, 0xa8, 0x49, 0xeb, 0xff, 0xe1, 0xf4, 0xfc, 0x1c, 0x37, 0x8e, 0xee, 0xfa }
    return pico_palette[num]
end

function Display:refresh()
    self.active = true

    for y=0, 59 do
        for x=0, 79 do
            local char = self.cpu:peek(self.start_addr + x + 80 * y)
            local color = self.cpu:peek(self.start_addr + x + 80 * y + 4800)
            local fg_color = self:palette(1 + (color & 0x0f))
            local bg_color = self:palette(1 + (color >> 4))
            self:char(char, x, y, fg_color, bg_color)
        end
    end
end

function Display:refresh_address(addr, val)
    self.cpu.mem[self.start_addr + addr] = val
    local offset = addr % 4800
    local char = self.cpu:peek(self.start_addr + offset)
    local color = self.cpu:peek(self.start_addr + offset + 4800)
    local fg_color = self:palette(1 + (color & 0x0f))
    local bg_color = self:palette(1 + (color >> 4))
    self:char(char, offset % 80, math.floor(offset / 80), fg_color, bg_color)
end

return Display
