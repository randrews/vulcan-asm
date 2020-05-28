local VASM = require('vasm')
local opcodes = require('opcodes')

CPU = {}

function CPU.new(display)
    local instance = setmetatable({}, { __index = CPU })

    instance.stack = {}
    for n = 0, 2048 - 1 do
        instance.stack[n] = 0
    end

    instance.mem = {}
    for n = 0, (128 * 1024) - 1 do
        instance.mem[n] = math.floor(math.random() * 256)
    end

    instance.int_enabled = false
    instance.int_vector = 0

    if display then
        instance.display = display
        display.cpu = instance
        instance.display:refresh()
    end

    return instance:reset()
end

function CPU:reset()
    self.pc = 256 -- Program counter
    self.call = 2048 - 1 -- Stack index of first frame of of call stack
    self.data = 2048 - 1 -- Stack index of top of data stack
    self.halted = false -- Flag to stop execution
    self.next_pc = nil -- Set after each fetch, opcodes can change it
    self.stack[2048 - 1] = 2048 - 1 -- First stack frame points at itself

    return self
end

function CPU:load(iterator)
    local bytes, start = VASM.assemble(iterator)

    for offset, byte in pairs(bytes) do
        self:poke(start + offset, byte)
    end
end

function CPU:push_data(word)
    word = math.floor(word) & 0xffffff
    self.data = (self.data + 1) % 2048
    self.stack[self.data] = word
end

-- A stack frame consists of:
--
-- - The address of the previous stack frame
-- - The return address
-- - The number of locals in this stack frame
-- - A sequence of local variables (optional)
--
-- The 'call' variable always points to the address of the
-- previous frame, so stack[call] is the old frame,
-- stack[call - 1] is the return, etc etc.
function CPU:push_call(addr)
    local oldcall = self.call
    local size = self.stack[self.call - 2] + 3 -- Size of this stack frame
    self.call = self.call - size

    -- Initialize new frame
    self.stack[self.call] = oldcall -- Pointer to previous frame
    self.stack[self.call - 1] = math.floor(addr) & 0xffffff -- Return address
    self.stack[self.call - 2] = 0 -- No locals (yet)
end

function CPU:pop_data()
    local word = self.stack[self.data]
    self.data = (self.data - 1 + 2048) % 2048
    return word
end

-- Pops a frame off the stock and returns the return address
-- from that frame
function CPU:pop_call()
    local prev = self.stack[self.call]
    local ret = self.stack[self.call - 1]
    self.call = prev
    return ret
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

function CPU:print_stack()
    for i = 0, self.data do
        print(string.format('%d:\t0x%x', self.data-i, self.stack[i]))
    end
end

function CPU:decode(opcode)
    local name = opcodes.mnemonic_for(opcode)
    if not name then error('Unrecognized opcode ' .. opcode) end
    if (name == 'and' or name == 'or' or name == 'not' or name == '2dup'
        or name == 'call' or name == 'load' or name == 'local') then
        return '_' .. name
    end
    return name
end

function CPU:fetch()
    local instruction = self:peek(self.pc)
    local arg_length = instruction & 3
    local mnemonic = self:decode(instruction >> 2)

    if arg_length > 0 then
        local arg = 0
        for n=1, arg_length do
            local b = self:peek(self.pc + n)
            b = b << (8 * (n - 1))
            arg = arg + b
        end

        self:push_data(arg)
    end

    self.next_pc = self.pc + arg_length + 1

    return mnemonic
end

function CPU:execute(mnemonic)
    (self[mnemonic])(self)
    self.pc = self.next_pc
end

function CPU:run()
    while not self.halted do
        self:execute(self:fetch())

        if self.display then
            self.display:loop()
        end
    end
end

function CPU:interrupt(...)
    if self.int_enabled then
        self.int_enabled = false
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
    self:push_data(self.stack[self.data])
end

function CPU:_2dup()
    self:push_data(self.stack[self.data-1])
    self:push_data(self.stack[self.data-1])
end

function CPU:swap()
    self.stack[self.data], self.stack[self.data-1] = self.stack[self.data-1], self.stack[self.data]
end

function CPU:pick()
    local index = self:pop_data()
    self:push_data(self.stack[self.data - index])
end

function CPU:height()
    self:push_data(self.data+1)
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
    self:push_data(self:pop_data() & self:pop_data())
end

function CPU:_or()
    self:push_data(self:pop_data() | self:pop_data())
end

function CPU:xor()
    self:push_data(self:pop_data() ~ self:pop_data())
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
    self:push_data(self:pop_data() << places)
end

function CPU:rshift()
    local places = self:pop_data()
    self:push_data(self:pop_data() >> places)
end

function CPU:arshift()
    local places = self:pop_data()
    local val = self:pop_data()
    if val & 0x800000 > 0 then
        for n=1, places do
            val = (val >> 1) | 0x800000
        end
        self:push_data(val)
    else
        self:push_data(val >> places)
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
    self:push_data(self.mem[self:pop_data()])
end

function CPU:load16()
    local addr = self:pop_data()
    self:push_data(self.mem[addr+1] << 8 | self.mem[addr])
end

function CPU:load24()
    local addr = self:pop_data()
    self:push_data(self.mem[addr+2] << 16 | self.mem[addr+1] << 8 | self.mem[addr])
end

function CPU:store24()
    local addr = self:pop_data()
    local val = self:pop_data()
    self.mem[addr] = val & 0xff
    self.mem[addr+1] = (val >> 8) & 0xff
    self.mem[addr+2] = (val >> 16) & 0xff
    self.display:refresh_address(addr)
    self.display:refresh_address(addr+1)
    self.display:refresh_address(addr+2)
end

function CPU:store16()
    local addr = self:pop_data()
    local val = self:pop_data()
    self.mem[addr] = val & 0xff
    self.mem[addr+1] = (val >> 8) & 0xff
    if self.display then
        self.display:refresh_address(addr)
        self.display:refresh_address(addr+1)
    end
end

function CPU:store()
    local addr = self:pop_data()
    self.mem[addr] = self:pop_data() & 0xff
    self.display:refresh_address(addr)
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
function CPU:frame()
    self.stack[self.call - 2] = self:pop_data()
end

function CPU:setlocal()
    local id = self:pop_data()
    local val = self:pop_data()
    if self.stack[self.call - 2] > id then -- If we have this many locals
        self.stack[self.call - 3 - id] = val
    end
end

function CPU:_local()
    local id = self:pop_data()
    if self.stack[self.call - 2] > id then -- If we have this many locals
        self:push_data(self.stack[self.call - 3 - id])
    else -- Default to pushing 0
        self:push_data(0)
    end
end

-- Convert a 24-bit unsigned value to a signed Lua number
function to_signed(word)
    word = word & 0xffffff
    if word & 0x800000 then
        word = word ~ 0xffffff + 1
        return -1 * word
    else
        return word
    end
end

return CPU
