parser = require('parser')
lpeg = require('lpeg')

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
    if type(t) ~= 'table' then -- It's a number or something
        return tostring(t)
    elseif t[1] or not next(t) then -- It's an empty object or an array
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

expr = parser.expr

-- A wrapper for testing that ASTs are equal:
function test(pattern, line, ast)
    local tree, remainder = (pattern * lpeg.Cp()):match(line)
    if tree == nil then
        print('FAIL: [[' .. line .. ']]\n  Failed to parse!')
    elseif remainder <= #line then
        local partial_ast = prettify(tree)
        print('FAIL: [[' .. line .. ']]\nDid not fully parse!\n  Matched: ' .. line:sub(1, remainder-1) .. '\n  Parsed as: ' .. partial_ast)
    elseif tree then
        local actual_ast = prettify(tree)
        if actual_ast == ast then return true
        else
            print('FAIL: [[' .. line .. ']]\nExpected: ' .. ast .. '\n  Actual: ' .. actual_ast)
            return false
        end
    end
end

-- Hex number
test(expr, [[0x10]], [[16]])

-- Binary number
test(expr, [[0b1010]], [[10]])

-- Decimal number
test(expr, [[23]], [[23]])

-- Decimal zero
test(expr, [[0]], [[0]])

-- Negative decimal
test(expr, [[-35]], [[(neg 35)]])

-- Strings
test(expr, [["hello"]], [[(string (h e l l o))]])

-- Strings with escapes
test(expr, [["hello\""]], [[(string (h e l l o \"))]])

-- Expressions
test(expr, [[43+17]], [[(+ 43 17)]])

-- Expressions with negatives
test(expr, [[43/-17]], [[(/ 43 (neg 17))]])

-- Multiple terms
test(expr, [[43+17 - 3]], [[(+ 43 (- 17 3))]])

-- Multiplication
test(expr, [[2*14-3]], [[(- (* 2 14) 3)]])

-- Sub-expressions
test(expr, [[2*(14-3)]], [[(* 2 (- 14 3))]])

-- Boolean expressions
test(expr, [[x > 4]], [[(> (id x) 4)]])

-- More boolean expressions
test(expr, [[x > 4 || x < 0]], [[(|| (> (id x) 4) (< (id x) 0))]])

-- Even more boolean expressions
test(expr, [[(x != 3) && !y ]], [[(&& (!= (id x) 3) (not (id y)))]])

-- Identifiers in expressions
test(expr, [[start + 2]], [[(+ (id start) 2)]])

-- Array references in expressions
test(expr, [[foo[3] ]], [[(id foo (subscript 3))]])

-- Addresses in expressions
test(expr, [[blah + @{x *4}]], [[(+ (id blah) (address (* (id x) 4)))]])

-- Param-less function calls
test(expr, [[blah()]], [[(id blah (params))]])

-- Unary function calls
test(expr, [[blah(3)]], [[(id blah (params 3))]])

-- Unary function calls with exprs
test(expr, [[blah(x+4)]], [[(id blah (params (+ (id x) 4)))]])

-- Binary function calls
test(expr, [[blah(a, b)]], [[(id blah (params (id a) (id b)))]])

-- Ternary function calls
test(expr, [[blah(a,b,c)]], [[(id blah (params (id a) (id b) (id c)))]])

-- Assignments
test(expr, [[x = 3]], [[(assign (id x) 3)]])

-- Assignments to array
test(expr, [[x[2]=3]], [[(assign (id x (subscript 2)) 3)]])

-- Assignments to memory
test(expr, [[@{ 1500 } = 3]], [[(assign (address 1500) 3)]])

-- Assignments in complex expressions
test(expr, [[3 + (x = 4) * 2]], [[(+ 3 (* (assign (id x) 4) 2))]])

-- Ternary conditionals
test(expr, [[x = (y ? 3 : 5)]], [[(assign (id x) (if (id y) 3 5))]])

-- Member references
test(expr, [[blah.foo]], [[(id blah (member foo))]])

-- Member array references
test(expr, [[blah.foo[3] ]], [[(id blah (member foo (subscript 3)))]])

-- Member lvalues
test(expr, [[blah.foo = 7]], [[(assign (id blah (member foo)) 7)]])

-- Member array lvalues
test(expr, [[blah.foo[3] = 7]], [[(assign (id blah (member foo (subscript 3))) 7)]])

-- Assignments from new
test(expr, [[x = new Player]], [[(assign (id x) (new Player))]])

-- # Statement parsing tests

statement = parser.statement

-- Expressions
test(statement, [[3]], [[(expr 3)]])
test(statement, [[if(x) {3} else {y=4; foo(7)}]], [[(if (id x) (body 3) (body (assign (id y) 4) (id foo (params 7))))]])

-- Variable declarations
test(statement, [[var x]], [[(var x)]])

-- Variable declarations with initial value
test(statement, [[var x = 7]], [[(var x (init 7))]])

-- Variable declarations with type
test(statement, [[var x:Weapon]], [[(var x (type Weapon))]])

-- Variable declarations with type and initial value
test(statement, [[var x:Weapon = new Weapon]], [[(var x (type Weapon) (init (new Weapon)))]])

-- Function declarations
test(statement, [[function foo() { }]], [[(func foo (body))]])

-- Function declarations with args
test(statement, [[function foo(a, b) { }]], [[(func foo (args a b) (body))]])

-- Function declarations with args and body
test(statement, [[function foo(a, b) { a+b*2; }]], [[(func foo (args a b) (body (+ (id a) (* (id b) 2))))]])
test(statement, [[function foo(a, b) { var x=a*b; x+2 }]], [[(func foo (args a b) (body (var x (init (* (id a) (id b)))) (+ (id x) 2)))]])

-- Function declarations with return
test(statement, [[function foo() { return 6 }]], [[(func foo (body (return 6)))]])

-- Void return
test(statement, [[function foo() { return }]], [[(func foo (body (return)))]])

-- Struct declarations
test(statement, [[struct Coord { x, y }]], [[(struct Coord (member x) (member y))]])

-- Struct declarations with initial values
test(statement, [[struct Coord { x=0, y = 0 }]], [[(struct Coord (member x (init 0)) (member y (init 0)))]])

-- Struct declarations with lengths
test(statement, [[struct Person { name(16) }]], [[(struct Person (member name (length 16)))]])

-- Loops
test(statement, [[loop { doThing() }]], [[(loop (body (id doThing (params))))]])

-- Loops with multiple statements
test(statement, [[loop { doThing(); doOtherThing }]], [[(loop (body (id doThing (params)) (id doOtherThing)))]])

-- Loops with breaks
test(statement, [[loop { doThing(); break }]], [[(loop (body (id doThing (params)) (break)))]])

-- Conditionals
test(statement, [[if (y) {3}]], [[(if (id y) (body 3))]])

-- Conditionals with else
test(statement, [[if(y) {3 } else {5}]], [[(if (id y) (body 3) (body 5))]])

-- Conditionals with else if
test(statement, [[if(y) {3 } else if (z) {5}else{7}]], [[(if (id y) (body 3) (if (id z) (body 5) (body 7)))]])
