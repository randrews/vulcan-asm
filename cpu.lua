local VASM = require('vasm')

CPU = {}

function CPU.new(display)
    local instance = setmetatable({}, { __index = CPU })

    instance.stack = {}
    for n = 0, (2048 - 1) do
        instance.stack[n] = 0
    end

    instance.mem = {}
    for n = 0, 131071 do
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
    self.call = 0 -- Stack index of top of call stack
    self.data = 2048 - 1 -- Stack index of top of data stack
    self.halted = false -- Flag to stop execution
    self.next_pc = nil -- Set after each fetch, opcodes can change it

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

function CPU:print_stack()
    for i = 0, self.data do
        print(string.format('%d:\t0x%x', self.data-i, self.stack[i]))
    end
end

function CPU:decode(opcode)
    if opcode == 0 then return 'push'
    elseif opcode == 1 then return 'add'
    elseif opcode == 2 then return 'sub'
    elseif opcode == 3 then return 'mul'
    elseif opcode == 4 then return 'div'
    elseif opcode == 5 then return 'mod'
    elseif opcode == 6 then return 'rand'
    elseif opcode == 7 then return '_and' -- Renamed from and
    elseif opcode == 8 then return '_or' -- renamed from or
    elseif opcode == 9 then return 'xor'
    elseif opcode == 10 then return '_not' -- Renamed from not
    elseif opcode == 11 then return 'lshift'
    elseif opcode == 12 then return 'rshift'
    elseif opcode == 13 then return 'arshift'
    elseif opcode == 14 then return 'pop'
    elseif opcode == 15 then return 'dup'
    elseif opcode == 16 then return '_2dup' -- Renamed from 2dup
    elseif opcode == 17 then return 'swap'
    elseif opcode == 18 then return 'pick'
    elseif opcode == 19 then return 'height'
    elseif opcode == 20 then return 'jmp'
    elseif opcode == 21 then return 'jmpr'
    elseif opcode == 22 then return '_call' -- Renamed from call
    elseif opcode == 23 then return 'ret'
    elseif opcode == 24 then return 'brz'
    elseif opcode == 25 then return 'brnz'
    elseif opcode == 26 then return 'brgt'
    elseif opcode == 27 then return 'brlt'
    elseif opcode == 28 then return 'hlt'
    elseif opcode == 29 then return '_load' -- Renamed from load
    elseif opcode == 30 then return 'load16'
    elseif opcode == 31 then return 'load24'
    elseif opcode == 32 then return 'store'
    elseif opcode == 33 then return 'store16'
    elseif opcode == 34 then return 'store24'
    elseif opcode == 35 then return 'inton'
    elseif opcode == 36 then return 'intoff'
    elseif opcode == 37 then return 'setiv'
    else error('Unrecognized opcode ' .. opcode) end
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
    self:push_data(~self:pop_data())
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

function CPU:brnz()
    local offset = self:pop_data()
    if self:pop_data() ~= 0 then
        self.next_pc = self.pc + offset
    end
end

function CPU:brgt()
    local offset = self:pop_data()
    if self:pop_data() & 0x800000 == 0 then
        self.next_pc = self.pc + offset
    end
end

function CPU:brlt()
    local offset = self:pop_data()
    if self:pop_data() & 0x800000 ~= 0 then
        self.next_pc = self.pc + offset
    end
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
    self.display:refresh_address(addr)
    self.display:refresh_address(addr+1)
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

return CPU
