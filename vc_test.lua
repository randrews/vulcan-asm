vc = require('vc')
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

-- Assignments
test(expr, [[x = 3]], [[(expr (term (assign (id x) (expr (term 3)))))]])

-- Assignments to array
test(expr, [[x[2]=3]], [[(expr (term (assign (id x (subscript (expr (term 2)))) (expr (term 3)))))]])

-- Assignments to memory
test(expr, [[@{ 1500 } = 3]], [[(expr (term (assign (address (expr (term 1500))) (expr (term 3)))))]])

-- Assignments in complex expressions
test(expr, [[3 + (x = 4) * 2]], [[(expr (term 3) + (term (expr (term (assign (id x) (expr (term 4))))) * 2))]])

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
test(expr, [[x = new Player]], [[(expr (term (assign (id x) (expr (term (new Player))))))]])

-- # Statement parsing tests

statement = vc.statement

-- Expressions
test(statement, [[3]], [[(stmt (expr (term 3)))]])
test(statement, [[if(x) {3} else {y=4; foo(7)}]], [[(stmt (if (expr (term (id x))) (body (expr (term 3))) (body (expr (term (assign (id y) (expr (term 4))))) (expr (term (id foo (params (expr (term 7)))))))))]])

-- Variable declarations
test(statement, [[var x]], [[(stmt (var x))]])

-- Variable declarations with initial value
test(statement, [[var x = 7]], [[(stmt (var x (init (expr (term 7)))))]])

-- Variable declarations with type
test(statement, [[var x:Weapon]], [[(stmt (var x (type Weapon)))]])

-- Variable declarations with type and initial value
test(statement, [[var x:Weapon = new Weapon]], [[(stmt (var x (type Weapon) (init (expr (term (new Weapon))))))]])

-- Function declarations
test(statement, [[function foo() { }]], [[(stmt (func foo (body)))]])

-- Function declarations with args
test(statement, [[function foo(a, b) { }]], [[(stmt (func foo (args a b) (body)))]])

-- Function declarations with args and body
test(statement, [[function foo(a, b) { a+b*2; }]], [[(stmt (func foo (args a b) (body (expr (term (id a)) + (term (id b) * 2)))))]])
test(statement, [[function foo(a, b) { var x=a*b; x+2 }]], [[(stmt (func foo (args a b) (body (var x (init (expr (term (id a) * (id b))))) (expr (term (id x)) + (term 2)))))]])

-- Function declarations with return
test(statement, [[function foo() { return 6 }]], [[(stmt (func foo (body (return (expr (term 6))))))]])

-- Struct declarations
test(statement, [[struct Coord { x, y }]], [[(stmt (struct Coord (member x) (member y)))]])

-- Struct declarations with initial values
test(statement, [[struct Coord { x=0, y = 0 }]], [[(stmt (struct Coord (member x (init (expr (term 0)))) (member y (init (expr (term 0))))))]])

-- Struct declarations with lengths
test(statement, [[struct Person { name(16) }]], [[(stmt (struct Person (member name (length (expr (term 16))))))]])

-- Loops
test(statement, [[loop { doThing() }]], [[(stmt (loop (body (expr (term (id doThing (params)))))))]])

-- Loops with multiple statements
test(statement, [[loop { doThing(); doOtherThing }]], [[(stmt (loop (body (expr (term (id doThing (params)))) (expr (term (id doOtherThing))))))]])

-- Loops with breaks
test(statement, [[loop { doThing(); break }]], [[(stmt (loop (body (expr (term (id doThing (params)))) (break))))]])

-- Conditionals
test(statement, [[if (y) {3}]], [[(stmt (if (expr (term (id y))) (body (expr (term 3)))))]])

-- Conditionals with else
test(statement, [[if(y) {3 } else {5}]], [[(stmt (if (expr (term (id y))) (body (expr (term 3))) (body (expr (term 5)))))]])

-- # Expression compilation tests

local compile = vc.compile

-- ## Utility functions

function compile_test(opts)
    local src = opts[1]
    local asm = opts[2]
    local globals = opts.globals or { print = 'print', new = 'new' }
    local check = opts.check or (function() end)

    if opts.pending then
        print('PENDING: ' .. src)
        return
    end

    local actual_asm = {}
    local function emit(str) table.insert(actual_asm, str) end
    local sym_idx = 0
    local function gensym() sym_idx = sym_idx + 1; return 'gen' .. sym_idx end
    local env = { emit = emit, gensym = gensym, globals = globals }

    compile(src, env)

    if not eq(asm, actual_asm) then
        print('FAIL: Produced different assembly for [[' .. src .. ']]:')
        print('AST:\n\t' .. prettify(statement:match(src)))
        print('Expected:')
        for _,l in ipairs(asm) do print('\t' .. l) end
        print('Actual:')
        for _,l in ipairs(actual_asm) do print('\t' .. l) end
        return
    end

    check(env)
end

function eq(tbl1, tbl2)
    for i = 1, math.max(#tbl1, #tbl2) do
        if tbl1[i] ~= tbl2[i] then
            return false
        end
    end
    return true
end

-- ## Test cases

-- Simple addition
compile_test{[[3+4]], {'push 3', 'push 4', 'add', 'hlt'}}

-- More complex addition
compile_test{[[3+4-2]], {'push 3', 'push 4', 'add', 'push 2', 'sub', 'hlt'}}

-- Order of operations
compile_test{[[3+4*2]], {'push 3', 'push 4', 'push 2', 'mul', 'add', 'hlt'}}

-- Numbers in other bases
compile_test{[[0b111 + 0x10]], {'push 7', 'push 16', 'add', 'hlt'}}

-- Nested expressions
compile_test{[[(3+4)*2]], {'push 3', 'push 4', 'add', 'push 2', 'mul', 'hlt'}}

-- Globals in expressions
compile_test{[[x+3]], {'load24 global_x', 'push 3', 'add', 'hlt'},
    globals = {x = 'global_x'}
}

-- Address references
compile_test{[[@{map+3*4}]], {'load24 global_map', 'push 3', 'push 4', 'mul', 'add', 'load24', 'hlt'},
    globals = {map = 'global_map'}
}

-- Array references
compile_test{[[actors[i-1] ]], {'load24 global_i', 'push 1', 'sub', 'mul 3', 'add global_actors', 'load24', 'hlt'},
    globals = {actors = 'global_actors', i = 'global_i'}
}

-- Global declarations
compile_test{[[var foo]], {'gen1: .db 0'},
    check = function(env)
        assert(env.globals.foo == 'gen1')
    end
}

-- Global declarations with initial values
compile_test{[[var foo = 3*4]], {'push 3', 'push 4', 'mul', 'store24 gen1', 'hlt', 'gen1: .db 0'},
    check = function(env)
        assert(env.globals.foo == 'gen1')
    end
}

-- Multiple statements
compile_test{[[var x=3; var y=(4)]], {'push 3', 'store24 gen1', 'push 4', 'store24 gen2', 'hlt', 'gen1: .db 0', 'gen2: .db 0'}}

-- Assigns to globals
compile_test{[[foo = 3*4]], {'push 3', 'push 4', 'mul', 'store24 foo', 'hlt'}, globals = {foo = 'foo'}}

-- Assigns to globals with subscripts
compile_test{[[foo[2] = 3*4]], {'push 3', 'push 4', 'mul', 'push 2', 'mul 3', 'add foo', 'store24', 'hlt'}, globals = {foo = 'foo'}}
