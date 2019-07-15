SDL = require('SDL')
SDL.image = require('SDL.image')

Display = {}
function Display.new(double)
    local instance = setmetatable({}, { __index = Display })
    local err = nil
    
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

function Display.to_rgb(byte)
    local red = (byte >> 5)
    local green = (byte >> 2) & 7
    local blue = (byte & 3) << 1
    if blue & 0x02 then blue = blue + 1 end
    print(string.format('r: %x, g: %x, b: %x', red, green, blue))
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
    for event in SDL.pollEvent() do
        print(event.type)
    end
end

d = Display.new(true); d:char(65+36, 10, 10, 0xff, 0xe0); while true do d:loop() end
----------------------------------------------------------------------------------------------------

CPU = {}
function CPU.new()
    local instance = setmetatable({}, { __index = CPU })

    instance.stack = {}
    for n = 0, (2048 - 1) do
        instance.stack[n] = 0
    end

    instance.mem = {}
    for n = 0, 131071 do
        instance.mem[n] = 0
    end

    instance.call = 0
    instance.data = 2048 - 1
    return instance
end

function CPU:push_data(word)
    word = math.floor(word) & 0xffffff
    self.data = (self.data + 1) % 2048
    self.stack[self.data] = word
end

function CPU:push_call(addr)
    addr = math.floor(addr) & 0xffffff
    self.call = (self.call - 1 + 2048) % 2048
    self.stack[self.call] = addr
end

function CPU:pop_data()
    local word = self.stack[self.data]
    self.data = (self.data - 1 + 2048) % 2048
    return word
end

function CPU:pop_call()
    local word = self.stack[self.call]
    self.call = (self.call + 1) % 2048
    return word
end

function CPU:poke(addr, value)
    addr = math.abs(math.floor(addr)) & 0x01ffff
    value = math.floor(value) & 0xff
    self.mem[addr] = value
end

function CPU:peek(addr)
    addr = math.abs(math.floor(addr)) & 0x01ffff
    return self.mem[addr]
end
