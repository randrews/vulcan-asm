vc = require('vc')

-- # Expression parsing tests

expr = vc.expr

-- ## Utility functions

-- Map a function across a table
function table:map(fn)
    local t = {}
    for _, v in ipairs(self) do
        table.insert(t, fn(v))
    end
    return t
end

-- Reduce a table with a function
function table:reduce(fn, sum)
    local start_idx = 1
    if not sum then
        start_idx = 2
        sum = self[1]
    end

    for i = start_idx, #self do
        sum = fn(sum, self[i])
    end

    return sum
end

-- Pretty-print an array
function prettify(t)
    -- It's an empty object or an array
    if t[1] or not next(t) then
        local elements = table.map(t, function(el)
                                       if type(el) == 'table' then
                                           return prettify(el)
                                       else
                                           return string.format('%s', el)
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

-- A wrapper for testing that ASTs are equal:
function test(line, ast)
    local actual_ast = prettify(expr:match(line))
    if actual_ast == ast then return true
    else
        print('FAIL: [[' .. line .. ']]\nExpected: ' .. ast .. '\n  Actual: ' .. actual_ast)
        return false
    end
end

-- ## Test cases

-- Hex number
test([[0x10]], [[(expr (term 16))]])

-- Binary number
test([[0b1010]], [[(expr (term 10))]])

-- Decimal number
test([[23]], [[(expr (term 23))]])

-- Decimal zero
test([[0]], [[(expr (term 0))]])

-- Negative decimal
test([[-35]], [[(expr (term -35))]])

-- Strings
test([["hello"]], [[(expr (term (string (h e l l o))))]])

-- Strings with escapes
test([["hello\""]], [[(expr (term (string (h e l l o \"))))]])

-- Expressions
test([[43+17]], [[(expr (term 43) + (term 17))]])

-- Expressions with negatives
test([[43/-17]], [[(expr (term 43 / -17))]])

-- Multiple terms
test([[43+17 - 3]], [[(expr (term 43) + (term 17) - (term 3))]])

-- Multiplication
test([[2*14-3]], [[(expr (term 2 * 14) - (term 3))]])

-- Sub-expressions
test([[2*(14-3)]], [[(expr (term 2 * (expr (term 14) - (term 3))))]])

-- Identifiers in expressions
test([[start + 2]], [[(expr (term (id start)) + (term 2))]])

-- Array references in expressions
test([[foo[3] ]], [[(expr (term (id foo (subscript (expr (term 3))))))]])

-- Addresses in expressions
test([[blah + @{x *4}]], [[(expr (term (id blah)) + (term (address (expr (term (id x) * 4)))))]])

-- Param-less function calls
test([[blah()]], [[(expr (term (id blah (params))))]])

-- Unary function calls
test([[blah(3)]], [[(expr (term (id blah (params (expr (term 3))))))]])

-- Unary function calls with exprs
test([[blah(x+4)]], [[(expr (term (id blah (params (expr (term (id x)) + (term 4))))))]])

-- Binary function calls
test([[blah(a, b)]], [[(expr (term (id blah (params (expr (term (id a))) (expr (term (id b)))))))]])

-- Ternary function calls
test([[blah(a,b,c)]], [[(expr (term (id blah (params (expr (term (id a))) (expr (term (id b))) (expr (term (id c)))))))]])

-- Blocks
test([[{ 3*4; 5+2 }]], [[(expr (term (block (expr (term 3 * 4)) (expr (term 5) + (term 2)))))]])
str = [[
  {
    3*4;
    5+2   ;
  }
]]
test(str, [[(expr (term (block (expr (term 3 * 4)) (expr (term 5) + (term 2)))))]])

-- Empty blocks
test([[{;}]], [[(expr (term (block)))]])
test([[{ }]], [[(expr (term (block)))]])
test([[{}]], [[(expr (term (block)))]])
test([[{ ; }]], [[(expr (term (block)))]])

-- Assignments
test([[x = 3]], [[(expr (term (assign (id x) (expr (term 3)))))]])

-- Assignments to array
test([[x[2]=3]], [[(expr (term (assign (id x (subscript (expr (term 2)))) (expr (term 3)))))]])

-- Assignments to memory
test([[@{ 1500 } = 3]], [[(expr (term (assign (address (expr (term 1500))) (expr (term 3)))))]])

-- Assignments in complex expressions
test([[3 + (x = 4) * 2]], [[(expr (term 3) + (term (expr (term (assign (id x) (expr (term 4))))) * 2))]])

-- Conditionals
test([[x = if (y) 3)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3))))))))]])

-- Conditionals with else
test([[x = if(y) 3 else 5)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3)) (expr (term 5))))))))]])

-- Ternary conditionals
test([[x = (y ? 3 : 5)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3)) (expr (term 5))))))))]])
