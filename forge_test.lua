forge = require('forge')

-- # Assembly parsing tests

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
test_compile{[[2 2 +]], {'nop 2', 'nop 2', 'add', 'hlt'}}

-- Comments
test_compile{[[2 2 ( I am a comment ) +]], {'nop 2', 'nop 2', 'add', 'hlt'}}

-- Defining new words
test_compile{[[: sq ( n == n^2 ) dup * ; 2 sq 1024 !]], {'nop 2', 'call _gen_1', 'nop 1024', 'store24', 'hlt', '_gen_1:', 'dup', 'mul', 'ret' }}

-- Reserved identifiers
test_compile{[[: : * ;]], {},
    check = function(env)
        assert(env.error:match('Invalid name ":" for new word on line'))
    end
}
