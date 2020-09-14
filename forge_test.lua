forge = require('forge')
vasm = require('vasm')
CPU = require('cpu')

-- # Forge tests

-- ## Utility functions

-- Map a function across a table
function table:map(fn)
    local t = {}
    for _, v in ipairs(self) do
        table.insert(t, fn(v))
    end
    return t
end

-- Return whether two arrays are (shallow) equal
function eq(tbl1, tbl2)
    for i = 1, math.max(#tbl1, #tbl2) do
        if tbl1[i] ~= tbl2[i] then
            return false
        end
    end
    return true
end

-- Pretty-print an array
function prettify(t)
    -- It's an empty object or an array
    if t[1] or not next(t) then
        local elements = table.map(t, function(el)
                                       if type(el) == 'table' then
                                           return prettify(el)
                                       else
                                           return string.format('%q', el)
                                       end
        end)

        return '(' .. table.concat(elements, ' ') .. ')'
    else
        -- It has a key but that key isn't 1, so it's a hash / object:
        local elements = {}
        local keys = {}

        for k, _ in pairs(t) do
            table.insert(keys, k)
        end

        table.sort(keys)

        for _, k in ipairs(keys) do
            local v = t[k]
            if type(v) == 'table' then
                table.insert(elements, k .. '=' .. prettify(v))
            else
                table.insert(elements, k .. '=' .. string.format('%q', v))
            end
        end
        return '{' .. table.concat(elements, ' ') .. '}'
    end
end

function test_read(src, expected)
    local actual = {}
    for token in forge.read(iterator(src)) do
        table.insert(actual, token)
    end

    if prettify(actual) == expected then return true
    else
        print('FAIL: [[' .. src .. ']]\nExpected: ' .. expected .. '\n  Actual: ' .. prettify(actual))
        return false
    end
end

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

-- ## Test cases

-- Normal word
test_read([[add]], [[("add")]])

-- Leading spaces
test_read([[   add]], [[("add")]])

-- Multiple words
test_read([[a b c]], [[("a" "b" "c")]])

-- Multiple lines
test_read('a\nb\n\n\nc', [[("a" "b" "c")]])

-- Numbers
test_read([[3 0x10 -5 0b100]], [[(3 16 -5 4)]])

-- Decimal zero
test_read([[0]], [[(0)]])

-- Words with punctuation
test_read([[a[] : b2c3]], [[("a[]" ":" "b2c3")]])

-- Words that start with numbers
test_read([[1+]], [[("1+")]])

-- # Compiler tests

function test_compile(opts)
    local src = opts[1]
    local asm = opts[2]
    local check = opts.check

    if opts.pending then
        print('PENDING: ' .. src)
        return
    end

    local actual_asm = {}
    local function emitter(str) table.insert(actual_asm, str:gsub('%s', ' '):match('^%s*(.*)')) end

    local success = true
    if check then
        success, err = pcall(forge.compile, iterator(src), emitter)
    else
        forge.compile(iterator(src), emitter)
    end

    if success and not eq(asm, actual_asm) then
        print('FAIL: Produced different assembly for [[' .. src .. ']]:')
        print('Expected:')
        for _,l in ipairs(asm) do print('\t' .. l) end
        print('Actual:')
        for _,l in ipairs(actual_asm) do print('\t' .. l) end
        return
    end

    if check then check{ error = err } end
end

-- Simple
test_compile{[[2 2 +]], {'.org 0x100', 'nop 2', 'nop 2', 'add', 'hlt'}}

-- Comments
test_compile{[[2 2 ( I am a comment ) +]], {'.org 0x100', 'nop 2', 'nop 2', 'add', 'hlt'}}

-- Line comments
test_compile{[[
2 2 \ I am a comment
+]], {'.org 0x100', 'nop 2', 'nop 2', 'add', 'hlt'}}

-- Double line comments
test_compile{[[
2 2 \ I am a comment \ also a comment
+]], {'.org 0x100', 'nop 2', 'nop 2', 'add', 'hlt'}}

-- Consecutive line comments
test_compile{[[\ I am a comment
\ also a comment]], {'.org 0x100', 'hlt'}}

-- Defining new words
test_compile{[[: sq ( n == n^2 ) dup * ; 2 sq 1024 !]], {'.org 0x100', 'nop 2', 'call _gen1', 'nop 1024', 'store24', 'hlt', '_gen1:', 'dup', 'mul', 'ret' }}

-- Reserved identifiers
test_compile{[[: : * ;]], {},
    check = function(env)
        assert(env.error:match('Invalid name ":" for word on line'))
    end
}

-- Variables
test_compile{[[variable x]], {'.org 0x100', 'hlt', '_gen1: .db 0'}}

-- Referring to variables
test_compile{[[variable x 3 x !]], {'.org 0x100', 'nop 3', 'nop _gen1', 'store24', 'hlt', '_gen1: .db 0'}}

-- Simple if
test_compile{[[: even 2 mod if 100 then ;]], {'.org 0x100', 'hlt', '_gen1:', 'nop 2', 'mod', 'brz @_gen2', 'nop 100', '_gen2:', 'ret'}}

-- If / else
test_compile{[[: even 2 mod if 100 else 200 then ;]], {'.org 0x100', 'hlt', '_gen1:', 'nop 2', 'mod', 'brz @_gen2', 'nop 100', 'jmpr @_gen3', '_gen2:', 'nop 200', '_gen3:', 'ret'}}

-- Infinite loop
test_compile{[[: forever begin 0 again ;]], {'.org 0x100', 'hlt', '_gen1:', '_gen2:', 'nop 0', 'jmpr @_gen2', '_gen3:', 'ret'}}

-- Loop with break
test_compile{[[: 10times 10 begin 1 - dup if break then again ;]], {'.org 0x100', 'hlt', '_gen1:', 'nop 10', '_gen2:', 'nop 1', 'sub', 'dup', 'brz @_gen4', 'jmpr @_gen3', '_gen4:', 'jmpr @_gen2', '_gen3:', 'ret'}}

-- While loop
test_compile{[[variable x : 10times 10 x ! begin x @ while x @ 1 - x ! again ;]],
    {'.org 0x100', 'hlt', '_gen2:', 'nop 10', 'nop _gen1', 'store24', '_gen3:', 'nop _gen1', 'load24', 'brz @_gen4', 'nop _gen1', 'load24', 'nop 1', 'sub', 'nop _gen1', 'store24', 'jmpr @_gen3', '_gen4:', 'ret', '_gen1: .db 0'}}

-- Local variables
test_compile{[[: blah local x 10 x :! x :@ ;]], {'.org 0x100', 'hlt', '_gen1:', 'frame 1', 'nop 10', 'nop 0', 'setlocal', 'nop 0', 'local', 'ret'}}

-- For loops
test_compile{[[: 100sum local sum 100 1 for n sum :@ n :@ + sum :! loop sum :@ ;]], {'.org 0x100', 'hlt', '_gen1:', 'frame 1', 'nop 100', 'nop 1', 'frame 3', 'setlocal 1', 'setlocal 2', '_gen2:', 'local 1', 'local 2', 'add 1', 'sub', 'brz @_gen3', 'nop 0', 'local', 'nop 1', 'local', 'add', 'nop 0', 'setlocal', 'local 1', 'add 1', 'setlocal 1', 'jmpr @_gen2', '_gen3:', 'frame 1', 'nop 0', 'local', 'ret'}}

-- Strings
test_compile{[[variable hi " hello, world! " hi !]], {'.org 0x100', 'nop _gen2', 'nop _gen1', 'store24', 'hlt', '_gen1: .db 0', '_gen2: .db "hello, world!\\0"'}}

-- Interrupts
test_compile{[[
: key inton ;
setiv key intoff]], {'.org 0x100', 'setiv _gen1', 'intoff', 'hlt', '_gen1:', 'inton', 'ret'}}

-- ## Full-stack tests

function array_iterator(arr)
    local i, e = nil, nil
    return function()
        i, e = next(arr, i)
        return e
    end
end

function array_emitter()
    local arr = {}
    local function emit(str) table.insert(arr, str) end
    return arr, emit
end

function serial_out()
    local arr = {}
    local function write(addr, val) table.insert(arr, val) end
    return arr, write
end

function test_run(opts)
    local src = opts[1]
    local expected_output = opts[2]
    local check = opts.check -- TODO

    if opts.pending then
        print('PENDING: ' .. src)
        return
    end

    local asm, emitter = array_emitter()
    forge.compile(iterator(src), emitter)
    local cpu = CPU.new()
    local console, callback = serial_out()
    cpu:install_device(200, 202, { poke = callback })
    cpu:load_asm(array_iterator(asm))
    cpu:run()

    if not eq(expected_output, console) then
        print('FAIL: Produced different output for [[' .. src .. ']]:')
        print('Expected:')
        print('\t' .. prettify(expected_output))
        print('Actual:')
        print('\t' .. prettify(console))
        return
    end

end

-- Basic byte output
test_run{[[2 200 !b 3 200 !b]], {2, 3}}

-- Calling words
test_run{[[: write 200 !b ; 20 10 write write]], {10, 20}}

-- Loops
test_run{[[: write 200 !b ; : 10loop 10 1 for n n :@ write loop ; 10loop]], {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}}

test_run{[[
   : 100sum
       local sum
       100 1 for n
           sum :@ n :@ + sum :!
       loop
       sum :@ ;
   100sum 200 !]], {186, 19, 0}} -- (19 << 8) + 186 == 5050

test_run{[[
    : test_while
        local c
        10 c :!
        begin
            c :@ dup
        while
            200 !b
            c :@ 1 - c :!
        again ;
    test_while]],
    {10, 9, 8, 7, 6, 5, 4, 3, 2, 1}}

test_run{[[
    : print ( str -- )
        local c
        c :!
        begin
            c :@ @ 0xff and \ grab a word, extract the low byte
        dup while \ until we hit a zero
            200 !b \ write this byte
            c :@ 1 + c :! \ increment
        again ;
    " hello! " print]],
    {('hello!'):byte(1, 6)}}
