compiler = require('compiler')
parser = require('parser')

-- # Utility functions

-- Map a function across a table
function table:map(fn)
    local t = {}
    for _, v in ipairs(self) do
        table.insert(t, fn(v))
    end
    return t
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

-- Return whether two arrays are (shallow) equal
function eq(tbl1, tbl2)
    for i = 1, math.max(#tbl1, #tbl2) do
        if tbl1[i] ~= tbl2[i] then
            return false
        end
    end
    return true
end

function test(opts)
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

    local statements = parser.parse(src)
    compiler.compile(statements, env)

    if not eq(asm, actual_asm) then
        print('FAIL: Produced different assembly for [[' .. src .. ']]:')
        print('AST:\n\t' .. prettify(statements))
        print('Expected:')
        for _,l in ipairs(asm) do print('\t' .. l) end
        print('Actual:')
        for _,l in ipairs(actual_asm) do print('\t' .. l) end
        return
    end

    check(env)
end

-- # Expression compilation tests

-- ## Test cases

-- Simple addition
test{[[3+4]], {'push 3', 'push 4', 'add', 'hlt'}}

-- More complex addition
test{[[3+4-2]], {'push 3', 'push 4', 'add', 'push 2', 'sub', 'hlt'}}

-- Order of operations
test{[[3+4*2]], {'push 3', 'push 4', 'push 2', 'mul', 'add', 'hlt'}}

-- Numbers in other bases
test{[[0b111 + 0x10]], {'push 7', 'push 16', 'add', 'hlt'}}

-- Nested expressions
test{[[(3+4)*2]], {'push 3', 'push 4', 'add', 'push 2', 'mul', 'hlt'}}

-- Globals in expressions
test{[[x+3]], {'load24 global_x', 'push 3', 'add', 'hlt'},
    globals = {x = 'global_x'}
}

-- Address references
test{[[@{map+3*4}]], {'load24 global_map', 'push 3', 'push 4', 'mul', 'add', 'load24', 'hlt'},
    globals = {map = 'global_map'}
}

-- Array references
test{[[actors[i-1] ]], {'load24 global_i', 'push 1', 'sub', 'mul 3', 'add global_actors', 'load24', 'hlt'},
    globals = {actors = 'global_actors', i = 'global_i'}
}

-- Global declarations
test{[[var foo]], {'gen1: .db 0'},
    check = function(env)
        assert(env.globals.foo == 'gen1')
    end
}

-- Global declarations with initial values
test{[[var foo = 3*4]], {'push 3', 'push 4', 'mul', 'store24 gen1', 'hlt', 'gen1: .db 0'},
    check = function(env)
        assert(env.globals.foo == 'gen1')
    end
}

-- Multiple statements
test{[[var x=3; var y=(4)]], {'push 3', 'store24 gen1', 'push 4', 'store24 gen2', 'hlt', 'gen1: .db 0', 'gen2: .db 0'}}

-- Assigns to globals
test{[[foo = 3*4]], {'push 3', 'push 4', 'mul', 'store24 foo', 'hlt'}, globals = {foo = 'foo'}}

-- Assigns to globals with subscripts
test{[[foo[2] = 3*4]], {'push 3', 'push 4', 'mul', 'push 2', 'mul 3', 'add foo', 'store24', 'hlt'}, globals = {foo = 'foo'}}
