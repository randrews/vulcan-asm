package.cpath = package.cpath .. ';./cvemu/?.so'
lfs = require('lfs')
--CPU = require('libvlua')
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')
Opcodes = require('util.opcodes')

Symbols = nil
TIB = 80000 -- Just a convenient place to stick a terminal input buffer for tests. Could be any number.

lfs.chdir('4th')

function init_cpu()
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.lines('4th.asm')
    Symbols = Loader.asm(cpu, iterator)

    return cpu
end

function call(cpu, symbol)
    cpu:push_call(Symbols.stop)
    cpu:set_pc(Symbols[symbol])
    cpu:run()
end

function test_fn(name, setup, check)
    local cpu = init_cpu()
    setup(cpu)
    call(cpu, name)
    local st = { cpu:stack() }
    local rst = { cpu:r_stack() }
    check(st, get_output(cpu), cpu, rst)
end

function get_output(cpu)
    local start = 0x10000
    local len = cpu:peek24(Symbols.emit_cursor)
    local str = ''
    for a = start, len+start-1 do
        str = str .. string.char(cpu:peek(a))
    end
    return str
end

function array_eq(a1, a2)
    local eq = true
    for i, n in ipairs(a1) do
        if n ~= a2[i] then eq = false end
    end
    if #a1 ~= #a2 then eq = false end

    if eq then return true end

    local lt = ''
    for i, n in ipairs(a1) do
        lt = lt .. tostring(n)
    end

    local rt = ''
    for i, n in ipairs(a2) do
        rt = rt .. tostring(n)
    end

    error(string.format('Arrays not equal!\nlt: { %s }\nrt: { %s }', lt, rt))
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

function expect_r_stack(expected)
    return function(_st, _out, _cpu, actual) assert(array_eq(expected, actual)) end
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
            assert(actual == b, string.format('0x%x: exp %d, act %d', start + i - 1, b, actual))
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

function expect_heap_advance(n)
    return function(_s, _o, cpu)
        local expected = heap(0) + n
        local actual = cpu:peek24(Symbols.heap)
        assert(actual == expected, string.format('heap should advance %d, actual %d', n, actual - heap(0)))
    end
end

function expect_cursor(n)
    return function(_s, _o, cpu)
        local expected = TIB + n
        local actual = cpu:peek24(Symbols.cursor)
        assert(actual == expected, string.format('cursor should advance %d, actual %d', n, actual - TIB))
    end
end

function expect_4th_rstack(stack)
    local words = {}
    for _, v in ipairs(stack) do table.insert(words, word(v)) end
    return all(
        expect_memory(Symbols.r_stack, table.unpack(words)),
        expect_word(Symbols.r_stack_ptr, Symbols.r_stack + #stack * 3))
end

function dump_memory(addr, len)
    return function(_s, _o, cpu)
        for a = addr, addr + len do
            local b = cpu:peek(a)
            local c = string.char(b)
            local op = Opcodes.mnemonic_for(math.floor(b / 4))
            local args = b & 3
            if b < 32 then c = '' end
            print(string.format('[%d]\t%xh:\t%xh\t(%d)\t%q\t%q/%d', a - addr, a, b, b, c, op, args))
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
    test_fn('eval', all(given_stack{TIB}, given_memory(TIB, line)), all(...))
end

function test_lines(lines, ...)
    local cpu = init_cpu()

    for _, line in ipairs(lines) do
        cpu:push_data(TIB)
        local contents = { line:byte(1, #line) }
        table.insert(contents, 0)
        for i, b in ipairs(contents) do cpu:poke(TIB + i - 1, b) end
        call(cpu, 'eval')
    end

    local st = {cpu:stack()}
    local rst = {cpu:r_stack()}
    local check = all(...)
    check(st, get_output(cpu), cpu, rst)
end

PRELUDE = 34 -- How many bytes the prelude adds to the heap
function test_prelude_line(line, ...)
    -- local prelude1 = ": cont ' $ jmp #asm ; immediate"
    local prelude1 = 'create :: ] create continue ] ['
    local prelude2 = ':: ;; postpone exit continue [ [ immediate'
    test_lines({ prelude1, prelude2, line }, ...)
end

function heap(offset)
    return Symbols.heap_start + offset
end

function dump_symbols()
    reverse = {}
    addrs = {}
    for sym, addr in pairs(Symbols) do reverse[addr] = sym; table.insert(addrs, addr) end
    table.sort(addrs)
    for _, addr in ipairs(addrs) do
        print(string.format('0x%x\t%s', addr, reverse[addr]))
    end
end

--------------------------------------------------

test_fn('dupnz',
        given_stack{ 3 },
        expect_stack{ 3, 3 })

test_fn('dupnz', 
        given_stack{ 0 },
        expect_stack{ 0 })

--------------------------------------------------

test_line('10 ?dup', expect_stack{10, 10})
test_line('0 ?dup', expect_stack{0})

--------------------------------------------------

test_line('10', expect_stack{10})
test_line('10 20 30',
          expect_stack{10, 20, 30},
          expect_r_stack{})

--------------------------------------------------

-- Evaluating gibberish
test_line('notaword', expect_output('Not a word: notaword\n'))

--------------------------------------------------

test_line('create blah',
          expect_word(Symbols.heap, heap(11)), -- Heap ptr is advanced by the entry length
          expect_memory(heap(0), 'blah\0'), -- New dict entry has the name
          expect_word(heap(5), heap(11)), -- Followed by the new heap ptr
          expect_word(heap(8), Symbols.dict_start), -- Next ptr is the old dict head
          expect_word(Symbols.dictionary, heap(0))) -- Dict has had the new entry consed on to it

--------------------------------------------------

-- Exiting and entering immediate mode
test_line(']', expect_word(Symbols.handleword_hook, Symbols.compile_handleword))
test_line('] [', all(
              expect_word(Symbols.handleword_hook, Symbols.immediate_handleword),
              expect_r_stack{}))

--------------------------------------------------

-- Compiling a number
test_line('] 122773',
          expect_word(Symbols.heap, heap(4)), -- Advance heap by the length of an instruction
          expect_memory(heap(0), { 3, 149, 223, 1})) -- A push instruction for 122773

-- Compiling a call to a word
test_line('] create',
          expect_word(Symbols.heap, heap(4)), -- Advance heap by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('call') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_create)) -- ...to nova_create

-- Compiling gibberish
test_line('] stillnotaword', expect_output('Not a word: stillnotaword\n'))

--------------------------------------------------

-- -- Continue word (compiles a jmp)
test_line('] continue ]',
          expect_word(Symbols.heap, heap(4)), -- Advance heap by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('jmp') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_close_bracket)) -- ...to nova_close_bracket

-- Continue compile word
test_line('] continue [',
          expect_word(Symbols.heap, heap(4)), -- Advance heap by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('jmp') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_open_bracket)) -- ...to nova_close_bracket

-- Continue gibberish
test_line('] continue supernotword', expect_output('Not a word: supernotword\n'))

-- Implement continue with #asm!
test_lines({ ": cont ' $ jmp #asm ; immediate",
             '] cont ]' },
    expect_memory(heap(11), -- Just skip cont's header
                  inst('call', Symbols.nova_tick), -- Call tick to see what we're continuing to
                  inst('push', Opcodes.opcode_for('jmp')), -- Push a jmp
                  inst('call', Symbols.compile_instruction_arg), -- Compile a jmp to that word
                  op('ret'), -- Return from cont
                  inst('jmp', Symbols.nova_close_bracket))) -- Cont gives us a jmp to `]`

-- Prelude continue with a runtime word
test_lines({ ": cont ' $ jmp #asm ; immediate",
             '] cont print' },
    expect_memory(heap(11 + 13), -- Just skip cont's header and impl
                  inst('jmp', Symbols.print))) -- Cont gives us a jmp to `print`

--------------------------------------------------

-- Prelude colon definition
test_lines({ ": cont ' $ jmp #asm ; immediate",
             'create :: ] create cont ] [' },
    expect_memory(heap(24), '::\0'), -- New dict entry has the name (24 bytes for cont)
    expect_word(heap(24 + 3), heap(24 + 9)), -- Followed by the ptr to the fn
    expect_memory(heap(24 + 9), inst('call', Symbols.nova_create)), -- Which is a call to create...
    expect_memory(heap(24 + 13), inst('jmp', Symbols.nova_close_bracket)), -- Followed by jmping to close_bracket
    expect_word(Symbols.handleword_hook, Symbols.immediate_handleword), -- And now we're back in immediate mode
    expect_r_stack{}) -- And haven't leaked a stack frame

-- Using prelude colon
test_lines({ "create cont ] ' $ jmp #asm ; immediate",
             'create :: ] create cont ] [ :: foo 35' },
    expect_memory(heap(24 + 17), 'foo\0'), -- A new entry for foo
   expect_word(heap(24 + 21), heap(24 + 27)), -- Defn ptr is the new heap
   expect_memory(heap(24 + 27), inst('push', 35)), -- fn begins with pushing a 35
   expect_word(Symbols.handleword_hook, Symbols.compile_handleword), -- We're still in compile mode
    expect_r_stack{}) -- And haven't leaked a stack frame

--------------------------------------------------

-- Postponing normal words
test_line('] postpone create',
          expect_memory(heap(0), inst('push', Symbols.nova_create)),
          expect_memory(heap(4), inst('push', Opcodes.opcode_for('call'))),
          expect_memory(heap(8), inst('call', Symbols.compile_instruction_arg)))

-- Postponing compile words
test_line('] postpone [', expect_memory(heap(0), inst('call', Symbols.nova_open_bracket)))

-- Postponing gibberish
test_line('] postpone reallynotaword', expect_output('Not a word: reallynotaword\n'))

--------------------------------------------------

-- Compile a ret
test_line('] exit', expect_memory(heap(0), { op('ret') }))

--------------------------------------------------
--- Prelude stuff: -------------------------------
--------------------------------------------------

-- This was a fun intellectual exercise and makes a nice torture test for NovaForth, but it violates the
-- "optimize for understandability" principle and so colon and semicolon are now both written in asm. The
-- tests remain here because they're good, very exhaustive, tests.

-- Prelude semicolon definition
test_line('create :: ] create continue ] [ :: ;; postpone exit continue [ [ immediate',
          expect_memory(heap(17), ';', ';', 0), -- A new entry for semicolon
          expect_memory(heap(26),
                        inst('call', Symbols.nova_exit), -- Which compiles a ret
                        inst('jmp', Symbols.nova_open_bracket)), -- And then returns to immediate mode
          expect_word(Symbols.compile_dictionary, heap(17)), -- Semicolon is in the compile dict
          expect_word(heap(23), Symbols.compile_dict_start), -- Semicolon points at old compile_dict head
          expect_word(Symbols.handleword_hook, Symbols.immediate_handleword)) -- In immediate mode again

-- Using prelude semicolon
test_prelude_line('] ;;',
                  expect_memory(heap(PRELUDE), op('ret')), -- Compiled our ret
                  expect_word(Symbols.handleword_hook, Symbols.immediate_handleword), -- In immediate mode again
                  expect_r_stack{}) -- And haven't leaked a stack frame

-- Defining a word and calling it, with the prelude
test_prelude_line(':: fives 5 5 5 ;; fives',
                  expect_stack{ 5, 5, 5 },
                  expect_r_stack{})

-- Testing create / does> without compile-time behavior, with the prelude
test_prelude_line(':: blah create does> 2 3 ;; blah fnord fnord',
                  -- We're creating a new word fnord and then running it, the new word gets passed the address
                  -- of its heap stuff and then pushes a couple numbers. Its heap area is the heap ptr when we
                  -- called does>, so, PRELUDE + 11 (blah's entry) + 21 (blah's body, part of which is fnord's) + 12 (fnord's entry)
                  expect_stack{ heap(PRELUDE + 11 + 22 + 12), 2, 3 }, -- 
                  -- Body of blah:
                  expect_memory(heap(PRELUDE + 11),
                                inst('call', Symbols.nova_create), -- After blah's header, we have a call to create
                                inst('push', heap(PRELUDE + 11 + 13)), -- push the address of after the does>
                                inst('jmp', Symbols.does_at_runtime), -- And a call to does@runtime, to start compiling it
                                op('ret'), -- blah's return
                                inst('push', 2), -- The runtime behavior of fnord (the "mold"):
                                inst('push', 3),
                                op('ret')), -- fnord's runtime return
                  -- Header of fnord:
                  expect_memory(heap(PRELUDE + 11 + 22),
                                'f', 'n', 'o', 'r', 'd', 0, -- the new word's header
                                word(heap(PRELUDE + 11 + 22 + 12)), -- pointer to the trampoline
                                -- and pointer to the next dictionary entry. By this point the front of the
                                -- dictionary is blah, which has its entry at heap(PRELUDE), right after the prelude:
                                word(heap(PRELUDE))),
                  -- Body (trampoline) of fnord:
                  expect_memory(heap(PRELUDE + 11 + 22 + 12),
                                inst('push', heap(PRELUDE + 11 + 22 + 12)), -- Push the old value, which was right
                                -- after the header (because of the null compile-time behavior)
                                inst('jmp', heap(PRELUDE + 11 + 13)))) -- jmp to the runtime behavior, after the does> call

-- Testing create / does> when there's compile-time behavior, with the prelude
test_prelude_line(':: blah create 15 , does> 3 ;; blah fnord fnord',
                  -- We're creating a new word fnord and then running it, the new word gets passed the address
                  -- of its heap stuff and then pushes a three. Its heap area is the heap ptr when we
                  -- called does>, so, PRELUDE + 11 (blah's entry) + 26 (blah's body, part of which is fnord's) + 12 (fnord's entry)
                  expect_stack{ heap(PRELUDE + 11 + 26 + 12), 3 },
                  -- Body of blah:
                  expect_memory(heap(PRELUDE + 11),
                        inst('call', Symbols.nova_create), -- After blah's header, we have a call to create
                        inst('push', 15),
                        inst('call', Symbols.nova_comma),
                        inst('push', heap(PRELUDE + 11 + 21)), -- push the address of after the does>
                        inst('jmp', Symbols.does_at_runtime), -- And a call to does@runtime, to start compiling it
                        op('ret'), -- blah's return
                        inst('push', 3), -- After the does>; the runtime behavior of fnord (the "mold"):
                        op('ret')), -- fnord's runtime return
                  -- Header of fnord:
                  expect_memory(heap(PRELUDE + 11 + 26),
                                'f', 'n', 'o', 'r', 'd', 0, -- the new word's header
                                word(heap(PRELUDE + 11 + 26 + 15)), -- pointer to the trampoline
                                -- and pointer to the next dictionary entry. By this point the front of the
                                -- dictionary is blah, which has its entry right after the prelude at heap(PRELUDE):
                                word(heap(PRELUDE))),
                  expect_memory(heap(PRELUDE + 11 + 26 + 12),
                                word(15)), -- The compile time behavior compiled this 15
                  -- Body (trampoline) of fnord:
                  expect_memory(heap(PRELUDE + 11 + 26 + 15),
                                inst('push', heap(PRELUDE + 11 + 26 + 12)), -- Push the old value, which was right
                                -- after the header, the 15 we compiled
                                inst('jmp', heap(PRELUDE + 11 + 21)))) -- jmp to the runtime behavior, after the does> call

--------------------------------------------------

-- Defining a word and calling it, with the normal colon / semicolon words
test_line(': fives 5 5 5 ; fives',
          expect_stack{ 5, 5, 5 },
          expect_r_stack{})

--------------------------------------------------

-- Basic use of asm
test_line('create execute $ jmp asm',
          expect_heap_advance(15),
          expect_word(heap(8), heap(14)),
          expect_memory(heap(14), op('jmp')))

-- Asm with args
test_line('45 $ push #asm',
          expect_memory(heap(0), inst('push', 45)),
          expect_word(Symbols.heap, heap(4)))

--------------------------------------------------

-- Compile-mode asm
test_line('] $ jmp asm',
          expect_heap_advance(8),
          expect_memory(heap(0),
                        inst('push', Opcodes.opcode_for('jmp')),
                        inst('call', Symbols.compile_instruction)))

-- Compile-mode asm with args
test_line('] 45 $ xor #asm',
          expect_heap_advance(12),
          expect_memory(heap(0),
                        inst('push', 45),
                        inst('push', Opcodes.opcode_for('xor'),
                        inst('call', Symbols.compile_instruction_arg))))

test_line(': foo 34 $ xor #asm ; immediate ] foo',
          expect_memory(heap(0),
                        -- foo's header
                        'f', 'o', 'o', 0, word(heap(10)), word(Symbols.compile_dict_start),
                        inst('push', 34), -- Push an arg
                        inst('push', Opcodes.opcode_for('xor')), -- Push an opcode
                        inst('call', Symbols.compile_instruction_arg), -- Compile that with an arg
                        op('ret'), -- Return from foo
                        -- Foo is now an immediate word, and when we call it in compile mode...
                        inst('xor', 34))) -- It compiles a xor 34

test_line('$ xor 3', expect_stack{9, 3})
test_line('$ blah 3', expect_stack{}, expect_output('Invalid mnemonic: blah\n'))

test_line('] $ xor 3',
          expect_stack{},
          expect_memory(heap(0),
                        inst('push', 9),
                        inst('push', 3)),
          expect_heap_advance(8))

test_line('] $ blah 3',
          expect_stack{},
          expect_output('Invalid mnemonic: blah\n'),
          expect_heap_advance(0)) -- It hits quit right after the error

--------------------------------------------------

-- Comma compile a number
test_line('1234 ,',
          expect_word(heap(0), 1234),
          expect_heap_advance(3))

--------------------------------------------------

-- Tick a word
test_line("' print", expect_stack{ Symbols.print })

-- Bracket-tick a word
test_line("] ['] print",
          expect_memory(heap(0), inst('push', Symbols.print)),
          expect_heap_advance(4))

-- Tick gibberish
test_line("' bananas",
          expect_stack{},
          expect_r_stack{},
          expect_output('Not a word: bananas\n'))

-- Bracket-tick gibberish
test_line("] ['] penguin",
          expect_stack{},
          expect_r_stack{},
          expect_output('Not a word: penguin\n'))

-- Tick a compile word
test_line("' [", expect_stack{ Symbols.nova_open_bracket })

-- Bracket-tick a compile word
test_line("] ['] does>",
          expect_memory(heap(0), inst('push', Symbols.does_word)),
          expect_heap_advance(4))

--------------------------------------------------

-- Fetch the pad address
test_line('  pad  ', expect_stack{ Symbols.pad })

-- Read a word to the pad
test_line('word mango',
          expect_stack{ Symbols.pad },
          expect_memory(Symbols.pad, 'm', 'a', 'n', 'g', 'o', 0))

--------------------------------------------------

-- Literal, compiles a push instruction
test_line('1234 ] literal',
          expect_stack{},
          expect_memory(heap(0), inst('push', 1234)),
          expect_heap_advance(4))

--------------------------------------------------

-- Paren comments
test_line('1 2 ( 3 4 5 ) 6', expect_stack{1, 2, 6})

-- Nested paren comments
test_line('1 2 ( ( 3 4 ) 5 6', expect_stack{1, 2})

-- Compiled paren comments
test_line('] 1 2 ( 3 4 5 ) 6', expect_heap_advance(12))

-- Compiled nested paren comments
test_line('] 1 2 ( ( 3 4 ) 5 6', expect_heap_advance(8))

-- Backslash comments
test_lines({ '1 2 \\ 3 4', '5 6' }, expect_stack{1, 2, 5, 6})

-- Compiled backslash comments
test_lines({ '] 1 2 \\ 3 4', '5 6' }, expect_heap_advance(16))

--------------------------------------------------

-- Parse numbers from words
test_line('number 17', expect_stack{ 17, 1 })
test_line('number blah', expect_stack{ 0 })
test_line('number -23', expect_stack{ (-23 & 0xffffff), 1 })

-- Parse hex numbers from words
test_line('hex number a4', expect_stack{ 164, 1 })
test_line('hex number blah', expect_stack{ 0 })

-- Switch between hex and dec
test_line('hex number a4 dec number 23', expect_stack{ 164, 1, 23, 1 })
test_line('hex a4 dec 23', expect_stack{ 164, 23 })

--------------------------------------------------

-- Output in hex and dec
test_line('hex a4 . dec 23 .', expect_output('a423')) -- Yeah, no separator
test_line('hex a4 dec .', expect_output('164'))
test_line('dec 525 hex .', expect_output('20d'))
test_line('-15 .', expect_output('-15'))

--------------------------------------------------

-- Compiling strings to the heap
test_line('s" foo"',
          expect_stack{heap(0)},
          expect_cursor(7),
          expect_memory(heap(0), 'f', 'o', 'o', 0),
          expect_heap_advance(4))

-- Compiling empty string
test_line('s" "',
          expect_stack{heap(0)},
          expect_memory(heap(0), 0),
          expect_heap_advance(1))

-- Unterminated string
test_line('s" foo',
          expect_stack{},
          expect_heap_advance(0),
          expect_cursor(6),
          expect_output('Unclosed string'))

-- Compile move squote
test_line('] s" blah"',
          expect_memory(heap(0),
                        inst('jmpr', 9), -- length of the jmpr itself + 'blah\0'
                        'b', 'l', 'a', 'h', 0, -- The actual string
                        inst('push', heap(4))), -- Push the addr of the string
          expect_heap_advance(13))

-- Compile mode unterminated string
test_line('] s" foo',
          expect_heap_advance(0),
          expect_output('Unclosed string'))

--------------------------------------------------

-- Basic output
test_line('." foo"',
          expect_stack{}, expect_heap_advance(0),
          expect_output('foo'))

-- Compile output
test_line('] ." foo"',
          expect_heap_advance(16),
          expect_memory(heap(0),
                        inst('jmpr', 8),
                        'f', 'o', 'o', 0,
                        inst('push', heap(4)),
                        inst('call', Symbols.print)))

-- Unterminated output
test_line('." foo',
          expect_stack{}, expect_heap_advance(0),
          expect_output('Unclosed string'))

-- Compile output
test_line('] ." foo',
          expect_heap_advance(0),
          expect_output('Unclosed string'))

--------------------------------------------------

-- Test print fn
test_line('s" foo" print',
          expect_cursor(13),
          expect_heap_advance(4),
          expect_output('foo'))

--------------------------------------------------

-- Test compare
test_line('s" foo" s" bar" compare', expect_stack{0})
test_line('s" foo" s" foo" compare', expect_stack{1})
test_line('s" foo" ?dup compare', expect_stack{1}) -- There's no simple dup...
test_line('s" foo" s" foo234" compare', expect_stack{0})
test_line('s" foo123" s" foo" compare', expect_stack{0})

--------------------------------------------------

-- Print the stack
test_line('10 20 30 .s',
          expect_stack{ 10, 20, 30 },
          expect_output('<< 10 20 30 >>'))

-- Print the stack in hex
test_line('10 20 30 hex .s',
          expect_stack{ 10, 20, 30 },
          expect_output('<< a 14 1e >>'))

-- Print nothing
test_line('.s',
          expect_stack{},
          expect_output('<< >>'))

--------------------------------------------------

-- pushr, peekr
test_line('3 >r r@',
          expect_stack{3},
          expect_4th_rstack{3})

-- popr
test_line('3 >r 5 r>',
          expect_stack{5, 3},
          expect_4th_rstack{})

-- rpick
test_line('10 20 30 >r >r >r 2 rpick',
          expect_stack{30},
          expect_4th_rstack{30, 20, 10})

--------------------------------------------------

-- Heap ptr stuff
test_line('&heap', expect_stack{Symbols.heap})
test_line('here', expect_stack{heap(0)})

--------------------------------------------------

-- To-asm
test_line('$ brnz >asm',
          expect_stack{},
          expect_heap_advance(4),
          expect_memory(heap(0), inst('brnz', 0)),
          expect_4th_rstack{heap(1)})

-- Resolve
test_line('$ brnz >asm resolve',
          expect_heap_advance(4),
          expect_4th_rstack{},
          expect_memory(heap(0),
                        inst('brnz', 4))) -- brnz 12 ahead

--------------------------------------------------

-- An 'if' implementation
test_line(': if $ brz >asm ; immediate ] if',
          expect_stack{},
          expect_heap_advance(9 + 9 + 4), -- Entry 'if', body of 'if' (push, call, ret), and the brnz we just compiled
          expect_4th_rstack{heap(9 + 9 + 1)}, -- Address of said brnz' arg
          expect_memory(heap(9), -- Skipping if's entry
                        inst('push', Opcodes.opcode_for('brz')), inst('call', Symbols.nova_asm_to), op('ret'), -- if's body
                        inst('brz', 0))) -- The unresolved brnz 'if' compiled

-- If / then
test_lines({ ': if $ brz >asm ; immediate',
             ': then resolve ; immediate',
             ': foo if 2 then ;',
             '1 foo 10 0 foo' },
    expect_stack{2, 10})

-- If / else / then
test_lines({ ': if $ brz >asm ; immediate',
             ': then resolve ; immediate',
             ': else r> $ jmpr >asm >r resolve ; immediate',
             ': foo if 2 else 3 then ;',
             '1 foo 10 0 foo' },
    expect_stack{2, 10, 3})

--------------------------------------------------

-- Testing some simple, single-opcode words that'll go in the prelude
test_lines({ 'create - $ sub asm ] ;',
             'create dup $ dup asm ] ;',
             '5 dup 3 -' },
    expect_stack{5, 2})

-- Begin / until loops
test_lines({ 'create - $ sub asm ] ;', -- Gotta subtract
             'create dup $ dup asm ] ;', -- Also gotta dup
             'create not $ not asm ] ;', -- until needs us to invert the condition
             ': begin here >r ; immediate', -- Begin just marks a point in the program we'll brnz back to
             -- Here's the fun part.
             -- Pull the address stored by 'begin' off the rstack and subtract `here` from it
             -- Then compile a brz to that address
             ': until r> here - $ brz #asm ; immediate',
             -- This ought to loop from 5..0, leaving each one on the stack
             ': foo 5 begin dup 1 - dup not until ; foo' },
    expect_stack{5, 4, 3, 2, 1, 0})

-- do / loop counted loops
test_lines({ 'create 1+ 1 $ add #asm ] ;',
             'create - $ sub asm ] ;',
             'create dup $ dup asm ] ;',
             'create swap $ swap asm ] ;',
             'create pop $ pop asm ] ;',
             'create < $ lt asm ] ;',
             ': do $ swap asm postpone >r postpone >r here >r ; immediate',
             ': _loop_test r> 1+ dup r@ < swap >r ;', -- pull off and inc the cntr, dup, peek at the limit, compare them, put the new cntr back
             ': unloop r> r> pop pop ;',
             ': loop postpone _loop_test r> here - $ brnz #asm postpone unloop ; immediate',
             ': foo 3 0 do 33 loop ; foo' },
    expect_stack{33, 33, 33})

--------------------------------------------------

-- Testing quit as called by an error
test_line('2 3 : foo nooope ; 7',
          expect_heap_advance(10), -- It does the header but that's it
          expect_output('Not a word: nooope\n'), -- Spits out an error message
          expect_word(Symbols.handleword_hook, Symbols.immediate_handleword), -- Back in immediate mode
          expect_stack{2, 3}) -- Doesn't clobber the stack though

-- Testing quit as called manually
test_lines({ ': low 5 quit 6 ;',
             ': med 3 low 4 ;',
             ': high 1 med 2 ;',
             'high' },
    expect_output(''), -- This isn't an error, we just quit
    expect_stack{1, 3, 5}) -- We quit partway through 'low', so skip all the frames above that

--------------------------------------------------

--[==[
    TODOs
    X Other loops and things
    X quit, and errors calling it

    Later TODOs
    - Remove 'continue', we can implement it ourselves easily
    - Prelude of simple words
    - Rewrite / macro-ize string fns
--]==]

--------------------------------------------------

print('Bytes available: ' .. 131072 - heap(0))
print('Text size: ' .. Symbols.data_start - 0x400)
print('Including dictionaries: ' .. Symbols.heap - 0x400)
