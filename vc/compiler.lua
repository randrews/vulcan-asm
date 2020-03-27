local parser = require('parser')

-- Compile a table containing a sequence of parsed statements
-- Env is a table with these members:
--
-- - emit is a function that takes a string and emits that to the final asm
-- - gensym is a function that return unique, valid asm label names (optionally using an optional semantic name passed in)
-- - globals is a table mapping defined global names to symbols
function compile(statements, env)
    -- This is given to us from outside, we have to call it in order for the final asm
    local final_emit = env.emit

    -- We have three segments in the program:
    -- - Text, which gets emitted first and is all the expressions in the global context, followed by an implicit hlt
    -- - Functions, emitted second and are all the functions
    -- - Globals, emitted last and containing the labels and .db's for global variables (all initialized to 0, the initializers run where the declaration was, in text)
    local segments = {text = {}, functions = {}, globals = {}}
    env.emit_to_segment = function(segment, line)
        assert(segments[segment], 'Unknown segment ' .. segment)
        table.insert(segments[segment], line)
    end
    env.emit = function(line) env.emit_to_segment('text', line) end
    env.emit_global = function(line) env.emit_to_segment('globals', line) end

    -- Try to compile each statement. There are a limited number of things it could be:
    for _, ast in ipairs(statements) do
        -- generate(
        assert(ast[1] == 'stmt', 'Did not compile to a statement')

        if ast[2][1] == 'var' then
            compile_var(ast[2], env)
        elseif ast[2][1] == 'expr' then
            compile_expr(ast[2], env)
        end
    end

    -- Helper for emitting an entire segment to the final output at once
    local function emit_segment(segment)
        for _, line in ipairs(segment) do final_emit(line) end
    end

    -- Emit all of the text followed by a hlt
    if #segments.text > 0 then
        emit_segment(segments.text)
        final_emit('hlt')
    end

    -- If there are any functions or globals, emit those too.
    -- They don't need hlts because functions will automatically return
    -- and globals never get jumped to.
    if #segments.functions > 0 then emit_segment(segments.functions) end
    if #segments.globals > 0 then emit_segment(segments.globals) end
end

local generators = {}

function generate(node, env)
    local name = node[1]
    local fn = generators[name]
    if fn then return fn(node, env)
    else error('Unrecognized node type: ' .. name) end
end

function generators.stmt(stmt, env)

end

function compile_var(var, env)
    -- Something for functions here
    local name = var[2]
    local label = env.gensym(name)
    env.globals[name] = label
    env.emit_global(label .. ': .db 0')

    local typename = clause(var, 'type')
    local initial = clause(var, 'init')

    if initial then
        compile_expr(initial[2], env)
        env.emit('store24 ' .. label)
    end

    if typename then
        error('TODO')
    end
end

function compile_expr(expr, env)
    for index = 2, #expr, 2 do
        local term = expr[index]
        compile_term(term, env)
        if index > 2 then
            local op = expr[index-1]
            if op == '+' then env.emit('add')
            elseif op == '-' then env.emit('sub') end
        end
    end
end

function compile_term(term, env)
    for index = 2, #term, 2 do
        local fact = term[index]

        if type(fact) == 'number' then env.emit('push ' .. fact)
        elseif type(fact) == 'table' then
            if fact[1] == 'expr' then compile_expr(fact, env)
            elseif fact[1] == 'new' then error('TODO')
            elseif fact[1] == 'assign' then compile_assign(fact, env)
            elseif fact[1] == 'if' then error('TODO')
            elseif fact[1] == 'id' then compile_id(fact, env)
            elseif fact[1] == 'string' then error('TODO')
            elseif fact[1] == 'address' then compile_address(fact, env) end
        end

        if index > 2 then
            local op = term[index-1]
            if op == '*' then env.emit('mul')
            elseif op == '/' then env.emit('div')
            elseif op == '%' then env.emit('mod') end
        end
    end
end

function compile_id(id, env)
    local name = id[2]
    if env.globals[name] then
        if id[3] and id[3][1] == 'subscript' then
            compile_expr(id[3][2], env)
            env.emit('mul 3')
            env.emit('add ' .. env.globals[name])
            env.emit('load24')
        elseif id[3] and id[3] == 'params' then error('TODO')
        elseif id[3] and id[3] == 'member' then error('TODO')
        elseif not id[3] then
            env.emit('load24 ' .. env.globals[name])
        end
    else
        error('Unrecognized identifier: ' .. name)
    end
    -- Something for function scopes later
end

-- An address reference (in an rvalue, not an lvalue)
function compile_address(addr, env)
    compile_expr(addr[2], env)
    env.emit('load24')
end

function compile_assign(assign, env)
    local _, lvalue, rvalue = table.unpack(assign)

    -- Go ahead and emit the rvalue, it's now on top of the stack
    compile_expr(rvalue, env)

    -- Deal with the lvalue
    if lvalue[1] == 'address' then
    elseif lvalue[1] == 'id' then
        local _, name, qualifier = table.unpack(lvalue)
        -- Something for function scopes
        assert(env.globals[name], 'Unrecognized name: ' .. name)
        if qualifier then -- It's either a subscript or a member
            if qualifier[1] == 'subscript' then
                compile_expr(qualifier[2], env)
                env.emit('mul 3')
                env.emit('add ' .. env.globals[name])
                env.emit('store24')
            else error('TODO') end
        else
            env.emit('store24 ' .. env.globals[name])
        end
    else error('Unrecognized lvalue: ' .. lvalue[1]) end
end

function clause(node, name)
    for _, child in ipairs(node) do
        if type(child) == 'table' and child[1] == name then
            return child
        end
    end
end

return { compile = compile }
