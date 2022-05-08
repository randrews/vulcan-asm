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

function call(cpu, symbol)
    cpu:push_call(Symbols.stop)
    cpu:set_pc(Symbols[symbol])
    cpu:run()
end

function test_fn(name, setup, check)
    local cpu, output = init_cpu()
    setup(cpu)
    call(cpu, name)
    local st = { cpu:stack() }
    local rst = { cpu:r_stack() }
    check(st, output.contents, cpu, rst)
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
    test_fn('eval', all(given_stack{Symbols.tib}, given_memory(Symbols.tib, line)), all(...))
end

function test_prelude_line(line, ...)
    test_fn('eval', all(run_prelude, given_stack{Symbols.tib}, given_memory(Symbols.tib, line)), all(...))
end

PRELUDE = 32 -- How many bytes the prelude adds to the heap
function run_prelude(cpu)
    local prelude = 'create : ] create continue ] [ : ; postpone exit continue [ [ immediate'
    local setup = all(given_stack{Symbols.tib}, given_memory(Symbols.tib, prelude))
    setup(cpu)
    call(cpu, 'eval')
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

test_line('10', expect_stack{10})
test_line('10 20 30',
          expect_stack{10, 20, 30},
          expect_r_stack{})

--------------------------------------------------

-- Evaluating gibberish
test_line('notaword', expect_output('Not a word: notaword\n'))

--------------------------------------------------

test_line('create blah',
          expect_word(Symbols.heap_ptr, heap(11)), -- Heap ptr is advanced by the entry length
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
          expect_word(Symbols.heap_ptr, heap(4)), -- Advance heap_ptr by the length of an instruction
          expect_memory(heap(0), { 3, 149, 223, 1})) -- A push instruction for 122773

-- Compiling a call to a word
test_line('] create',
          expect_word(Symbols.heap_ptr, heap(4)), -- Advance heap_ptr by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('call') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_create)) -- ...to nova_create

-- Compiling gibberish
test_line('] stillnotaword', expect_output('Not a word: stillnotaword\n'))

--------------------------------------------------

-- Continue word (compiles a jmp)
test_line('] continue ]',
          expect_word(Symbols.heap_ptr, heap(4)), -- Advance heap_ptr by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('jmp') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_close_bracket)) -- ...to nova_close_bracket

-- Continue compile word
test_line('] continue [',
          expect_word(Symbols.heap_ptr, heap(4)), -- Advance heap_ptr by the length of an instruction
          expect_memory(heap(0), { Opcodes.opcode_for('jmp') * 4 + 3 }), -- A call instruction
          expect_word(heap(1), Symbols.nova_open_bracket)) -- ...to nova_close_bracket

-- Continue gibberish
test_line('] continue supernotword', expect_output('Not a word: supernotword\n'))

--------------------------------------------------

-- Prelude colon definition
test_line('create : ] create continue ] [',
          expect_memory(heap(0), ':\0'), -- New dict entry has the name
          expect_word(heap(2), heap(8)), -- Followed by the ptr to the fn
          expect_memory(heap(8), inst('call', Symbols.nova_create)), -- Which is a call to create...
          expect_memory(heap(12), inst('jmp', Symbols.nova_close_bracket)), -- Followed by jmping to close_bracket
          expect_word(Symbols.handleword_hook, Symbols.immediate_handleword), -- And now we're back in immediate mode
          expect_r_stack{}) -- And haven't leaked a stack frame

-- Using prelude colon
test_line('create : ] create continue ] [ : foo 35',
          expect_memory(heap(16), 'foo\0'), -- A new entry for foo
          expect_word(heap(20), heap(26)), -- Defn ptr is the new heap
          expect_memory(heap(26), inst('push', 35)), -- fn begins with pushing a 35
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

-- Prelude semicolon definition
test_line('create : ] create continue ] [ : ; postpone exit continue [ [ immediate',
          expect_memory(heap(16), ';\0'), -- A new entry for semicolon
          expect_memory(heap(24), inst('call', Symbols.nova_exit)), -- Which compiles a ret
          expect_memory(heap(28), inst('jmp', Symbols.nova_open_bracket)), -- And then returns to immediate mode
          expect_word(Symbols.compile_dictionary, heap(16)), -- Semicolon is in the compile dict
          expect_word(heap(21), Symbols.compile_dict_start), -- Semicolon points at old compile_dict head
          expect_word(Symbols.handleword_hook, Symbols.immediate_handleword)) -- In immediate mode again

-- Using prelude semicolon
test_prelude_line('] ;',
                  expect_memory(heap(PRELUDE), op('ret')), -- Compiled our ret
                  expect_word(Symbols.handleword_hook, Symbols.immediate_handleword), -- In immediate mode again
                  expect_r_stack{}) -- And haven't leaked a stack frame

--------------------------------------------------

-- Defining a word and calling it
test_prelude_line(': fives 5 5 5 ; fives',
                  expect_stack{ 5, 5, 5 },
                  expect_r_stack{})

--------------------------------------------------

-- Basic use of asm
test_line('create execute asm jmp',
          expect_word(Symbols.heap_ptr, heap(15)),
          expect_word(heap(8), heap(14)),
          expect_memory(heap(14), op('jmp')))

-- Invalid asm
test_line('asm blah',
          expect_output('Invalid mnemonic: blah\n'),
          expect_r_stack{},
          expect_stack{})

-- Asm with args
test_line('45 #asm push',
          expect_memory(heap(0), inst('push', 45)),
          expect_word(Symbols.heap_ptr, heap(4)))

--------------------------------------------------

-- Testing create / does> without compile-time behavior
test_prelude_line(': blah create does> 2 3 ; blah fnord fnord',
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

-- Testing create / does> when there's compile-time behavior
test_prelude_line(': blah create 15 , does> 3 ; blah fnord fnord',
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

print('Bytes available: ' .. 131072 - heap(0))
print('Text size: ' .. Symbols.data_start - 0x400)
