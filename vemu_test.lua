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
assert(cpu.stack[2047] == 2047)
assert(cpu.stack[2048] == nil)
assert(cpu.mem[0] ~= nil)
assert(cpu.mem[131071] ~= nil)
assert(cpu.mem[131072] == nil)
assert(cpu.call == 2047)
assert(cpu.data == 2047)

-- State after pushing data
local cpu = CPU.new()
cpu:push_data(37)
cpu:push_data(45)
assert(cpu.stack[0] == 37)
assert(cpu.stack[1] == 45)
assert(cpu.call == 2047)
assert(cpu.data == 1)

-- State after pushing return addresses
local cpu = CPU.new()
cpu:push_call(37)
cpu:push_call(45)
assert(cpu.stack[2047] == 2047) -- First frame prev
assert(cpu.stack[2046] == 0) -- First frame ret
assert(cpu.stack[2045] == 0) -- First frame locals

assert(cpu.stack[2044] == 2047) -- Second frame prev
assert(cpu.stack[2043] == 37) -- Second frame ret
assert(cpu.stack[2042] == 0) -- Second frame locals

assert(cpu.stack[2041] == 2044) -- Third frame prev
assert(cpu.stack[2040] == 45) -- Third frame ret
assert(cpu.stack[2039] == 0) -- Third frame locals
assert(cpu.call == 2041) -- Pointing at start of second frame
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

-- Running a simple binary
local cpu = CPU.new()
cpu:poke(256, 0x01) -- nop 1 arg
cpu:poke(257, 0x02) -- 2
cpu:poke(258, 0x05) -- add 1 arg
cpu:poke(259, 0x02) -- 2
cpu:poke(260, 29 << 2)
cpu:run()
assert(cpu:pop_data() == 4)

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
assert(cpu:decode(21) == 'swap')

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
assert(cpu.call == 2044)
assert(cpu.stack[cpu.call] == 2047)
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
assert(cpu.call == 2047)

-- Setting frame size
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    call blah
blah: frame 3
    hlt
]]))
cpu:run()
assert(cpu.call == 2044)
assert(cpu.stack[cpu.call] == 2047)
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
assert(cpu.call == 2044)
assert(cpu.stack[cpu.call] == 2047)
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

-- Top frame locals
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    frame 2
    push 5
    setlocal 1
    push 12
    local 1
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 5)
assert(cpu:pop_data() == 12)

-- Calls after locals
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    frame 2
    push 5
    setlocal 1
    call blah
blah: frame 2
    push 3
    setlocal 1
    hlt
]]))
cpu:run()
assert(cpu.call == 2042)
assert(cpu.stack[2047] == 2047) -- First frame
assert(cpu.stack[2046] == 0)
assert(cpu.stack[2045] == 2)
assert(cpu.stack[2044] == 0)
assert(cpu.stack[2043] == 5)

assert(cpu.stack[cpu.call] == 2047) -- Second frame
assert(cpu.stack[cpu.call-1] == 266)
assert(cpu.stack[cpu.call-2] == 2)
assert(cpu.stack[cpu.call-3] == 0)
assert(cpu.stack[cpu.call-4] == 3)

-- Out-of-range frame locals
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    frame 3
    local 7
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0)

-- Comparing values
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 10
    gt 20
    push 20
    gt 5
    push 10
    lt 20
    push 10
    lt 5
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0) -- 10 < 5 ?
assert(cpu:pop_data() ~= 0) -- 10 < 20 ?
assert(cpu:pop_data() ~= 0) -- 20 > 5 ?
assert(cpu:pop_data() == 0) -- 10 > 20 ?

-- Comparing values arithmetically
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 10
    mul 0xffffff
    agt 20
    push 20
    push 5
    mul 0xffffff
    agt
    push 10
    mul 0xffffff
    alt 20
    push 10
    push 5
    mul 0xffffff
    alt
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0) -- 10 < 5 ?
assert(cpu:pop_data() ~= 0) -- -10 < 20 ?
assert(cpu:pop_data() ~= 0) -- 20 > -5 ?
assert(cpu:pop_data() == 0) -- -10 > 20 ?

-- Logical not
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    not 10
    not 0
    hlt
]]))
cpu:run()
assert(cpu:pop_data() ~= 0)
assert(cpu:pop_data() == 0)

-- Basic memory mapped output
local arr = {}
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 12
    store 200
    push 15
    store 200
    hlt
]]))
cpu:output_device(200, 200, function(_, val) table.insert(arr, val) end)
cpu:run()
assert(#arr == 2)
assert(arr[1] == 12)
assert(arr[2] == 15)

-- Range memory mapped output
local arr = {1, 2, 3, 4, 5}
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    push 0
    store 201
    push 0
    store16 203
    hlt
]]))
cpu:output_device(200, 204, function(addr, val) arr[addr+1] = val end)
cpu:run()
assert(arr[1] == 1)
assert(arr[2] == 0)
assert(arr[3] == 3)
assert(arr[4] == 0)
assert(arr[5] == 0)

-- Range memory mapped input
local arr = {1, 2, 3, 4, 5}
local cpu = CPU.new()
cpu:load(iterator([[
    .org 256
    load24 201
    hlt
]]))
cpu:input_device(200, 204, function(addr) return arr[addr+1] end)
cpu:run()
assert(cpu:pop_data() == (4 << 16) | (3 << 8) | 2)
