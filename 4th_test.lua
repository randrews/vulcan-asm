package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')

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

function expect_stack(expected)
    return function(actual) assert(array_eq(expected, actual)) end
end

function expect_output(expected)
    return function(_s, actual) assert(expected == actual, string.format('%q != %q', expected, actual)) end
end

function expect_memory(start, ...)
    local mem = { ... }
    return function(_s, _o, cpu)
        for i, b in ipairs(mem) do
            local actual = cpu:peek(start + i - 1)
            assert(actual == b, string.format('%d != %d', b, actual))
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
        given_stack{ Symbols.dictionary },
        expect_stack{ Symbols.dictionary + 7 })

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

--------------------------------------------------

test_fn('word_char',
        given_stack{ 68 },
        expect_stack{ 1 })

test_fn('word_char',
        given_stack{ 9 },
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 10 },
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 13 },
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 32 },
        expect_stack{ 0 })

test_fn('word_char',
        given_stack{ 0 },
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
            expect_stack{ }))

test_fn('itoa',
        given_stack{ 7 },
        all(expect_output('7'),
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
            expect_output("You called foo\n")))

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

-- Multiple words, leading and trailing space...
test_fn('handleline',
        all(given_memory(Symbols.line_buf, '  \n\t\t155 10 20 + 34 * .   '),
            given_stack{ }),
        all(expect_stack{ 155 },
            expect_output("1020")))
