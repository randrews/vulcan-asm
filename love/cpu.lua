local opcodes = require('./opcodes')

CPU = {}

function CPU.new()
    local instance = setmetatable({}, { __index = CPU })

    instance.devices = {}

    instance.sp = 0
    instance.dp = 0

    instance.mem = {}
    for n = 0, (128 * 1024) - 1 do
        instance.mem[n] = math.floor(math.random() * 256)
    end

    instance.int_enabled = false
    instance.int_vector = 0

    return instance:reset()
end

function CPU:reset()
    self.dp = 256 -- Data stack pointer (0x00-0xff reserved, always points at low byte of top of stack)
    self.bottom_dp = 256 -- Exists only for debugging; set this in a setdp instruction
    self.sp = 1024 -- Return stack pointer (256 cells higher)
    self.pc = 1024 -- Program counter
    self.halted = false -- Flag to stop execution
    self.next_pc = nil -- Set after each fetch, opcodes can change it

    for _, device in ipairs(self.devices) do
        if device.reset then device.reset() end
    end

    return self
end

function CPU:flags()
    return self.halted, self.int_enabled
end

-- The 'dp' register always points one above the high byte of the
-- top of the stack, so mem[dp-3] is the least significant byte
function CPU:push_data(word)
    word = bit.band(math.floor(word), 0xffffff)
    self:poke24(self.dp, word)
    self.dp = self.dp + 3
end

-- The 'sp' register always points to the low byte of the
-- top of the stack, so mem[sp] is the least significant byte
function CPU:push_call(val)
    self.sp = self.sp - 3
    self:poke24(self.sp, bit.band(math.floor(val), 0xffffff))
end

function CPU:pop_data()
    self.dp = self.dp - 3
    return self:peek24(self.dp)
end

function CPU:pop_call()
    local val = self:peek24(self.sp)
    self.sp = self.sp + 3
    return val
end

function CPU:peek_call()
    local val = self:peek24(self.sp)
    return val
end

-- Devices support different callbacks:
-- - peek is called with an offset, if a byte within the address range is read
-- - poke is called with an offset and a new (byte) value, if a byte is written
-- - tick is called every time the CPU runs an instruction
-- - reset is called when the CPU resets
function CPU:install_device(start_addr, end_addr, callbacks)
    table.insert(self.devices, {
                     address = {start_addr, end_addr},
                     peek = callbacks.peek,
                     poke = callbacks.poke,
                     tick = callbacks.tick,
                     reset = callbacks.reset
    })
end

function CPU:poke(addr, value)
    addr = bit.band(math.abs(math.floor(addr)), 0x01ffff)
    value = bit.band(math.floor(value), 0xff)
    for _, device in ipairs(self.devices) do
        if device.poke and addr >= device.address[1] and addr <= device.address[2] then
            device.poke(addr - device.address[1], value)
            return
        end
    end
    self.mem[addr] = value
end

function CPU:poke24(addr, value)
    self:poke(addr, bit.band(value, 0xff))
    self:poke(addr + 1, bit.band(bit.rshift(value, 8), 0xff))
    self:poke(addr + 2, bit.band(bit.rshift(value, 16), 0xff))
end

function CPU:peek(addr)
    addr = bit.band(math.abs(math.floor(addr)), 0x01ffff)
    for _, device in ipairs(self.devices) do
        if device.peek and addr >= device.address[1] and addr <= device.address[2] then
            return device.peek(addr - device.address[1])
        end
    end
    return self.mem[addr]
end

function CPU:peek24(addr)
    local val = self:peek(addr)
    val = bit.bor(val, bit.lshift(self:peek(addr + 1), 8))
    val = bit.bor(val, bit.lshift(self:peek(addr + 2), 16))
    return val
end

function CPU:print_stack()
    if self.dp == self.bottom_dp then print('<stack empty>')
    else
        for i = self.bottom_dp, self.dp, 3 do
            print(string.format('0x%x:\t0x%x', i, self:peek24(i)))
        end
    end
end

function CPU:decode(opcode)
    local name = opcodes.mnemonic_for(opcode)
    if not name then error('Unrecognized opcode ' .. opcode) end
    if (name == 'and' or name == 'or' or name == 'not' or name == 'call'
        or name == 'load' or name == 'sp' or name == 'dp') then
        return '_' .. name
    end
    return name
end

function CPU:fetch()
    local instruction = self:peek(self.pc)
    local arg_length = bit.band(instruction, 3)
    local mnemonic = self:decode(bit.rshift(instruction, 2))

    if arg_length > 0 then
        local arg = 0
        for n=1, arg_length do
            local b = self:peek(self.pc + n)
            b = bit.lshift(b, (8 * (n - 1)))
            arg = arg + b
        end

        self:push_data(arg)
    end

    if mnemonic ~= 'hlt' then
        self.next_pc = self.pc + arg_length + 1
    end

    return mnemonic
end

function CPU:execute(mnemonic)
    (self[mnemonic])(self)
    self.pc = self.next_pc
end

-- Run instructions and tick devices until `hlt`
function CPU:run()
    while not self.halted do
        self:execute(self:fetch())
        self:tick_devices()
    end
end

function CPU:tick_devices()
    for _,device in ipairs(self.devices) do
        if device.tick then device.tick() end
    end
end

function CPU:interrupt(...)
    if self.int_enabled then
        self.int_enabled = false
        self.halted = false
        self:push_call(self.pc)
        for _, val in ipairs{...} do self:push_data(val) end
        self.pc = self.int_vector
    end
end

----------------------------------------------------------------------------------------------------

-- Basic instructions
-- Pushing is handled by the execute function
function CPU:push() end

function CPU:hlt()
    self.halted = true
end

function CPU:pop()
    self:pop_data()
end

-- Stack manipulation
function CPU:dup()
    self:push_data(self:peek24(self.dp - 3))
end

function CPU:swap()
    local a = self:pop_data()
    local b = self:pop_data()
    self:push_data(a)
    self:push_data(b)
end

function CPU:rot()
    local c = self:pop_data()
    local b = self:pop_data()
    local a = self:pop_data()
    self:push_data(b)
    self:push_data(c)
    self:push_data(a)
end

function CPU:pick()
    local index = self:pop_data()
    self:push_data(self:peek24(self.dp - (index + 1) * 3))
end

-- Math functions
function CPU:add()
    self:push_data(self:pop_data() + self:pop_data())
end

function CPU:mul()
    self:push_data(self:pop_data() * self:pop_data())
end

function CPU:sub()
    local a = self:pop_data()
    self:push_data(self:pop_data() - a)
end

function CPU:div()
    local a = self:pop_data()
    self:push_data(math.floor(self:pop_data() / a))
end

function CPU:mod()
    local a = self:pop_data()
    self:push_data(self:pop_data() % a)
end

-- Logic functions
function CPU:_and()
    self:push_data(bit.band(self:pop_data(), self:pop_data()))
end

function CPU:_or()
    self:push_data(bit.bor(self:pop_data(), self:pop_data()))
end

function CPU:xor()
    self:push_data(bit.bnot(self:pop_data(), self:pop_data()))
end

function CPU:_not()
    local val = self:pop_data()
    if val == 0 then
        self:push_data(1)
    else
        self:push_data(0)
    end
end

function CPU:lshift()
    local places = self:pop_data()
    self:push_data(bit.lshift(self:pop_data(), places))
end

function CPU:rshift()
    local places = self:pop_data()
    self:push_data(bit.rshift(self:pop_data(), places))
end

function CPU:arshift()
    local places = self:pop_data()
    local val = self:pop_data()
    if bit.band(val, 0x800000) > 0 then
        for n=1, places do
            val = bit.bor(bit.rshift(val, 1), 0x800000)
        end
        self:push_data(val)
    else
        self:push_data(bit.rshift(val, places))
    end
end

-- Branching and jumping
function CPU:jmp()
    self.next_pc = self:pop_data()
end

function CPU:jmpr()
    self.next_pc = self.pc + self:pop_data()
end

function CPU:_call()
    self:push_call(self.next_pc)
    self.next_pc = self:pop_data()
end

function CPU:ret()
    self.next_pc = self:pop_call()
end

function CPU:brz()
    local offset = self:pop_data()
    if self:pop_data() == 0 then
        self.next_pc = self.pc + offset
    end
end

function CPU:brnz()
    local offset = self:pop_data()
    if self:pop_data() ~= 0 then
        self.next_pc = self.pc + offset
    end
end

function CPU:gt()
    local b = self:pop_data()
    local a = self:pop_data()
    if a > b then self:push_data(1)
    else self:push_data(0) end
end

function CPU:lt()
    local b = self:pop_data()
    local a = self:pop_data()
    if a < b then self:push_data(1)
    else self:push_data(0) end
end

function CPU:agt()
    local b = to_signed(self:pop_data())
    local a = to_signed(self:pop_data())
    if a > b then self:push_data(1)
    else self:push_data(0) end
end

function CPU:alt()
    local b = to_signed(self:pop_data())
    local a = to_signed(self:pop_data())
    if a < b then self:push_data(1)
    else self:push_data(0) end
end

-- Memory access
function CPU:_load()
    self:push_data(self:peek(self:pop_data()))
end

function CPU:loadw()
    local addr = self:pop_data()
    self:push_data(self:peek24(addr))
end

function CPU:storew()
    local addr = self:pop_data()
    local val = self:pop_data()
    self:poke24(addr, val)
end

function CPU:store()
    local addr = self:pop_data()
    self:poke(addr, bit.band(self:pop_data(), 0xff))
end

-- Interrupts
function CPU:inton()
    self.int_enabled = true
end

function CPU:intoff()
    self.int_enabled = false
end

function CPU:setiv()
    self.int_vector = self:pop_data()
end

-- Call stack
function CPU:sdp()
    self:push_data(self.sp)
    self:push_data(self.dp + 3)
end

function CPU:setsdp()
    local b = self:pop_data()
    local a = self:pop_data()
    self.dp = b
    self.sp = a
end

function CPU:pushr()
    self:push_call(self:pop_data())
end

function CPU:popr()
    self:push_data(self:pop_call())
end

function CPU:peekr()
    self:push_data(self:peek_call())
end

-- Convert a 24-bit unsigned value to a signed Lua number
function to_signed(word)
    word = bit.band(word, 0xffffff)
    if bit.band(word, 0x800000) then
        word = bit.bnot(word, 0xffffff) + 1
        return -1 * word
    else
        return word
    end
end

return CPU
