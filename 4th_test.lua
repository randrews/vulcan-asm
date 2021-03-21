package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')
Opcodes = require('util.opcodes')

Symbols = nil

function init_cpu()
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.open('4th.asm')
    Symbols = Loader.asm(cpu, iterator:lines())

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
    local cpu, output = init_cpu('4th.asm')
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

--------------------------------------------------

-- cpu, output, symbols = init_cpu('4th.asm')
-- readloop(cpu, 'foo\n')
-- assert(output.contents == 'You called foo\n')
-- st = { cpu:stack() }
-- assert(#st == 0)

--------------------------------------------------

test_fn('dupnz',
        given_stack{ 3 },
        expect_stack{ 3, 3 })

test_fn('dupnz', 
        given_stack{ 0 },
        expect_stack{ 0 })

--------------------------------------------------

test_fn('dupz',
        given_stack{ 0 },
        expect_stack{ 0, 0 })

test_fn('dupz',
        given_stack{ 5 },
        expect_stack{ 5 })

--------------------------------------------------

test_fn('dup2', 
        given_stack{ 12, 34 },
        expect_stack{ 12, 34, 12, 34 })

--------------------------------------------------

test_fn('print',
        given_stack{ Symbols.foo_str },
        all(expect_output('You called foo'), expect_stack{ }))

test_fn('print',
        all(given_memory(0x10000, "Hello!"), given_stack{ 0x10000 }),
        all(expect_output('Hello!'), expect_stack{ }))

--------------------------------------------------

test_fn('cr',
        given_stack{ 7 },
        all(expect_output('\n'), expect_stack{ 7 }))

--------------------------------------------------

test_fn('streq',
        given_stack{ Symbols.foo_str, Symbols.bar_str },
        expect_stack{ 0 })

test_fn('streq',
        given_stack{ Symbols.foo_str, Symbols.foo_str },
        expect_stack{ 1 })

--------------------------------------------------

test_fn('wordeq',
        all(given_memory(0x10000, 'foo'),
            given_memory(0x10500, 'foo'),
            given_stack{ 0x10000, 0x10500 }),
        expect_stack{ 1 })

test_fn('wordeq',
        all(given_memory(0x10000, 'foo   '),
            given_memory(0x10500, 'foo\n'),
            given_stack{ 0x10000, 0x10500 }),
        expect_stack{ 1 })

test_fn('wordeq',
        all(given_memory(0x10000, 'bar   '),
            given_memory(0x10500, 'foo\n'),
            given_stack{ 0x10000, 0x10500 }),
        expect_stack{ 0 })

-- Because each are a zero-length word followed by other stuff
test_fn('wordeq',
        all(given_memory(0x10000, ' bar'),
            given_memory(0x10500, ' foo'),
            given_stack{ 0x10000, 0x10500 }),
        expect_stack{ 1 })

--------------------------------------------------

-- First two dict entries are foo and bar. foo plus null plus
-- 3-byte definition is dict + 7
test_fn('advance_entry',
        given_stack{ Symbols.d_foo },
        expect_stack{ Symbols.d_bar })

--------------------------------------------------

-- Does it find the first entry?
test_fn('tick',
        all(
            given_memory(0x10000, 'foo'),
            given_stack{ 0x10000 }),
        expect_stack{ Symbols.foo })

-- Can it find a later entry?
test_fn('tick',
        all(given_memory(0x10000, 'bar'),
            given_stack{ 0x10000 }),
        expect_stack{ Symbols.bar })

-- Does it detect when they only partially match?
test_fn('tick',
        all(given_memory(0x10000, 'bar234'),
            given_stack{ 0x10000 }),
        expect_stack{ 0 })

-- What about something that doesn't match at all?
test_fn('tick',
        all(given_memory(0x10000, 'nothing'),
            given_stack{ 0x10000 }),
        expect_stack{ 0 })

-- Target word is blank?
test_fn('tick',
        all(given_memory(0x10000, ''),
            given_stack{ 0x10000 }),
        expect_stack{ 0 })

-- There's a null in the middle? This should stop after the first part
test_fn('tick',
        all(given_memory(0x10000, 'foo\0bar'),
            given_stack{ 0x10000 }),
        expect_stack{ Symbols.foo })

-- Does it harm lower things on the stack?
test_fn('tick',
        all(given_memory(0x10000, '.'),
            given_stack{ 1, 2, 3, 0x10000 }),
        expect_stack{ 1, 2, 3, Symbols.itoa })

-- Does it find the last thing in the dictionary?
test_fn('tick',
        all(given_memory(0x10000, ':'),
            given_stack{ 1, 2, 3, 0x10000 }),
        expect_stack{ 1, 2, 3, Symbols.colon_word })

--------------------------------------------------

test_fn('word_char',
        given_stack{ 68 },
        expect_stack{ 1 })

test_fn('word_char',
        given_stack{ 9 }, -- tab
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 10 }, -- lf
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 13 }, -- cr
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 32 }, -- space
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 0 }, -- null
        expect_stack{ 0 })

--------------------------------------------------

test_fn('is_digit',
        given_stack{ 48 },
        expect_stack{ 1 })

test_fn('is_digit',
        given_stack{ 57 },
        expect_stack{ 1 })

test_fn('is_digit',
        given_stack{ 65 },
        expect_stack{ 0 })

--------------------------------------------------

test_fn('is_number',
        all(given_memory(0x10000, '1234\0'),
            given_stack{ 0x10000 }),
        expect_stack{ 1234, 1 })

test_fn('is_number',
        all(given_memory(0x10000, '34cd\0'),
            given_stack{ 0x10000 }),
        expect_stack{ 0x10002, 0 })

test_fn('is_number',
        all(given_memory(0x10000, '512  \0'),
            given_stack{ 0x10000 }),
        expect_stack{ 512, 1 })

--------------------------------------------------

test_fn('itoa',
        given_stack{ 1234 },
        all(expect_output('1234'),
            expect_stack{ },
            expect_word(Symbols.heap_ptr, Symbols.heap_start)))

test_fn('itoa',
        given_stack{ 7 },
        all(expect_output('7'),
            expect_stack{ }))

test_fn('itoa',
        given_stack{ 0 },
        all(expect_output('0'),
            expect_stack{ }))

--------------------------------------------------

test_fn('onkeypress',
        given_stack{ string.byte('f'), 65 },
        all(expect_stack{ },
            expect_memory(Symbols.line_buf, string.byte('f')),
            expect_memory(Symbols.line_len, 1)))

test_fn('onkeypress',
        all(given_memory(Symbols.line_buf, 'fo'),
            given_memory(Symbols.line_len, 2),
            given_stack{ string.byte('o'), 65 }),
        all(expect_stack{ },
            expect_memory(Symbols.line_buf, string.byte('f'), string.byte('o'), string.byte('o')),
            expect_memory(Symbols.line_len, 3)))

-- test_fn('onkeypress',
--         all(given_memory(Symbols.line_buf, 'foo'),
--             given_memory(Symbols.line_len, 3),
--             given_stack{ 10, 65 }),
--         all(expect_stack{ },
--             expect_memory(Symbols.line_buf, string.byte('f'), string.byte('o'), string.byte('o'), 0),
--             expect_memory(Symbols.line_len, 0))) -- come back to this once handleline works

--------------------------------------------------

-- Can it handle a blank word
test_fn('handleword',
        all(given_memory(Symbols.line_buf, 0),
            given_stack{ Symbols.line_buf }),
        expect_stack{ })

-- Can it handle a word in the dictionary
test_fn('handleword',
        all(given_memory(Symbols.line_buf, 'foo'),
            given_stack{ Symbols.line_buf }),
        all(expect_stack{ },
            expect_output('You called foo\n')))

-- Can it handle a word later in the dictionary
test_fn('handleword',
        all(given_memory(Symbols.line_buf, 'bar'),
            given_stack{ Symbols.line_buf }),
        all(expect_stack{ },
            expect_output('Bar was called, probably by you!\n')))

-- Can it pass the correct stack to the word
test_fn('handleword',
        all(given_memory(0x10000, '.'),
            given_stack{ 5678, 0x10000 }),
        all(expect_stack{ },
            expect_output('5678')))

-- Can it pass the correct stack to the word
test_fn('handleword',
        all(given_memory(0x10000, '*'),
            given_stack{ 3, 5, 0x10000 }),
        expect_stack{ 15 })

-- Will it parse a number
test_fn('handleword',
        all(given_memory(0x10000, '1234'),
            given_stack{ 0x10000 }),
        expect_stack{ 1234 })

-- Will it flag a missing word
test_fn('handleword',
        all(given_memory(0x10000, 'nope'),
            given_stack{ 0x10000 }),
        all(expect_stack{ },
            expect_output("That word wasn't found: nope\n")))

--------------------------------------------------

test_fn('skip_nonword',
        all(given_memory(0x10000, '   foo'),
            given_stack{ 2, 3, 0x10000 }),
        expect_stack{ 2, 3, 0x10003 })

test_fn('skip_nonword',
        all(given_memory(0x10000, ' \0\n\tfoo'),
            given_stack{ 2, 3, 0x10000 }),
        expect_stack{ 2, 3, 0x10001 })

test_fn('skip_nonword',
        all(given_memory(0x10000, 'foo'),
            given_stack{ 2, 3, 0x10000 }),
        expect_stack{ 2, 3, 0x10000 })

--------------------------------------------------

test_fn('skip_word',
        all(given_memory(0x10000, 'foo'),
            given_stack{ 2, 3, 0x10000 }),
        expect_stack{ 2, 3, 0x10003 })

test_fn('skip_word',
        all(given_memory(0x10000, '   foo'),
            given_stack{ 2, 3, 0x10000 }),
        expect_stack{ 2, 3, 0x10000 })

--------------------------------------------------

-- An empty line
test_fn('handleline',
        all(given_memory(Symbols.line_buf, 0),
            given_stack{ }),
        expect_stack{ })

-- A line with one word on it
test_fn('handleline',
        all(given_memory(Symbols.line_buf, 'foo'),
            given_stack{ }),
        all(expect_stack{ },
            expect_output('You called foo\n')))

-- A line with only whitespace
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '  '),
            given_stack{ 2, 3 }),
        expect_stack{ 2, 3 })

-- One word and some previous stack
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '+'),
            given_stack{ 2, 3 }),
        expect_stack{ 5 })

-- One number
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '104'),
            given_stack{ 2, 3 }),
        expect_stack{ 2, 3, 104 })

-- Two words
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '10 23'),
            given_stack{ 100 }),
        expect_stack{ 100, 10, 23 })

-- Two words with much whitespace
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '10    .'),
            given_stack{ 100 }),
        all(expect_stack{ 100 },
            expect_output('10')))

-- A line with trailing whitespace
test_fn('handleline',
        all(given_memory(Symbols.line_buf, 'foo   '),
            given_stack{ }),
        all(expect_stack{ },
            expect_output("You called foo\n")))

-- Passing stack to some things
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '2 3 + + .'),
            given_stack{ 5 }),
        all(expect_stack{ },
            expect_output('10')))

-- Multiple words, leading and trailing space...
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '  \n\t\t155 10 20 + 34 * .   '),
            given_stack{ }),
        all(expect_stack{ 155 },
            expect_output('1020')))

--------------------------------------------------

test_fn('find_byte',
        all(given_memory(0x10000, 'floop"'),
            given_stack{ 34, 0x10000 }),
        all(expect_stack{ 0x10005 }))

test_fn('find_byte',
        all(given_memory(0x10000, 'floop"'),
            given_stack{ 65, 0x10000 }),
        all(expect_stack{ 0 }))

test_fn('find_byte',
        all(given_memory(0x10000, 'Apple'),
            given_stack{ 65, 0x10000 }),
        all(expect_stack{ 0x10000 }))

--------------------------------------------------

test_fn('read_string',
        all(given_memory(0x10000, 'floop"'),
            given_stack{ 0x10000 }),
        expect_stack{ 0x10000, 0x10005 })

test_fn('read_string',
        all(given_memory(0x10000, '  floop"'),
            given_stack{ 0x10000 }),
        expect_stack{ 0x10002, 0x10007 })

test_fn('read_string',
        all(given_memory(0x10000, '"'),
            given_stack{ 0x10000 }),
        expect_stack{ 0x10000, 0x10000 })

test_fn('read_string',
        all(given_memory(0x10000, 'nope'),
            given_stack{ 0x10000 }),
        expect_stack{ 0 })

--------------------------------------------------

test_fn('handleline',
        all(given_memory(Symbols.line_buf, '." hello, world"'),
            given_stack{ }),
        all(expect_stack{ },
            expect_output('hello, world')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, '." hello, world   "   '),
            given_stack{ }),
        all(expect_stack{ },
            expect_output('hello, world   ')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, '5 ." hello, world   "'),
            given_stack{ }),
        all(expect_stack{ 5 },
            expect_output('hello, world   ')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, '5 ." hello, world: " 3 + .'),
            given_stack{ }),
        all(expect_stack{ },
            expect_output('hello, world: 8')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, '." unterminated...'),
            given_stack{ }),
        all(expect_stack{ },
            expect_output('Unclosed string')))

--------------------------------------------------

test_fn('copy_region',
        all(given_memory(0x10000, 'something'),
            given_stack{ 0x10000, 0x1000a, 0x12000 }),
        all(expect_stack{ },
            expect_string(0x12000, 'something')))

test_fn('copy_region',
        all(given_memory(0x10000, 'something'),
            given_memory(0x12000, 'foo'),
            given_stack{ 0x10000, 0x10000, 0x12000 }),
        all(expect_stack{ },
            expect_string(0x12000, 'foo')))

--------------------------------------------------

test_fn('word_to_dict',
        all(given_memory(0x10000, 'blah'),
            given_stack{ 0x10000 }),
        all(expect_stack{ Symbols.heap_start + 5 },
            expect_memory(Symbols.heap_start, 'b', 'l', 'a', 'h', 0, 0, 0, 0),
            expect_word(Symbols.dictionary, Symbols.heap_start),
            expect_word(Symbols.heap_start + 8, Symbols.d_foo),
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 11)))

--------------------------------------------------

-- These are actually tests of colon_word
test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': '),
            given_stack{ 0x10000 }),
        all(expect_stack{ 0x10000 },
            expect_output('Expected word, found end of input\n')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': xyz'),
            given_stack{ 0x12345 }),
        all(expect_stack{ 0x12345 },
            expect_memory(Symbols.heap_start, 'x', 'y', 'z', 0),
            expect_word(Symbols.heap_start + 4, Symbols.heap_start + 10),
            expect_word(Symbols.heap_start + 7, Symbols.d_foo),
            expect_word(Symbols.handleword_hook, Symbols.compileword),
            expect_word(Symbols.current_mode, 1)))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah 123'),
            given_stack{ 0x12345 }),
        all(expect_stack{ 0x12345 },
            expect_memory(Symbols.heap_start, 'b', 'l', 'a', 'h', 0),
            expect_memory(Symbols.heap_start + 11, 3, 123, 0, 0), -- 11 byte dict entry: 5 word + 3 def + 3 next ptr
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 15)))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah bar'),
            given_stack{ 0x12345 }),
        all(expect_stack{ 0x12345 },
            expect_memory(Symbols.heap_start + 11, Opcodes.opcode_for('call') * 4 + 3), -- instruction byte
            expect_word(Symbols.heap_start + 12, Symbols.bar),
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 15)))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah ;'),
            given_stack{ 0x12345 }),
        all(expect_stack{ 0x12345 },
            expect_memory(Symbols.heap_start + 11, Opcodes.opcode_for('ret') * 4), -- return instruction
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 12),
            expect_word(Symbols.handleword_hook, Symbols.handleword),
            expect_word(Symbols.current_mode, 0)))

--------------------------------------------------

-- Putting everything together

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah 10 * ; 5 blah .'),
            given_stack{ 100 }),
        all(expect_stack{ 100 },
            expect_output('50'),
            expect_word(Symbols.current_mode, 0)))

--------------------------------------------------

test_fn('allot',
        all(given_stack{ 20, 10 }),
        all(expect_stack{ 20, Symbols.heap_start },
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 10)))

--------------------------------------------------

-- This isn't something you should do really, free without an allot, but it's a test of how
-- free actually works, so...
test_fn('free',
        all(given_stack{ 20, 10 }),
        all(expect_stack{ 20 },
            expect_word(Symbols.heap_ptr, Symbols.heap_start - 10)))

--------------------------------------------------

-- Conditionals
test_fn('if_word',
        all(given_stack{ 100 }),
        all(expect_stack{ 100 },
            expect_word(Symbols.c_stack_ptr, Symbols.c_stack + 3),
            expect_memory(Symbols.heap_start, Opcodes.opcode_for('brz') * 4 + 3, 0, 0, 0),
            expect_word(Symbols.c_stack, Symbols.heap_start + 1)))

test_fn('resolve_c_addr',
        all(given_word(Symbols.c_stack_ptr, Symbols.c_stack + 3),
            given_word(Symbols.c_stack, 10000), -- Push a 10000 on to the c stack
            given_stack{ 100, 10200 } -- We're going to resolve that to point relatively at 10200
        ),
        all(expect_stack{ 100 },
            expect_word(Symbols.c_stack_ptr, Symbols.c_stack),
            expect_word(10000, 201))) -- 201 because the relative addr is from the instr byte, one behind the arg LB

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah if 10 then ; 0 blah'),
            given_stack{ 100 }),
        all(expect_stack{ 100 },
            expect_memory(Symbols.heap_start + 11, Opcodes.opcode_for('brz') * 4 + 3)))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah if 10 then ; 20 blah'),
            given_stack{ 100 }),
        all(expect_stack{ 100, 10 }))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah if else 5 then ; 0 blah'),
            given_stack{ 100 }),
        all(expect_stack{ 100, 5 },
            expect_memory(Symbols.heap_start + 11, Opcodes.opcode_for('brz') * 4 + 3)))

--------------------------------------------------

-- Compiling quotation stuff
test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah ." Hello" ; blah'),
            given_stack{ 100 }),
        all(expect_stack{ 100 },
            expect_memory(Symbols.heap_start + 11,
                          op('jmpr', 3), word(10), -- Jump past the data, 6 bytes string, 4 bytes the jmpr instruction itself
                          'H', 'e', 'l', 'l', 'o', 0, -- The string!
                          op('push', 3), word(Symbols.heap_start + 11 + 4), -- Push the addr of the string
                          op('call', 3), word(Symbols.print)), -- Call print
            expect_output('Hello'))) -- And we printed it?

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah s" Hello" ; blah'),
            given_stack{ 100 }),
        all(expect_stack{ 100, Symbols.heap_start + 11 + 4 },
            expect_memory(Symbols.heap_start + 11,
                          op('jmpr', 3), word(10), -- Jump past the data, 6 bytes string, 4 bytes the jmpr instruction itself
                          'H', 'e', 'l', 'l', 'o', 0, -- The string!
                          op('push', 3), word(Symbols.heap_start + 11 + 4)), -- Push the addr of the string
            expect_output(''))) -- And we shouldn't print it

--------------------------------------------------

test_fn('handleline',
        all(given_memory(Symbols.line_buf, 's" Hello"'),
            given_stack{ 100 }),
        all(expect_stack{ 100, Symbols.heap_start },
            expect_memory(Symbols.heap_start, 'H', 'e', 'l', 'l', 'o', 0), -- The string!
            expect_word(Symbols.heap_ptr, Symbols.heap_start + 6), -- The start of the string
            expect_output('')))

--------------------------------------------------

-- Indefinite loops
test_fn('handleline',
        given_memory(Symbols.line_buf, ': blah begin ." foo" again ;'), -- Everyone's first basic program...
        expect_memory(Symbols.heap_start + 11,
                      op('jmpr', 3), word(8), -- The jmpr for the string
                      'f', 'o', 'o', 0, -- The string itself
                      op('push', 3), word(Symbols.heap_start + 11 + 4), -- The push for the string addr
                      op('call', 3), word(Symbols.print), -- Call to print the string
                      op('jmpr', 3), word(-16))) -- Jump back 16 bytes to the begin

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah 0 begin dup . 1 + dup 4 - if else exit then again ; blah'),
            given_stack{ 100 }),
        all(expect_output('0123')))

test_fn('handleline',
        all(given_memory(Symbols.line_buf, ': blah 0 begin dup . 1 + dup 5 = until ; blah'),
            given_stack{ 100 }),
        all(expect_output('01234')))

test_fn('handleline',
        given_memory(Symbols.line_buf, ': blah 0 begin dup 5 < while dup . 1 + repeat ; blah'),
        all(expect_memory(Symbols.heap_start + 11,
                          inst('push', 0),
                          call_inst('w_dup'),
                          inst('push', 5),
                          call_inst('w_lt'),
                          inst('brz', 24), -- 4-instr loop body + repeat + brz itself
                          call_inst('w_dup'),
                          call_inst('itoa'),
                          inst('push', 1),
                          call_inst('w_add'),
                          inst('jmpr', -32),
                          op('ret')
            ),
            expect_output('01234')
        )
)

--------------------------------------------------

print('Text ends at: ' .. Symbols.line_buf)
print('Bytes available: ' .. 131072 - Symbols.heap_start)
print('Code size: ' .. Symbols.line_buf - 0x400)

-- todo: dotquote in compilation mode
