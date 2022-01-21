package.cpath = package.cpath .. ';./cvemu/?.so'
lfs = require('lfs')
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')
Opcodes = require('util.opcodes')

Symbols = nil

lfs.chdir('4th')

function init_cpu()
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.lines('4th.asm')
    Symbols = Loader.asm(cpu, iterator)

    local device = { contents = '' }
    cpu:install_device(2, 2,
                       { poke = function(_addr, val) device.contents = device.contents .. string.char(val) end })

    return cpu, device
end

function runinput(cpu, line)
    cpu:run()
    for i = 1, #line do
        local ch = line:byte(i, i)
        cpu:interrupt(ch, 65)
        cpu:run()
    end
    cpu:interrupt(10, 65) -- The newline
    cpu:run()
end

function call(cpu, symbol)
    cpu:push_call(Symbols.stop)
    cpu:set_pc(Symbols[symbol])
    cpu:run()
end

function test_fn(name, setup, check)
    local cpu, output = init_cpu()
    setup(cpu)
    call(cpu, name)
    st = { cpu:stack() }
    check(st, output.contents, cpu)
end

function array_eq(a1, a2)
    assert(#a1 == #a2, string.format('Arrays are different sizes: %d and %d', #a1, #a2))
    for i, n in ipairs(a1) do
        assert(n == a2[i], string.format('Difference at %d: %d != %d', i, n, a2[i]))
    end
    return true
end

function given_stack(contents)
    return function(cpu) for _, n in ipairs(contents) do cpu:push_data(n) end end
end

function given_memory(at, contents)
    if type(contents) == 'string' then
        contents = { contents:byte(1, #contents) }
        table.insert(contents, 0)
    elseif type(contents) == 'number' then
        contents = { contents }
    end
    return function(cpu)
        for i, b in ipairs(contents) do cpu:poke(at + i - 1, b) end
    end
end

function given_word(at, word)
    return function(cpu) cpu:poke24(at, word) end
end

function expect_stack(expected)
    return function(actual) assert(array_eq(expected, actual)) end
end

function expect_output(expected)
    return function(_s, actual) assert(expected == actual, string.format('exp %q,  act %q', expected, actual)) end
end

function expect_memory(start, ...)
    local mem = { ... }
    local expanded_mem = {}
    for _, el in ipairs(mem) do
        if type(el) == 'string' then table.insert(expanded_mem, el:byte())
        elseif type(el) == 'table' then
            for _, b in ipairs(el) do table.insert(expanded_mem, b) end
        else
            table.insert(expanded_mem, el)
        end
    end
    
    return function(_s, _o, cpu)
        for i, b in ipairs(expanded_mem) do
            local actual = cpu:peek(start + i - 1)
            assert(actual == b, string.format('%x: exp %d, act %d', start + i - 1, b, actual))
        end
    end
end

function word(val)
    val = val & 0xffffff
    return { val & 0xff, (val & 0xff00) / 256, (val & 0xff0000) / 65536 }
end

function op(mnemonic, args)
    if not args then args = 0 end
    return Opcodes.opcode_for(mnemonic) * 4 + args
end

function inst(mnemonic, arg)
    local o = op(mnemonic, 3)
    local w = word(arg)
    return { o, w[1], w[2], w[3] }
end

function call_inst(symbol)
    return inst('call', Symbols[symbol])
end

function expect_string(start, str)
    return function(_s, _o, cpu)
        for i = 1, #str do
            local actual = cpu:peek(start + i - 1)
            assert(actual == str:byte(i), string.format('%x: exp %q, act %q (%d)', start + i - 1, str:sub(i,i), string.char(actual), actual))
        end
        assert(cpu:peek(start + #str - 1), string.format('%x exp 0, act %d', start + #str - 1, cpu:peek(start + #str - 1)))
    end
end

function expect_word(addr, val)
    return function(_s, _o, cpu)
        local actual = cpu:peek24(addr)
        assert(actual == val, string.format('exp %xh, act %xh', val, actual))
    end
end

function dump_memory(addr, len)
    return function(_s, _o, cpu)
        for a = addr, addr + len do
            local b = cpu:peek(a)
            local c = string.char(b)
            local op = Opcodes.mnemonic_for(math.floor(b / 4))
            local args = b & 3
            if b < 32 then c = '' end
            print(string.format('%xh: %xh (%d) %q %q/%d', a, b, b, c, op, args))
        end
    end
end

function all(...)
    local fns = { ... }
    return function(...)
        for i, f in ipairs(fns) do f(...) end
    end
end

function test_line(line, ...)
    test_fn('handleline', given_memory(Symbols.line_buf, line), all(...))
end

-- example: test{'blah', stack = { 1 }, out = 'foo'}
function test(opts)
    test_fn('handleline', given_memory(Symbols.line_buf, opts[1]),
            all(expect_stack(opts.stack or {}), expect_output(opts.out or '')))
end

--------------------------------------------------

test_fn('dupnz',
        given_stack{ 3 },
        expect_stack{ 3, 3 })

test_fn('dupnz', 
        given_stack{ 0 },
        expect_stack{ 0 })

--------------------------------------------------

print('Text ends at: ' .. Symbols.line_buf)
print('Bytes available: ' .. 131072 - Symbols.heap_start)
print('Code size: ' .. Symbols.data_start - 0x400)
print('Including dictionaries: ' .. Symbols.line_buf - 0x400)
