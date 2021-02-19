vulcan = require('vasm.vasm')

statement = vulcan.statement

-- # Assembly parsing tests

-- ## Utility functions

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

-- A debugging aid to pretty-print our internal representation of an instruction
function print_line(line, recur)
    local elements = {}
    local keys = {}

    for k, _ in pairs(line) do
        table.insert(keys, k)
    end

    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = line[k]
        if type(v) == 'table' then
            table.insert(elements, k .. '=' .. print_line(v, true))
        else
            table.insert(elements, k .. '=' .. string.format('%q', v))
        end
    end

    local str = '{' .. table.concat(elements, ' ') .. '}'
    if recur then
        return str
    else
        print(str)
    end
end

-- A wrapper for testing that ASTs are equal:
function test(line, ast)
    local actual_ast = prettify(statement:match(line))
    if actual_ast == ast then return true
    else
        print('FAIL: [[' .. line .. ']]\nExpected: ' .. ast .. '\n  Actual: ' .. actual_ast)
        return false
    end
end

-- ## Test cases

-- Just an opcode
test([[add]], [[("opcode" "add")]])

-- Leading spaces
test([[   add]], [[("opcode" "add")]])

-- Opcode with an argument
test([[add 43]], [[("opcode" "add" "argument" ("expr" ("term" 43)))]])

-- Another with an argument
test([[load24 43]], [[("opcode" "load24" "argument" ("expr" ("term" 43)))]])

-- Label, opcode, argument
test([[foo: add 43]], [[("label" "foo" "opcode" "add" "argument" ("expr" ("term" 43)))]])

-- Label, opcode
test([[foo: add]], [[("label" "foo" "opcode" "add")]])

-- Hex argument
test([[add 0x10]], [[("opcode" "add" "argument" ("expr" ("term" 16)))]])

-- Binary argument
test([[add 0b1010]], [[("opcode" "add" "argument" ("expr" ("term" 10)))]])

-- Decimal argument
test([[add 23]], [[("opcode" "add" "argument" ("expr" ("term" 23)))]])

-- Decimal zero argument
test([[add 0]], [[("opcode" "add" "argument" ("expr" ("term" 0)))]])

-- Strings
test([[  .db "hello"]], [[("directive" ".db" "argument" ("string" ("h" "e" "l" "l" "o")))]])

-- Strings with escapes
test([[  .db "hello\""]], [[("directive" ".db" "argument" ("string" ("h" "e" "l" "l" "o" "\\\"")))]])

-- Expressions
test([[add 43+17]], [[("opcode" "add" "argument" ("expr" ("term" 43) "+" ("term" 17)))]])

-- Multiple terms
test([[add 43+17 - 3]], [[("opcode" "add" "argument" ("expr" ("term" 43) "+" ("term" 17) "-" ("term" 3)))]])

-- Multiplication
test([[add 2*14-3]], [[("opcode" "add" "argument" ("expr" ("term" 2 "*" 14) "-" ("term" 3)))]])

-- Sub-expressions
test([[add 2*(14-3)]], [[("opcode" "add" "argument" ("expr" ("term" 2 "*" ("expr" ("term" 14) "-" ("term" 3)))))]])

-- Labels in expressions
test([[jmp start + 2]], [[("opcode" "jmp" "argument" ("expr" ("term" "start") "+" ("term" 2)))]])

-- Relative labels in expressions
test([[brz @loop]], [[("opcode" "brz" "argument" ("expr" ("term" "@loop")))]])

-- Comments
test([[hlt ; whatever]], [[("opcode" "hlt")]])

-- Just a comment
test([[; whatever]], [[()]])

-- Just whitespace
test([[     ]], [[()]])

-- Blank line
test([[]], [[()]])

-- # Assembler first-pass tests

parse_assembly = vulcan.parse_assembly

-- ## Utility functions

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

-- Wrapper for testing with an iterator
function test_parse(asm, lines)
    local actual_lines = prettify(parse_assembly(iterator(asm)))

    if actual_lines == lines then return true
    else
        print('FAIL:\nExpected: ' .. lines .. '\n  Actual: ' .. actual_lines)
        return false
    end
end

-- Test that an error actually occurs
function test_parse_error(asm, message)
    local status, actual_err = pcall(function()
            return prettify(parse_assembly(iterator(asm)))
    end)

    if status then
        print('FAIL:\nExpected error \"' .. err .. '\" but nothing was thrown')
        print('Return value: ' .. actual_err)
    else
        local index = actual_err:find(message)
        if not index then
            print('FAIL:\nExpected error to contain: ' .. message .. '\n             Actual error: ' .. actual_err)
            return false
        end
    end
end

-- ## Test cases

-- It should parse simple files
test_parse([[
    ;; With n at top of stack, replaces it with the
    ;; nth triangular series number

triangular:
    dup
    sub 1
    mul
]], [[({label="triangular" line=4} {line=5 opcode="dup"} {argument=("expr" ("term" 1)) line=6 opcode="sub"} {line=7 opcode="mul"})]])

-- It should disallow string arguments except in .db
test_parse_error([[add "hello"]], [[String argument outside .db directive]])

-- It should allow string arguments in .db
test_parse([[.db "hello"]], [[({argument=("string" ("h" "e" "l" "l" "o")) directive=".db" line=1})]])

-- # Expression evaluator tests

evaluate = vulcan.evaluate

-- ## Utility functions

function test_eval(ast, val, symbols, start_address)
    local actual_val = evaluate(ast, symbols or {}, start_address)
    if type(actual_val) == 'table' then
        actual_val = prettify(actual_val)
        val = prettify({ val:byte(1, #val) })
    end

    if actual_val == val then return true
    else
        print('FAIL:\nExpected: ' .. val .. '\n  Actual: ' .. actual_val)
        return false
    end
end

-- ## Test cases

-- Most basic and common case, a number:
test_eval({'expr', {'term', 43}}, 43)

-- Some addition and subtraction
test_eval({'expr', {'term', 10}, '+', {'term', 5}, '-', {'term', 2}}, 13)

-- Multiplication and order of operations
test_eval({'expr', {'term', 2, '*', 14}, '-', {'term', 3}}, 25)

-- Symbol table lookups
test_eval({'expr', {'term', 'start'}, '+', {'term', 2}}, 12, {start=10})

-- Failing symbol table lookup
local success, err = pcall(function()
        evaluate({'expr', {'term', 'start'}, '+', {'term', 2}}, {})
end)
assert(success == false and err:match('Symbol not defined: start'))

-- Relative label lookups
test_eval({'expr', {'term', '@loop'}}, 5, {loop=15}, 10)

-- Failing relative label lookup
local success, err = pcall(function()
        evaluate({'expr', {'term', '@loop'}}, {}, 5, 10)
end)
assert(success == false and err:match('Symbol not defined: loop'))

-- A parsed string
test_eval({'string', {'H', 'e', 'l', 'l', 'o'}}, 'Hello')

-- A parsed string with escapes
test_eval({'string', {'H', 'e', 'l', 'l', 'o', '\\"'}}, 'Hello"')

-- # Second pass tests

solve_equs = vulcan.solve_equs

-- ## Utility functions

function test_equs(asm, symbols)
    local actual_symbols = prettify(solve_equs(parse_assembly(iterator(asm))))

    if actual_symbols == symbols then return true
    else
        print('FAIL:\nExpected: ' .. symbols .. '\n  Actual: ' .. actual_symbols)
        return false
    end
end

-- ## Test cases

-- Simple case
test_equs([[foo: .equ 5]], [[{foo=5}]])

-- One refers to another
test_equs([[
foo: .equ 5
bar: .equ foo+6
]], [[{bar=11 foo=5}]])

-- Fails to resolve symbol:
success, err = pcall(test_equs, [[foo: .equ bar]], '')
assert(success == false and
           err:match('Cannot resolve .equ on line 1:') and
           err:match('Symbol not defined: bar'))

-- Contains a relative address:
success, err = pcall(test_equs, [[foo: .equ @bar]], '')
assert(success == false and
           err:match('Cannot resolve .equ on line 1:') and
           err:match('Cannot resolve relative label'))

-- # Third pass tests

measure_instructions = vulcan.measure_instructions

-- ## Utility functions

function test_measure(asm, lengths)
    local lines = parse_assembly(iterator(asm))
    local symbols = solve_equs(lines)
    measure_instructions(lines, symbols)
    local actual_lengths = prettify(table.map(lines, function(l) return l.length end))

    if actual_lengths == lengths then return true
    else
        print('FAIL:\nExpected: ' .. lengths .. '\n  Actual: ' .. actual_lengths)
        return false
    end
end

-- ## Test cases

-- Some single-byte stuff
test_measure([[
add
jmp
nop
]], [[(1 1 1)]])

-- .db with a number
test_measure([[.db 123]], [[(3)]])

-- .db with a string
test_measure([[.db "potato!"]], [[(7)]])

-- Things that don't output
test_measure([[
.org 123
foo: .equ 234
]], [[(0 0)]])

-- Single-byte args
test_measure([[push 0x23]], [[(2)]])

-- Two-byte args
test_measure([[push 0x1023]], [[(3)]])

-- Three-byte args
test_measure([[push 0xaa1023]], [[(4)]])

-- Args with unknown length
test_measure([[push banana+12]], [[(4)]])

-- Relative label args
test_measure([[brz @loop]], [[(4)]])

-- # Fourth pass tests

place_labels = vulcan.place_labels

-- ## Utility functions

function test_place(asm, addresses, symbols)
    local lines = parse_assembly(iterator(asm))
    local actual_symbols = solve_equs(lines)
    measure_instructions(lines, actual_symbols)
    place_labels(lines, actual_symbols)
    local actual_addresses = prettify(table.map(lines, function(l) return l.address end))

    if addresses and actual_addresses ~= addresses then
        print('FAIL:\nExpected: ' .. addresses .. '\n  Actual: ' .. actual_addresses)
        return false
    end

    if symbols and symbols ~= prettify(actual_symbols) then
        print('FAIL:\nExpected: ' .. symbols .. '\n  Actual: ' .. prettify(actual_symbols))
        return false
    end

    return true
end

-- ## Test cases

-- Simple
test_place([[
add 12
sub
]], [[(0 2)]], [[{$end=2 $start=0}]])

-- With a constant .org
test_place([[
.org 1000
add 12]], [[(1000 1000)]])

-- With a label
test_place([[
start: add
sub]], [[(0 1)]], [[{$end=1 $start=0 start=0}]])

-- With a .org referring to a label
test_place([[
.org 100
jt_start: jmpr
.org jt_start+7
add 7]], [[(100 100 107 107)]], [[{$end=108 $start=100 jt_start=100}]])

-- A .org we can't calculate
success, err = pcall(test_place,[[
.org start+10
add
start: sub]])
assert(success == false and err:match('Unable to resolve .org on line 1'))

-- It shouldn't reassign .equs
test_place([[
blah: .equ 17
mul blah*2]], nil, [[{$end=1 $start=0 blah=17}]])

-- Calculates a correct start address
test_place([[
.org 123
nop]], nil, [[{$end=123 $start=123}]])

-- A .org with a relative label:
success, err = pcall(test_place,[[.org @loop+4]])
assert(success == false
           and err:match('Unable to resolve .org on line 1')
           and err:match('Cannot resolve relative label'))

-- # Fifth pass tests

calculate_args = vulcan.calculate_args

-- ## Utility functions

function test_calculate(asm, args)
    local lines = parse_assembly(iterator(asm))
    local symbols = solve_equs(lines)
    measure_instructions(lines, symbols)
    place_labels(lines, symbols)
    calculate_args(lines, symbols)
    local actual_args = prettify(table.map(lines, function(l) return l.argument or 0 end))

    if actual_args ~= args then
        print('FAIL:\nExpected: ' .. args .. '\n  Actual: ' .. actual_args)
        return false
    end

    return true
end

-- ## Test cases

-- Simple
test_calculate([[add 25]], [[(25)]])

-- Arithmetic
test_calculate([[add 2+3*6]], [[(20)]])

-- Referring to labels
test_calculate([[
foo: .org 100
add foo+5
]], [[(100 105)]])

-- Referring to .equs
test_calculate([[
blah: .equ 17
mul blah*2]], [[(17 34)]] )

-- Referring to relative labels
test_calculate([[
loop: sub 1
brz @loop
]], [[(1 -2)]])

-- # Full assembler tests

assemble = vulcan.assemble

-- ## Utility functions

function test_assemble(asm, bytes)
    local actual_bytes = assemble(iterator(asm))

    if #actual_bytes + 1 ~= #bytes then
        print('FAIL:\nExpected: ' .. (#bytes) .. ' bytes to be generated\n  Actual: ' .. (#actual_bytes+1))
        return false
    end

    for idx, byte in ipairs(bytes) do
        local actual_byte = actual_bytes[idx-1]
        if byte ~= actual_byte then
            print('FAIL:\nExpected: ' .. byte_tostring(byte) .. ' at index ' .. idx .. '\n  Actual: ' .. byte_tostring(actual_byte))
        end
    end
    return true
end

function byte_tostring(byte)
    if byte < 16 then
        return string.format('0x0%x', byte)
    else
        return string.format('0x%x', byte)
    end
end

-- ## Test cases

-- Null program
test_assemble([[ nop ]], {0})

-- Opcodes
test_assemble([[
 add
 sub
 mul ]], {4, 8, 12})

-- Instructions with arguments
test_assemble([[
push 0x10
add 0x10 ]], {0x01, 0x10, 0x05, 0x10})

-- Instructions with negative arguments
test_assemble([[
loop: sub 1
brz @loop]], {0x09, 0x01, 0x6f, 0xfe, 0xff, 0xff})

-- Instructions with arguments and a .org
test_assemble([[
.org 0x0100
push 0x10
add 0x10 ]], {0x01, 0x10, 0x05, 0x10})

-- Instructions with long arguments
test_assemble([[
push 0x123456
add 0x1234 ]], {0x03, 0x56, 0x34, 0x12, 0x06, 0x34, 0x12})

-- .org directives at the beginning
test_assemble([[
.org 123
nop ]], {0x00})

-- .org directives in the middle
test_assemble([[
.org 0
add
.org 5
add ]], {0x04, 0, 0, 0, 0, 0x04})

-- .equ directives
test_assemble([[
foo: .equ 5
add foo ]], {0x05, 5})

-- Jumping to labels
test_assemble([[
.org 0x0100
       push 10
start: dup
       add 0x1000
       store 0
       sub 1
       brz @start]],
    {0x01, 0x0a, 0x4c, 0x06, 0x00, 0x10, 0x85, 0x00, 0x09, 0x01, 0x6f, 0xf8, 0xff, 0xff})

-- .db directives
test_assemble([[
add 10
.db 0x1234]], {0x05, 10, 0x34, 0x12, 0x00})

-- .db directives with .orgs
test_assemble([[
.org 0x100
add 10
.db 0x1234]], {0x05, 10, 0x34, 0x12, 0x00})

-- .db directives with strings
test_assemble([[
.org 0x100
add 10
.db "Hello"]], {0x05, 10, 0x48, 0x65, 0x6c, 0x6c, 0x6f})

-- .db directives with strings and escapes
test_assemble([[
.org 0x100
add 10
.db "Hello\0"]], {0x05, 10, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00})

test_assemble([[
.org 0x400
load 100
load 101
add
store 102
hlt]], {0x79, 0x64, 0x79, 0x65, 0x04, 0x85, 0x66, 0x74})
