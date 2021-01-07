local CPU = require('cpu')
local Loader = require('loader')
local opcodes = require('opcodes')

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
assert(cpu.mem[0] ~= nil)
assert(cpu.mem[131071] ~= nil)
assert(cpu.mem[131072] == nil)
assert(cpu.sp == 1024)
assert(cpu.dp == 256)

-- State after pushing data
local cpu = CPU.new()
cpu:push_data(37)
cpu:push_data(45)
assert(cpu:peek24(256) == 37)
assert(cpu:peek24(259) == 45)
assert(cpu.sp == 1024)
assert(cpu.dp == 256 + 6)

-- State after pushing return addresses
local cpu = CPU.new()
cpu:push_call(37)
cpu:push_call(45)
assert(cpu:peek24(cpu.sp) == 45)
assert(cpu:peek24(cpu.sp + 3) == 37)
assert(cpu.sp == 1024 - 6)
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
cpu:poke(0x404, opcodes.opcode_for('hlt') << 2) -- hlt
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
assert(cpu.sp == 1024 - 3)
assert(cpu:peek24(cpu.sp) == 0x400 + 4)

-- Returning from calls
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    nop 3
    call blah
    hlt
blah: mul 2
    ret
]]))
cpu:run()
assert(cpu:pop_data() == 6)
assert(cpu.sp == 1024)

-- Setting frame size
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    call blah
blah: decsp 9
    hlt
]]))
cpu:run()
assert(cpu.sp == 1024 - 12)
assert(cpu:pop_data() == cpu.sp)
assert(cpu:peek24(cpu.sp + 9) == 0x404)

-- Setting frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    call blah
blah: decsp 9
    dup
    push 7
    swap
    store24
    add 3
    push 2
    swap
    store24
    hlt
]]))
cpu:run()
assert(cpu.sp == 1024 - 12)
assert(cpu:peek24(cpu.sp) == 7)
assert(cpu:peek24(cpu.sp + 3) == 2)

-- Getting frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    call blah
blah: push 7
    decsp 3
    store24
    sp
    load24
    mul 2
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 14)

-- Top frame locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 5
    decsp 6
    add 3
    store24
    push 12
    sp
    add 3
    load24
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 5)
assert(cpu:pop_data() == 12)

-- Calls after locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 5
    decsp 6
    add 3
    store24
    call blah
blah: push 3
    decsp 6
    add 3
    store24
    hlt
]]))
cpu:run()
assert(cpu.sp == 1024 - 15)
assert(cpu:peek24(1024 - 3) == 5) -- First local
assert(cpu:peek24(1024 - 9) == 0x400 + 11) -- Skip a local, the return address
assert(cpu:peek24(1024 - 12) == 3) -- First local in the 2nd frame

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

-- 2dup
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 1024
    nop 10
    nop 20
    2dup
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 20)
assert(cpu:pop_data() == 10)
assert(cpu:pop_data() == 20)
assert(cpu:pop_data() == 10)

-- pick
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 1024
    nop 10
    nop 20
    pick 1
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 10)
assert(cpu:pop_data() == 20)
assert(cpu:pop_data() == 10)

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
