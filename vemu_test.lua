local CPU = require('cpu')
local Loader = require('loader')

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
assert(cpu.mem[1023] == 0x00) -- high,
assert(cpu.mem[1022] == 0x03) -- middle,
assert(cpu.mem[1021] == 0xff) -- and low bytes of 1023, the starting sp
assert(cpu:peek24(1023 - 5) == 1024) -- starting stack frame return addr
assert(cpu:peek24(1023 - 8) == 0) -- starting stack frame, no locals
assert(cpu.mem[0] ~= nil)
assert(cpu.mem[131071] ~= nil)
assert(cpu.mem[131072] == nil)
assert(cpu.sp == 1023)
assert(cpu.dp == 256)

-- State after pushing data
local cpu = CPU.new()
cpu:push_data(37)
cpu:push_data(45)
assert(cpu:peek24(256) == 37)
assert(cpu:peek24(259) == 45)
assert(cpu.sp == 1023)
assert(cpu.dp == 256 + 6)

-- State after pushing return addresses
local cpu = CPU.new()
cpu:push_call(37)
cpu:push_call(45)
assert(cpu:peek24(1023 - 2) == 1023) -- First frame prev (set on reset)
assert(cpu:peek24(1023 - 5) == 1024) -- First frame ret (set on reset)
assert(cpu:peek24(1023 - 8) == 0) -- First frame locals (set on reset)
assert(cpu:peek24(1023 - 11) == 1023) -- Second frame prev
assert(cpu:peek24(1023 - 14) == 37) -- Second frame ret
assert(cpu:peek24(1023 - 17) == 0) -- Second frame locals
assert(cpu:peek24(1023 - 20) == 1023 - 9) -- Third frame prev
assert(cpu:peek24(1023 - 23) == 45) -- Third frame ret
assert(cpu:peek24(1023 - 26) == 0) -- Third frame locals
assert(cpu.sp == 1023 - 18) -- Pointing at start of second frame
assert(cpu.dp == 256)

-- Pushing and then popping data
local cpu = CPU.new()
cpu:push_data(47)
cpu:push_data(32)
assert(cpu:pop_data() == 32)
assert(cpu:pop_data() == 47)
assert(cpu.dp == 256)

-- Reading and writing to memory
local cpu = CPU.new()
cpu:poke(37, 45)
cpu:poke24(54, 0x123456)
assert(cpu.mem[37] == 45)
assert(cpu:peek(37) == 45)
assert(cpu:peek(54) == 0x56)
assert(cpu:peek(55) == 0x34)
assert(cpu:peek(56) == 0x12)

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
assert(cpu.pc == 1024)
assert(not cpu.halted)

-- Running a simple binary
local cpu = CPU.new()
cpu:poke(0x400, 0x01) -- nop 1 arg
cpu:poke(0x401, 0x02) -- 2
cpu:poke(0x402, 0x05) -- add 1 arg
cpu:poke(0x403, 0x02) -- 2
cpu:poke(0x404, 29 << 2)
cpu:run()
assert(cpu:pop_data() == 4)

-- Running simple ASM
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
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
Loader.asm(cpu, iterator([[
    .org 0x400
    push 2
]]))
assert(cpu:fetch() == 'push')
assert(cpu.next_pc == 0x400 + 2)
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
Loader.asm(cpu, iterator([[
    .org 1024
    call blah
blah: push 3
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 3)
assert(cpu.sp == 1023 - 9)
assert(cpu:peek24(cpu.sp - 2) == 1023)
assert(cpu:peek24(cpu.sp - 5) == 0x400 + 4)
assert(cpu:peek24(cpu.sp - 8) == 0)

-- Returning from calls
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 3
    call blah
    hlt
blah: mul 2
    ret
]]))
cpu:run()
assert(cpu:pop_data() == 6)
assert(cpu.sp == 1023)

-- Setting frame size
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    call blah
blah: frame 3
    hlt
]]))
cpu:run()
assert(cpu.sp == 1023 - 9)
assert(cpu:peek24(cpu.sp - 2) == 1023)
assert(cpu:peek24(cpu.sp - 5) == 0x404)
assert(cpu:peek24(cpu.sp - 8) == 3)

-- Setting frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    call blah
blah: frame 3
    push 7
    setlocal 1
    push 2
    setlocal 0
    hlt
]]))
cpu:run()
assert(cpu.sp == 1023 - 9)
assert(cpu:peek24(cpu.sp - 2) == 1023)
assert(cpu:peek24(cpu.sp - 5) == 0x404)
assert(cpu:peek24(cpu.sp - 8) == 3)
assert(cpu:peek24(cpu.sp - 11) == 2)
assert(cpu:peek24(cpu.sp - 14) == 7)

-- Getting frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
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
Loader.asm(cpu, iterator([[
    .org 0x400
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
Loader.asm(cpu, iterator([[
    .org 0x400
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
assert(cpu.sp == 1023 - 15)
assert(cpu:peek24(1023 - 2) == 1023) -- First frame
assert(cpu:peek24(1023 - 5) == 0x400)
assert(cpu:peek24(1023 - 8) == 2)
assert(cpu:peek24(1023 - 14) == 5)

assert(cpu:peek24(cpu.sp - 2) == 1023) -- Second frame
assert(cpu:peek24(cpu.sp - 5) == 0x400 + 10)
assert(cpu:peek24(cpu.sp - 8) == 2)
assert(cpu:peek24(cpu.sp - 14) == 3)

-- Out-of-range frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    frame 3
    local 7
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0)

-- Comparing values
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
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
Loader.asm(cpu, iterator([[
    .org 1024
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
Loader.asm(cpu, iterator([[
    .org 1024
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
Loader.asm(cpu, iterator([[
    .org 0x400
    push 12
    store 200
    push 15
    store 200
    hlt
]]))
cpu:install_device(200, 200, { poke = function(_, val) table.insert(arr, val) end })
cpu:run()
assert(#arr == 2)
assert(arr[1] == 12)
assert(arr[2] == 15)

-- Range memory mapped output
local arr = {1, 2, 3, 4, 5}
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 0
    store 201
    push 0
    store16 203
    hlt
]]))
cpu:install_device(200, 204, { poke = function(addr, val) arr[addr+1] = val end })
cpu:run()
assert(arr[1] == 1)
assert(arr[2] == 0)
assert(arr[3] == 3)
assert(arr[4] == 0)
assert(arr[5] == 0)

-- Range memory mapped input
local arr = {1, 2, 3, 4, 5}
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    load24 201
    hlt
]]))
cpu:install_device(200, 204, { peek = function(addr) return arr[addr+1] end })
cpu:run()
assert(cpu:pop_data() == (4 << 16) | (3 << 8) | 2)

-- Benchmark
local cpu = CPU.new()
Loader.forge(cpu, iterator([[
  : count ( max -- )
  local sum
  0 for n
  sum n + sum!
  loop ;
  10000 count
]]))
local start = os.clock()
cpu:run()
print(os.clock() - start)
