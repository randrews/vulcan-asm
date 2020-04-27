local Generator = {}

-- ## Compile
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
    instance.emit_function = function(self, line) emit_to_segment('functions', line) end

    return instance
end

-- ## Finalize
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
    if type(node) == 'table' then
        local name = node[1]
        -- Some node names aren't valid method names, let's translate them
        local method_name = method_for(name)
        local fn = self[method_name]
        if fn then return fn(self, node)
        else error('Unrecognized node type: ' .. name) end
    elseif type(node) == 'number' then
        self:emit('push ' .. node)
    else error('Unrecognized node type [' .. node .. ']') end
end

-- ## Variable declarations:
--
-- This compiles a variable declaration, and puts a spec for that variable into either
-- `globals` or `locals`. What that spec is depends on what kind of variable it is:
--
-- All variables are one word long, and either contain a pointer to something, or a
-- simple value. The only times we need to know the type of a variable is if it's an
-- instance of a struct (so we know which offsets to use for which members) or if it's
-- a function (to know the number of arguments, to ensure we structure the call
-- correctly).
--
-- The simplest thing that can be a variable spec is just a simple value: these compile
-- to a label in the globals segment (for globals), so the spec is just a string saying
-- which label it is. For a local, it can be a number for which index local it is.
--
-- All other specs are tables, with at minimum a `type` field and either a `label` field
-- (for globals) or an `index` field (for locals).
--
-- Functions (which don't get declared with `var` but I'll document them here anyway)
-- have a type of 'function', and also an 'arity' field for the number of arguments.
-- They are also only globals, no local functions.
--
-- Structs have a type of 'struct' and a 'struct' field that contains the name of the
-- struct they are.
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

function operator(...)
    local opcodes = {...}
    return function(self, expr)
        self:generate(expr[2])
        self:generate(expr[3])
        for _, opcode in ipairs(opcodes) do
            self:emit(opcode)
        end
    end
end

Generator.add = operator('add')
Generator.sub = operator('sub')
Generator.mul = operator('mul')
Generator.div = operator('div')
Generator.mod = operator('mod')
Generator.gt = operator('gt')
Generator.lt = operator('lt')
Generator.ge = operator('lt', 'lnot')
Generator.le = operator('gt', 'lnot')
Generator.ne = operator('xor')
Generator.eq = operator('xor', 'lnot')
Generator._and = operator('and')
Generator._or = operator('or')
Generator.xor = operator('xor')

function Generator:neg(expr)
    self:generate(expr[2])
    self:emit('not')
    self:emit('add 1')
end

-- This isn't all exprs, it's just exprs-as-statements
function Generator:expr(expr)
    self:generate(expr[2])
    self:emit('pop')
end

function Generator:id(id)
    local name = id[2]
    local subscript = clause(id, 'subscript')
    -- TODO struct member
    if self.locals and self.locals[name] then
        self:emit('local ' .. self.locals[name])
        if subscript then
            self:generate(subscript)
            self:emit('mul 3')
            self:emit('add')
            self:emit('load24')
        end
    elseif self.globals[name] then
        if subscript then
            self:generate(subscript)
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

function Generator:subscript(sub)
    self:generate(sub[2])
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

    -- So that it leaves whatever the rvalue was on the stack, as a return value
    self:emit('dup')

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

-- ## Function declarations:
function Generator:func(func)
    -- This needs to do three things:
    local name = func[2]
    local args = clause(func, 'args')
    local body = clause(func, 'body')

    assert(not self.globals[name], 'Duplicate declaration for ' .. name)

    -- - First, we need to create an entry in globals containing the label
    --   and arity of the function.
    local label = self:gensym()
    local arity = #args - 1 -- (the first thing is 'args')
    self.globals[name] = { type='function', label=label, arity=arity }

    -- - Next, we need to create a local scope and insert entries into it
    --   for the parameters
    self.locals = {}
    for n = 1, arity do
        self.locals[args[n+1]] = n - 1
    end

    -- - Finally, we need to create a new emitter and replace the current
    --   one, so that when we compile the body statements the code goes to
    --   that emitter.
    local old_emit = self.emit
    self.emit = self.emit_function

    -- Emit a function header:
    self:emit(label .. ':')
    self:emit('frame ' .. arity)

    -- Store the args into their locals:
    for n=(arity-1), 0, -1 do
        self:emit('setlocal ' .. n)
    end

    -- Generate code for the body
    self:generate(body)

    self:emit('ret')
end

function Generator:body(body)
    for n=2, #body do
        local stmt = body[n]
        self:generate(stmt)
        -- Most body statements leave something on the stack that needs to be cleaned up,
        -- but some don't, like ret
        if not (type(stmt) == 'table' and stmt[1] == 'return') then
            self:emit('pop')
        end
    end
end

function Generator:_new(new)
    error('TODO')
end

function Generator:_if(node)
    -- First, we need a label for the end:
    local end_lbl = self:gensym()

    -- and one for the else branch if it exists:
    local else_lbl
    if node[4] then else_lbl = self:gensym() end

    -- Evaluate the condition:
    self:generate(node[2])

    -- If the condition is zero, jmp past the body.
    -- If there's an else, jmp to its label:
    if node[4] then
        self:emit('brz ' .. else_lbl)
    else
        self:emit('brz ' .. end_lbl)
    end

    -- If we're here the condition is nonzero, so evaluate the true side...
    self:generate(node[3])

    -- If there was an else, we now need to skip past it:
    if node[4] then
        -- And jump to the end:
        self:emit('jmp ' .. end_lbl)

        -- The else branch:
        self:emit(else_lbl .. ':')
        self:generate(node[4])
    end

    -- The end label:
    self:emit(end_lbl .. ':')
end

function Generator:_return(ret)
    assert(self.locals, 'Return outside a function')
    local expr = ret[2]
    if expr then
        self:generate(expr)
        self:emit('ret')
    else
        self:emit('ret 0')
    end
end

function Generator:string(str)
    error('TODO')
end

function method_for(name)
    -- Some names aren't viable method names; 'new' because it's
    -- also the constructor, 'if' and 'return' because they're keywords
    if name == 'if' or name == 'new' or name == 'return' or name == 'not' then return '_' .. name end

    -- Some are operators:
    local operators = {
        ['+'] = 'add',
        ['-'] = 'sub',
        ['*'] = 'mul',
        ['/'] = 'div',
        ['%'] = 'mod',
        ['>'] = 'gt',
        ['<'] = 'lt',
        ['<='] = 'le',
        ['>='] = 'ge',
        ['=='] = 'eq',
        ['!='] = 'ne',
        ['&&'] = '_and',
        ['||'] = '_or'
    }

    if operators[name] then return operators[name] end
    return name
end

function clause(node, name)
    for _, child in ipairs(node) do
        if type(child) == 'table' and child[1] == name then
            return child
        end
    end
end

return { compile = compile }
