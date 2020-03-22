vc = require('vc')

-- # Utility functions

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

-- # Expression parsing tests

expr = vc.expr

-- A wrapper for testing that ASTs are equal:
function test(pattern, line, ast)
    local actual_ast = prettify(pattern:match(line))
    if actual_ast == ast then return true
    else
        print('FAIL: [[' .. line .. ']]\nExpected: ' .. ast .. '\n  Actual: ' .. actual_ast)
        return false
    end
end

-- Hex number
test(expr, [[0x10]], [[(expr (term 16))]])

-- Binary number
test(expr, [[0b1010]], [[(expr (term 10))]])

-- Decimal number
test(expr, [[23]], [[(expr (term 23))]])

-- Decimal zero
test(expr, [[0]], [[(expr (term 0))]])

-- Negative decimal
test(expr, [[-35]], [[(expr (term -35))]])

-- Strings
test(expr, [["hello"]], [[(expr (term (string (h e l l o))))]])

-- Strings with escapes
test(expr, [["hello\""]], [[(expr (term (string (h e l l o \"))))]])

-- Expressions
test(expr, [[43+17]], [[(expr (term 43) + (term 17))]])

-- Expressions with negatives
test(expr, [[43/-17]], [[(expr (term 43 / -17))]])

-- Multiple terms
test(expr, [[43+17 - 3]], [[(expr (term 43) + (term 17) - (term 3))]])

-- Multiplication
test(expr, [[2*14-3]], [[(expr (term 2 * 14) - (term 3))]])

-- Sub-expressions
test(expr, [[2*(14-3)]], [[(expr (term 2 * (expr (term 14) - (term 3))))]])

-- Identifiers in expressions
test(expr, [[start + 2]], [[(expr (term (id start)) + (term 2))]])

-- Array references in expressions
test(expr, [[foo[3] ]], [[(expr (term (id foo (subscript (expr (term 3))))))]])

-- Addresses in expressions
test(expr, [[blah + @{x *4}]], [[(expr (term (id blah)) + (term (address (expr (term (id x) * 4)))))]])

-- Param-less function calls
test(expr, [[blah()]], [[(expr (term (id blah (params))))]])

-- Unary function calls
test(expr, [[blah(3)]], [[(expr (term (id blah (params (expr (term 3))))))]])

-- Unary function calls with exprs
test(expr, [[blah(x+4)]], [[(expr (term (id blah (params (expr (term (id x)) + (term 4))))))]])

-- Binary function calls
test(expr, [[blah(a, b)]], [[(expr (term (id blah (params (expr (term (id a))) (expr (term (id b)))))))]])

-- Ternary function calls
test(expr, [[blah(a,b,c)]], [[(expr (term (id blah (params (expr (term (id a))) (expr (term (id b))) (expr (term (id c)))))))]])

-- Blocks
test(expr, [[{ 3*4; 5+2 }]], [[(expr (term (block (expr (term 3 * 4)) (expr (term 5) + (term 2)))))]])
str = [[
  {
    3*4;
    5+2   ;
  }
]]
test(expr, str, [[(expr (term (block (expr (term 3 * 4)) (expr (term 5) + (term 2)))))]])

-- Empty blocks
test(expr, [[{;}]], [[(expr (term (block)))]])
test(expr, [[{ }]], [[(expr (term (block)))]])
test(expr, [[{}]], [[(expr (term (block)))]])
test(expr, [[{ ; }]], [[(expr (term (block)))]])

-- Assignments
test(expr, [[x = 3]], [[(expr (term (assign (id x) (expr (term 3)))))]])

-- Assignments to array
test(expr, [[x[2]=3]], [[(expr (term (assign (id x (subscript (expr (term 2)))) (expr (term 3)))))]])

-- Assignments to memory
test(expr, [[@{ 1500 } = 3]], [[(expr (term (assign (address (expr (term 1500))) (expr (term 3)))))]])

-- Assignments in complex expressions
test(expr, [[3 + (x = 4) * 2]], [[(expr (term 3) + (term (expr (term (assign (id x) (expr (term 4))))) * 2))]])

-- Conditionals
test(expr, [[x = if (y) 3)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3))))))))]])

-- Conditionals with else
test(expr, [[x = if(y) 3 else 5)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3)) (expr (term 5))))))))]])

-- Ternary conditionals
test(expr, [[x = (y ? 3 : 5)]], [[(expr (term (assign (id x) (expr (term (if (expr (term (id y))) (expr (term 3)) (expr (term 5))))))))]])

-- Member references
test(expr, [[blah.foo]], [[(expr (term (id blah (member foo))))]])

-- Member array references
test(expr, [[blah.foo[3] ]], [[(expr (term (id blah (member foo (subscript (expr (term 3)))))))]])

-- Member lvalues
test(expr, [[blah.foo = 7]], [[(expr (term (assign (id blah (member foo)) (expr (term 7)))))]])

-- Member array lvalues
test(expr, [[blah.foo[3] = 7]], [[(expr (term (assign (id blah (member foo (subscript (expr (term 3))))) (expr (term 7)))))]])

-- Assignments from new
test(expr, [[x = new Player]], [[(expr (term (assign (id x) (new Player))))]])

-- # Statement parsing tests

statement = vc.statement

-- Expressions
test(statement, [[x+3;]], [[(expr (term (assign (id blah (member foo)) (expr (term 7)))))]])
