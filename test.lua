statement = require('vulcan')

function prettify(t)
    local elements = table.map(t, function(el)
                                   if type(el) == 'table' then
                                       return prettify(el)
                                   else
                                       return string.format('%q', el)
                                   end
    end)
    
    return '(' .. table.concat(elements, ' ') .. ')'
end

function test(line, ast)
    local actual_ast = prettify(statement:match(line))
    if actual_ast == ast then return true
    else
        print('FAIL: [[' .. line .. ']]\nExpected: ' .. ast .. '\nActual:   ' .. actual_ast)
        return false
    end
end

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

-- Binary argument
test([[add 0b1010]], [[("opcode" "add" "argument" ("expr" ("term" 10)))]])

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
