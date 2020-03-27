local Generator = {}

-- Compile a table containing a sequence of parsed statements
--
-- - emit is a function that takes a string and emits that to the final asm
-- - globals is a table mapping defined global names to symbols
-- - gensym is a function that return unique, valid asm label names (optionally using a semantic name passed in)
function compile(statements, emit, globals, gensym)
    local gen = Generator.new(globals, gensym)

    -- Try to generate code for each statement
    for _, node in ipairs(statements) do
        gen:generate(node, env)
    end

    -- Write the generated code out to the emitter
    gen:finalize(emit)
end

function Generator.new(globals, gensym)
    local instance = {
        gensym = gensym,
        globals = globals,
        segments = {text = {}, functions = {}, globals = {}}
    }
    setmetatable(instance, {__index=Generator})

    -- We have three segments in the program:
    -- - Text, which gets emitted first and is all the expressions in the global context, followed by an implicit hlt
    -- - Functions, emitted second and are all the functions
    -- - Globals, emitted last and containing the labels and .db's for global variables (all initialized to 0, the initializers run where the declaration was, in text)
    local emit_to_segment = function(segment, line)
        table.insert(instance.segments[segment], line)
    end
    instance.emit = function(self, line) emit_to_segment('text', line) end
    instance.emit_global = function(self, line) emit_to_segment('globals', line) end

    return instance
end

-- After all statements have been generated, call this to emit the code (in order)
--
-- - emit is a function that takes a string and writes it to an assembly file
function Generator:finalize(emit)
    -- Helper for emitting an entire segment to the final output at once
    local function emit_segment(segment)
        for _, line in ipairs(segment) do emit(line) end
    end

    -- Emit all of the text followed by a hlt
    if #(self.segments.text) > 0 then
        emit_segment(self.segments.text)
        emit('hlt')
    end

    -- If there are any functions or globals, emit those too.
    -- They don't need hlts because functions will automatically return
    -- and globals never get jumped to.
    if #(self.segments.functions) > 0 then emit_segment(self.segments.functions) end
    if #(self.segments.globals) > 0 then emit_segment(self.segments.globals) end
end

-- Generate code (sending to whatever the active segment is) for the passed-in node.
-- This will work on any node, so it gets called recursively by most other node types.
function Generator:generate(node)
    local name = node[1]
    -- Some names aren't viable method names; 'new' because it's
    -- also the constructor, 'if' because it's a keyword
    if name == 'if' or name == 'new' then name = '_' .. name end
    local fn = self[name]
    if fn then return fn(self, node)
    else error('Unrecognized node type: ' .. name) end
end

function Generator:stmt(stmt)
    self:generate(stmt[2])
end

function Generator:var(var)
    -- Something for functions here
    local name = var[2]
    local label = self.gensym(name)
    self.globals[name] = label
    self:emit_global(label .. ': .db 0')

    local typename = clause(var, 'type')
    local initial = clause(var, 'init')

    if initial then
        self:generate(initial[2])
        self:emit('store24 ' .. label)
    end

    if typename then
        error('TODO')
    end
end

function Generator:expr(expr)
    for index = 2, #expr, 2 do
        local term = expr[index]
        self:generate(term, env)
        if index > 2 then
            local op = expr[index-1]
            if op == '+' then self:emit('add')
            elseif op == '-' then self:emit('sub') end
        end
    end
end

function Generator:term(term)
    for index = 2, #term, 2 do
        local fact = term[index]

        if type(fact) == 'number' then self:emit('push ' .. fact)
        elseif type(fact) == 'table' then self:generate(fact) end

        if index > 2 then
            local op = term[index-1]
            if op == '*' then self:emit('mul')
            elseif op == '/' then self:emit('div')
            elseif op == '%' then self:emit('mod') end
        end
    end
end

function Generator:id(id)
    local name = id[2]
    if self.globals[name] then
        if id[3] and id[3][1] == 'subscript' then
            self:generate(id[3][2])
            self:emit('mul 3')
            self:emit('add ' .. self.globals[name])
            self:emit('load24')
        elseif id[3] and id[3] == 'params' then error('TODO')
        elseif id[3] and id[3] == 'member' then error('TODO')
        elseif not id[3] then
            self:emit('load24 ' .. self.globals[name])
        end
    else
        error('Unrecognized identifier: ' .. name)
    end
    -- Something for function scopes later
end

-- An address reference (in an rvalue, not an lvalue)
function Generator:address(addr)
    self:generate(addr[2])
    self:emit('load24')
end

function Generator:assign(assign)
    local _, lvalue, rvalue = table.unpack(assign)

    -- Go ahead and emit the rvalue, it's now on top of the stack
    self:generate(rvalue)

    -- Deal with the lvalue
    if lvalue[1] == 'address' then
    elseif lvalue[1] == 'id' then
        local _, name, qualifier = table.unpack(lvalue)
        -- Something for function scopes
        assert(self.globals[name], 'Unrecognized name: ' .. name)
        if qualifier then -- It's either a subscript or a member
            if qualifier[1] == 'subscript' then
                self:generate(qualifier[2], env)
                self:emit('mul 3')
                self:emit('add ' .. self.globals[name])
                self:emit('store24')
            else error('TODO') end
        else
            self:emit('store24 ' .. self.globals[name])
        end
    else error('Unrecognized lvalue: ' .. lvalue[1]) end
end

function Generator:_new(new)
    error('TODO')
end

function Generator:_if(_if)
    error('TODO')
end

function Generator:string(str)
    error('TODO')
end

function clause(node, name)
    for _, child in ipairs(node) do
        if type(child) == 'table' and child[1] == name then
            return child
        end
    end
end

return { compile = compile }
