SDL = require('SDL')

Display = {}
function Display.new()
    local instance = setmetatable({}, { __index = Display })

    if not Display.initialized then
        local ret, err = SDL.init(SDL.flags.Video)
        if not ret then error(err) end
        Display.initialized = true
    end

    instance.window = SDL.createWindow{title='Vulcan', width=640, height=480}
    return instance
end

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
