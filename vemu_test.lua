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

-- Initial state
local cpu = CPU.new()
assert(cpu.stack[0] == 0)
assert(cpu.stack[2047] == 0)
assert(cpu.stack[2048] == nil)
assert(cpu.mem[0] ~= nil)
assert(cpu.mem[131071] ~= nil)
assert(cpu.mem[131072] == nil)
assert(cpu.call == 0)
assert(cpu.data == 2047)

-- State after pushing data
local cpu = CPU.new()
cpu:push_data(37)
cpu:push_data(45)
assert(cpu.stack[0] == 37)
assert(cpu.stack[1] == 45)
assert(cpu.call == 0)
assert(cpu.data == 1)

-- State after pushing return addresses
local cpu = CPU.new()
cpu:push_call(37)
cpu:push_call(45)
assert(cpu.stack[2047] == 0) -- First frame prev
assert(cpu.stack[2046] == 37) -- First frame ret
assert(cpu.stack[2045] == 0) -- First frame locals

assert(cpu.stack[2044] == 2047) -- Second frame prev
assert(cpu.stack[2043] == 45) -- Second frame ret
assert(cpu.stack[2042] == 0) -- Seconi frame locals
assert(cpu.call == 2044) -- Pointing at start of second frame
assert(cpu.data == 2047)

-- Pushing and then popping data
local cpu = CPU.new()
cpu:push_data(47)
cpu:push_data(32)
assert(cpu:pop_data() == 32)
assert(cpu:pop_data() == 47)
assert(cpu.data == 2047)

-- Reading and writing to memory
local cpu = CPU.new()
cpu:poke(37, 45)
assert(cpu.mem[37] == 45)
assert(cpu:peek(37) == 45)

-- Masking addresses to only the main memory range
local cpu = CPU.new()
cpu:poke(0xffffff, 47)
assert(cpu.mem[0x01ffff] == 47)
assert(cpu:peek(0xffffff) == 47)
assert(cpu:peek(0x01ffff) == 47)

-- Resetting the CPU
local cpu = CPU.new()
cpu.pc = 1000
cpu.halted = true
cpu:reset()
assert(cpu.pc == 256)
assert(not cpu.halted)

-- Running simple ASM
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 2
    add 2
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 4)

-- Decoding instructions
local cpu = CPU.new()
assert(cpu:decode(17) == 'swap')

-- Fetching instructions
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 2
]]))
assert(cpu:fetch() == 'push')
assert(cpu.next_pc == 258)
assert(cpu:pop_data() == 2)

-- A call instruction
local cpu = CPU.new()
cpu.next_pc = 10
cpu:push_data(35)
cpu:_call()
assert(cpu:pop_call() == 10)
assert(cpu.next_pc == 35)

-- Stack frame structure
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    call blah
blah: push 3
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 3)
assert(cpu.call == 2047)
assert(cpu.stack[cpu.call] == 0)
assert(cpu.stack[cpu.call-1] == 260)
assert(cpu.stack[cpu.call-2] == 0)

-- Returning from calls
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 3
    call blah
    hlt
blah: mul 2
    ret
]]))
cpu:run()
assert(cpu:pop_data() == 6)
assert(cpu.call == 0)

-- Setting frame size
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    call blah
blah: frame 3
    hlt
]]))
cpu:run()
assert(cpu.call == 2047)
assert(cpu.stack[cpu.call] == 0)
assert(cpu.stack[cpu.call-1] == 260)
assert(cpu.stack[cpu.call-2] == 3)

-- Setting frame locals
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    call blah
blah: frame 3
    push 7
    setlocal 1
    push 2
    setlocal 0
    hlt
]]))
cpu:run()
assert(cpu.call == 2047)
assert(cpu.stack[cpu.call] == 0)
assert(cpu.stack[cpu.call-1] == 260)
assert(cpu.stack[cpu.call-2] == 3)
assert(cpu.stack[cpu.call-3] == 2)
assert(cpu.stack[cpu.call-4] == 7)

-- Getting frame locals
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    call blah
blah: frame 3
    push 7
    setlocal 1
    push 2
    setlocal 0
    local 1
    mul 2
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 14)
