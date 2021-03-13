package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
Loader = require('vemu.loader')

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
assert(cpu:peek(0) ~= nil)
assert(cpu:peek(131071) ~= nil)
assert(cpu:sp() == 1024)
assert(cpu:dp() == 256)

-- Pushing and then popping data
local cpu = CPU.new()
cpu:push_data(47)
cpu:push_data(32)
assert(cpu:pop_data() == 32)
assert(cpu:pop_data() == 47)

-- Reading and writing to memory
local cpu = CPU.new()
cpu:poke(37, 45)
assert(cpu:peek(37) == 45)

-- Masking addresses to only the main memory range
local cpu = CPU.new()
cpu:poke(0xffffff, 47)
assert(cpu:peek(0xffffff) == 47)
assert(cpu:peek(0x01ffff) == 47)

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
assert(cpu:sp() == 1024 - 3)
assert(cpu:peek24(cpu:sp()) == 0x400 + 4)

-- Comparisons
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 2
    gt 1
    push 2
    lt 5
    push 0xfffffe
    agt 3
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0)
assert(cpu:pop_data() == 1)
assert(cpu:pop_data() == 1)

-- Shifts
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 1
    lshift 3
    push 8
    rshift 2
    push 0x810000
    arshift 4
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 0xf81000)
assert(cpu:pop_data() == 2)
assert(cpu:pop_data() == 8)

-- Stack frame structure
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 100
blah: push 3
    hlt
    .org 0x400
    call blah
]]))
cpu:run()
assert(cpu:pop_data() == 3)

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

-- Branching
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 3
    brz @two
    push 20
    hlt
two: push 10
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 20)

local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 3
    brnz @two
    push 20
    hlt
two: push 10
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 10)

local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 0
    brz @two
    push 20
    hlt
two: push 10
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 10)

-- Backwards jumps
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
.org 0x400 ; start here
    push 1
loop:
    dup
    store 0x02 ; write it to output
    add 1
    dup
    gt 10 ; have we done it 10 times yet?
    brz @loop
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 11)
assert(cpu:peek(2) == 10)

-- Loads
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    load 1234
    loadw 1234
    hlt
]]))
cpu:poke(1234, 1)
cpu:poke(1235, 2)
cpu:poke(1236, 3)
cpu:run()
assert(cpu:pop_data() == 0x030201)
assert(cpu:pop_data() == 1)

-- Stores
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 0x1234
    store 1000
    push 0xaabbcc
    storew 3000
    hlt
]]))
cpu:poke(1001, 0)
cpu:run()
assert(cpu:peek(1000) == 0x34)
assert(cpu:peek(1001) == 0x00)
assert(cpu:peek(3000) == 0xcc)
assert(cpu:peek(3001) == 0xbb)
assert(cpu:peek(3002) == 0xaa)

-- Pushing to return stack
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 10
    push 4
    push 3
    pushr
    pushr
    hlt
]]))
cpu:run()
assert(cpu:pop_call() == 4)
assert(cpu:pop_call() == 3)
assert(cpu:pop_data() == 10)

-- Popping from return stack
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 10
    pushr 20
    pushr 4
    push 3
    popr
    add
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 7)
assert(cpu:pop_data() == 10)
assert(cpu:pop_call() == 20)

-- Calls after locals
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    pushr 5
    call blah
blah: pushr 3
    hlt
]]))
cpu:run()
assert(cpu:sp() == 1024 - 9)
assert(cpu:peek24(1024 - 3) == 5) -- First local
assert(cpu:peek24(1024 - 6) == 0x400 + 6) -- the return address
assert(cpu:peek24(1024 - 9) == 3) -- First local in the 2nd frame

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
    .org 0x400
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
    .org 0x400
    not 10
    not 0
    hlt
]]))
cpu:run()
assert(cpu:pop_data() ~= 0)
assert(cpu:pop_data() == 0)

-- Device reset hooks
local arr = {}
local cpu = CPU.new()
cpu:poke(100, 0)
cpu:install_device(200, 200, { reset = function() cpu:poke(100, 100) end })
cpu:reset()
assert(cpu:peek(100) == 100)

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
cpu:reset()
cpu:run()
assert(#arr == 2)
assert(arr[1] == 12)
assert(arr[2] == 15)

-- Range memory mapped output
local arr = {1, 2, 3, 4, 5, 6}
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 0
    store 201
    push 0
    storew 203
    hlt
]]))
cpu:install_device(200, 205, { poke = function(addr, val) arr[addr+1] = val end })
cpu:run()
assert(arr[1] == 1)
assert(arr[2] == 0)
assert(arr[3] == 3)
assert(arr[4] == 0)
assert(arr[5] == 0)
assert(arr[6] == 0)

-- Range memory mapped input
local arr = {1, 2, 3, 4, 5}
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    loadw 201
    hlt
]]))
cpu:install_device(200, 204, { peek = function(addr) return arr[addr+1] end })
cpu:run()
assert(cpu:pop_data() == (4 << 16) | (3 << 8) | 2)

-- Flags
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    inton
    hlt
]]))
local h, i = cpu:flags()
assert(not h and not i)
cpu:run()
h, i = cpu:flags()
assert(h and i)

-- Stack pointers
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 2000
    setsdp 3000
    hlt
]]))
cpu:run()
assert(cpu:sp() == 2000)
assert(cpu:dp() == 3000)

-- Rotate stack
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 10
    push 100
    push 200
    push 300
    rot
    hlt
]]))
cpu:run()
assert(cpu:pop_data() == 100)
assert(cpu:pop_data() == 300)
assert(cpu:pop_data() == 200)
assert(cpu:pop_data() == 10)

-- Fetch pointers
local cpu = CPU.new()
Loader.asm(cpu, iterator([[
    .org 0x400
    push 10
    pushr 20
    sdp
    hlt
]]))
cpu:run()
-- starts at 256, we added 3 with the push, then added 6 more by running sdp
assert(cpu:pop_data() == 265)
-- starts at 1024, subtracted 3 with the pushr
assert(cpu:pop_data() == 1021)
assert(cpu:pop_data() == 10)

-- -- Benchmark
-- local cpu = CPU.new()
-- Loader.forge(cpu, iterator([[
--   : count ( max -- )
--   0 local sum !
--   0 for n
--   sum n + sum!
--   loop ;
--   10000 count
-- ]]))
-- local start = os.clock()
-- cpu:run()
-- print(os.clock() - start)
