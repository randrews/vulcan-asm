dofile('vemu.lua')

-- Fake an iterator from a string
function iterator(str)
    return function()
        if str == '' then return nil end
        local endl = str:find('\n')
        if not endl then endl = #str+1 end
        local current_line = str:sub(1, endl-1)
        str = str:sub(endl + 1)
        return current_line
    end
end

local cpu = CPU.new()
assert(cpu.stack[0] == 0)
assert(cpu.stack[2047] == 0)
assert(cpu.stack[2048] == nil)
assert(cpu.mem[0] ~= nil)
assert(cpu.mem[131071] ~= nil)
assert(cpu.mem[131072] == nil)
assert(cpu.call == 0)
assert(cpu.data == 2047)

local cpu = CPU.new()
cpu:push_data(37)
cpu:push_data(45)
assert(cpu.stack[0] == 37)
assert(cpu.stack[1] == 45)
assert(cpu.call == 0)
assert(cpu.data == 1)

local cpu = CPU.new()
cpu:push_call(37)
cpu:push_call(45)
assert(cpu.stack[2047] == 37)
assert(cpu.stack[2046] == 45)
assert(cpu.call == 2046)
assert(cpu.data == 2047)

local cpu = CPU.new()
cpu:push_data(47)
cpu:push_data(32)
assert(cpu:pop_data() == 32)
assert(cpu:pop_data() == 47)
assert(cpu.data == 2047)

local cpu = CPU.new()
cpu:poke(37, 45)
assert(cpu.mem[37] == 45)
assert(cpu:peek(37) == 45)

local cpu = CPU.new()
cpu:poke(0xffffff, 47)
assert(cpu.mem[0x01ffff] == 47)
assert(cpu:peek(0xffffff) == 47)
assert(cpu:peek(0x01ffff) == 47)

local cpu = CPU.new()
cpu.pc = 1000
cpu.halted = true
cpu:reset()
assert(cpu.pc == 256)
assert(not cpu.halted)

local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 2
    add 2
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 4)

local cpu = CPU.new()
assert(cpu:decode(17) == 'swap')

local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 2
]]))
assert(cpu:fetch() == 'push')
assert(cpu.next_pc == 258)
assert(cpu:pop_data() == 2)

local cpu = CPU.new()
cpu.next_pc = 10
cpu:push_data(35)
cpu:_call()
assert(cpu:pop_call() == 10)
assert(cpu.next_pc == 35)
