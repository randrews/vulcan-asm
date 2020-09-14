lpeg = require('lpeg')

-- # Forge Compiler
-- Being a compiler for Forge, a high-level language for the Vulcan computer.

-- ## Utilities

function table.new() return  end
function table:index(needle)
    for i, v in ipairs(self) do
        if v == needle then return i end
    end
end
function table:rfind(pred)
    for i = #self, 1, -1 do
        if pred(self[i]) then return self[i] end
    end
end

-- Some things can't be used as word names:
local reserved = {
    [':'] = true, [';'] = true, ['('] = true, [')'] = true, ['if'] = true, ['else'] = true, ['then'] = true
}

-- ## Parser

-- This iterates over the tokens and line numbers in a file.
-- Pass in an iterator over lines of source (like from io.lines) and
-- successive calls will yield successive tokens.
function read(lines)
    -- We store the current line number, the current column in that line, and the current line
    local line_num = 1
    local start = 1
    local line = lines()

    -- This handles turning tokens that look like numbers into actual numbers:
    -- - Decimals with an optional leading minus sign
    -- - Hex with a leading `0x`
    -- - Binary with a leading `0b`
    local function parse_number(token)
        if token:match('^[-]?%d+$') then return tonumber(token)
        elseif token:match('^0x([%da-fA-F]+)$') then return tonumber(token:sub(3), 16)
        elseif token:match('^0b([01]+)$') then return tonumber(token:sub(3), 2)
        else return token end
    end

    return function()
        while true do
            -- Try to match a token: throw away any leading spaces, grab the next word,
            -- and then the current position. Start at the current start column
            local token, after = line:match('^%s*(%g+)()', start)
            if token then
                -- If we grabbed something, then update the start column, try to see if
                -- it's a number, and then return it and the current line
                start = after
                return parse_number(token), line_num
            else
                -- Otherwise this line has no more tokens. Increment the line number,
                -- reset start, and grab a new line. Because we're in a loop this will
                -- just try again on the next line...
                line_num = line_num + 1
                start = 1
                line = lines()
                -- ...Unless there is no next line. In which case we break out of the
                -- loop and return nil.
                if not line then break end
            end
        end
    end
end

-- ## Compiler
-- Turn an iterator of source lines into a sequence of assembly lines, which will be passed
-- to `final_emit`
function compile(lines, final_emit)
    -- We have three segments in the program:
    --
    -- - Global, which gets emitted first and is all the expressions in the global context, followed by an implicit hlt
    -- - Words, emitted second and are all the functions
    -- - Variables, emitted last and containing the labels and .db's for variables (all initialized to 0, the initializers
    --   run where the declaration was, in text)
    local segments = { global = {}, words = {}, variables = {} }

    -- The "compiler state," which can be passed to token and mode handlers and allow them to
    -- do anything they might want the compiler to do
    local state = {
        comment_start_line = nil, -- For line comments to konw when the line has ended
        current_frame_size = 0, -- For things that create local variables to know which indices to add
        current_segment = 'global', -- Which segment we're emitting code to
        name_type = nil, -- For `read_name`
        name_handler = nil,
        string_words = {}, -- For string mode

        -- A stack of currently-open control structures. Each contains, at the least, a `type`
        -- and a `line` field
        controls = setmetatable({}, {__index = table}),

        -- The dictionary of locals; all locals are just mapping a name to a stack-frame-index
        local_dictionary = {},

        -- The dictionary, which initially has only the primitive words in it: an entry here contains either a label or
        -- an opcode, and tells us how to handle each word. Initially all the words in it will be the single-opcode primitives:
        dictionary = {
            ['+'] = { asm = 'add' }, ['-'] = { asm = 'sub' }, ['*'] = { asm = 'mul' }, ['/'] = { asm = 'div' }, mod = { asm = 'mod' },
            drop = { asm = 'pop' }, dup = { asm = 'dup' }, ['2dup'] = { asm = '2dup' }, swap = { asm = 'swap' },
            ['and'] = { asm = 'and' }, ['or'] = { asm = 'or' }, xor = { asm = 'xor' },
            ['>'] = { asm = 'agt' }, ['<'] = { asm = 'alt' },
            ['@'] = { asm = 'load24' }, ['!'] = { asm = 'store24' }, ['!b'] = { asm = 'store' },
            inton = { asm = 'inton' }, intoff = { asm = 'intoff' }
        }
    }

    -- A stack of compiler modes, which affect how the next word is handled
    local mode_stack = setmetatable({'default'}, {__index = table})
    function state.mode() return mode_stack[#mode_stack] end
    function state.push_mode(mode) mode_stack:insert(mode) end
    function state.pop_mode() return mode_stack:remove() end

    -- This generates unique names for assembly labels
    local sym_id = 0
    function state.gensym()
        sym_id = sym_id + 1
        return '_gen' .. sym_id
    end

    -- Return the top control structure, optionally of one of the passed-in
    -- types
    function state.top_control(...)
        local types = {...}
        if #types > 0 then
            return state.controls:rfind(function(ctrl) return table.index(types, ctrl.type) end)
        else return state.controls[#state.controls] or {} end
    end

    -- Treat the next token as a name, and pass it (and the state) to a handler function
    -- (after returning to whatever the original mode was)
    function state.read_name(name_type, name_handler)
        state.name_type, state.name_handler = name_type, name_handler
        state.push_mode('name')
    end

    -- Emit a line of assembly to a segment (or the current segment)
    function state.emit(line, segment)
        table.insert(segments[segment or state.current_segment], line)
    end

    -- ### Main Loop
    -- Loop over each token in the source, and handle them
    for token, line_num in read(lines) do
        state.line_num = line_num

        -- Also detect the end of a line-comment
        if state.mode() == 'line_comment' and state.line_num ~= state.comment_start_line then
            state.pop_mode()
        end

        -- Comment stuff: detect comment opening tokens, and change the mode
        if state.mode() ~= 'string' then
            if token == '\\' and state.mode() ~= 'line_comment' then
                state.comment_start_line = state.line_num
                state.push_mode('line_comment')
            elseif token == '(' then
                state.push_mode('comment')
            end
        end

        -- Mode stuff: everything else we do depends on our mode. We'll check
        -- the table of mode handlers for our current mode and see if it can
        -- handle this token. If not, then the default behavior fires
        if type(modes[state.mode()]) == 'function' then
            modes[state.mode()](token, state)
        elseif type(modes[state.mode()]) == 'table' and modes[state.mode()][token] then
            modes[state.mode()][token](state)
        else
            modes.default(token, state)
        end        
    end

    -- Helper for emitting an entire segment to the final output at once
    local function emit_segment(segment)
        for _, line in ipairs(segment) do final_emit(line) end
    end

    -- Emit all of the global segment followed by a hlt
    -- If there are any words or variables, emit those too.
    -- They don't need hlts because words will automatically return
    -- and globals never get jumped to.
    final_emit('\t.org\t0x100')
    emit_segment(segments.global)
    final_emit('\thlt')
    emit_segment(segments.words)
    emit_segment(segments.variables)
end

-- ## Mode handlers

-- The compiler treats words differently depending on what mode it's in.
-- This table contains either functions, which are called with a word and a
-- compiler state, or a table of words -> functions.
modes = {}

-- ### Default behavior:
-- If nothing else tells us differently, we do this to handle numbers, words
-- defined in the dictionary, etc

function modes.default(token, state)
    if type(token) == 'number' then
        state.emit('\tnop\t' .. token)
    elseif token == ':' then
        state.read_name('word',
                        function(name, state)
                            assert(not state.dictionary[name], 'Reused name \"' .. name .. '\" on line ' .. state.line_num)
                            -- Put it in the dictionary and change our mode and segment
                            state.dictionary[name] = { label = state.gensym() }
                            state.push_mode('word_definition')
                            state.current_segment = 'words'
                            -- Emit a label for the entry point of this function
                            state.emit(state.dictionary[name].label .. ':')
                            state.local_dictionary, state.current_frame_size = {}, 0
                        end
        )
    elseif token == 'variable' then
        state.read_name('variable',
                        function(name, state)
                            assert(not state.dictionary[name], 'Reused name \"' .. name .. '\" on line ' .. state.line_num)
                            -- Put it in the dictionary and change our mode and segment
                            state.dictionary[name] = { variable = state.gensym() }
                            -- Emit a label and .db for the variable
                            state.emit(state.dictionary[name].variable .. ':\t.db 0', 'variables')
                        end
        )
    elseif token == 'setiv' then
        state.read_name('word',
                        function(name, state)
                            assert(state.dictionary[name] and state.dictionary[name].label,
                                   'Undefined word \"' .. name .. '\" set as interrupt vector on line ' .. state.line_num)
                            state.emit('\tsetiv\t' .. state.dictionary[name].label)
                        end
        )
    elseif state.local_dictionary[token] then
        state.emit('\tnop\t' .. state.local_dictionary[token])
    elseif token == '"' then
        state.push_mode('string')
    else
        local def = state.dictionary[token]
        assert(def,
               'Undefined word \"' .. token .. '\" on line ' .. state.line_num)
        if def.asm then state.emit('\t' .. def.asm)
        elseif def.label then state.emit('\t' .. 'call\t' .. def.label)
        elseif def.variable then state.emit('\tnop\t' .. def.variable) end
    end
end

-- ### Comment behaviors

-- Region comments go until a close paren
function modes.comment(token, state)
    if token == ')' then state.pop_mode() end
end

-- We're already handling these ending before the mode check; this
-- just tells us to ignore all tokens inside a comment
function modes.line_comment() end

-- ### Strings
function modes.string(token, state)
    if token == '"' then
        local str = table.concat(state.string_words, ' '):gsub('\\', '\\\\'):gsub('"', '\\"') .. '\\0'
        local label = state.gensym()
        state.emit(string.format('%s:\t.db\t"%s"', label, str), 'variables')
        state.emit('\tnop\t' .. label)
        state.string_words = {}
        state.pop_mode()
    else
        table.insert(state.string_words, token)
    end
end

-- ### Names
-- Names all basically work the same: when we see a token that we know is
-- followed by a name, we push the `name` mode and set a name handler and
-- name type in the state. The `name` mode reads any token, checks that it's
-- a valid name, then pops the mode and calls the handler.

function modes.name(token, state)
    local valid = type(token) ~= 'number' and not reserved[token]
    assert(valid, 'Invalid name \"' .. token .. '\" for ' .. state.name_type .. ' on line ' .. state.line_num)
    state.pop_mode()
    state.name_handler(token, state)
end

-- ### Word definitions
-- This is a table of all the special tokens we might see inside a word
-- definition. Anything not in this table will fall through to the default
-- handler

modes.word_definition = {}

-- First off, we want to disallow nesting word definitions
modes.word_definition[':'] = function(state)
    error('Already defining a word on line ' .. state.line_num)
end

-- This is how you end a word definition
modes.word_definition[';'] = function(state)
    -- First check we're not leaving any open blocks
    if #state.controls > 0 then
        error('Unclosed `' .. state.controls[1].type .. '` on line ' .. state.controls[1].line)
    end
    -- To end a word, emit a return and reset our mode and segment
    state.emit('\tret')
    state.pop_mode()
    state.current_segment = 'global'
end

-- ### Conditionals
-- `if` / `else` / `then` are the conditional construct in Forge. `if` consumes
-- the top of the stack, and if it's zero, jumps to the matching `else` or
-- `then`.
modes.word_definition['if'] = function(state)
    state.controls:insert{ type = 'if', line = state.line_num, after = state.gensym() }
    state.emit('\tbrz\t@' .. state.controls[#state.controls].after)
end

-- `else` is the jump target if the condition is false (if it's provided).
-- First we make sure that we're actually in an `if`, and that there's not
-- already an `else` for it. Then we splice ourselves into that control structure
modes.word_definition['else'] = function(state)
    assert(state.top_control().type == 'if',
           '`else` outside `if` on line ' .. state.line_num)
    assert(not state.top_control().has_else,
           'Extra `else` on line ' .. state.line_num)
    local top = state.top_control()
    local old_after = top.after
    top.after, top.has_else = state.gensym(), true
    state.emit('\tjmpr\t@' .. state.top_control().after)
    state.emit(old_after .. ':')
end

-- `then` is the end of an `if` / `else`: we just need to emit a label to
-- jump to and pop the control stack.
modes.word_definition['then'] = function(state)
    assert(state.top_control().type == 'if',
           '`then` outside `if` on line ' .. state.line_num)
    state.emit(state.top_control().after .. ':')
    state.controls:remove(#state.controls)
end

-- ### Loops
-- There are three kinds of loops: an infinite loop using `begin` / `again`,
-- a while loop using `begin` / `while` / `again`, and a counted `for` loop.
-- The first two start with `begin`, which just needs to push a control
-- structure and emit a jump target for the `again`
function modes.word_definition.begin(state)
    state.controls:insert{ type = 'begin', line = state.line_num, start = state.gensym(), after = state.gensym() }
    state.emit(state.top_control().start .. ':')
end

-- `again` just inserts a jump to the matching `begin` and pops the control stack
function modes.word_definition.again(state)
    assert(state.top_control().type == 'begin',
           '`again` outside `begin` on line ' .. state.line_num)
    state.emit('\tjmpr\t@' .. state.top_control().start)
    state.emit(state.top_control().after .. ':')
    state.controls:remove(#state.controls)
end

-- All loops allow a `break` statement to jump immediately to the end of the loop
modes.word_definition['break'] = function(state)
    assert(state.top_control('begin', 'for'),
           '`break` outside loop on line ' .. state.line_num)
    state.emit('\tjmpr\t@' .. state.top_control('begin', 'for').after)
end

-- `while` can be inserted anywhere in a `begin` loop, and will exit the loop if
-- the top of stack is zero.
modes.word_definition['while'] = function(state)
    assert(state.top_control().type == 'begin',
           '`while` outside loop on line ' .. state.line_num)
    state.emit('\tbrz\t@' .. state.top_control().after)
end

-- ### For loops
-- A `for` loop consumes the lower and upper limits of the loop and is followed
-- by a variable name for the counter. It runs the loop body (until the matching
-- `loop`) for every value in the range (inclusive). The counter is a local
-- variable visible only in the loop body.
-- To compile this, we create a counter variable set to the lower bound, and an
-- anonymous local variable set to the upper bound. We emit a label for `loop` to
-- jump to and then compare the counter to the upper bound
modes.word_definition['for'] = function(state)
    state.read_name('for',
                    function(name, state)
                        -- Put it in the dictionary and change our frame size
                        -- Incrementing by two to store the upper limit also
                        state.local_dictionary[name], state.current_frame_size = state.current_frame_size, state.current_frame_size + 2
                        state.emit('\tframe\t' .. state.current_frame_size)
                        -- Push a control
                        state.controls:insert{ type = 'for', line = state.line_num, start = state.gensym(), after = state.gensym(), limit = state.current_frame_size - 1, counter = name }
                        -- Set counter to the start value and limit to the end value
                        state.emit('\tsetlocal\t' .. state.local_dictionary[name])
                        state.emit('\tsetlocal\t' .. state.top_control().limit)
                        -- Start of loop label
                        state.emit(state.top_control().start .. ':')
                        -- Check if the counter > limit, brz to after:
                        state.emit('\tlocal\t' .. state.local_dictionary[name])
                        state.emit('\tlocal\t' .. state.top_control().limit)
                        state.emit('\tadd\t' .. 1)
                        state.emit('\tsub')
                        state.emit('\tbrz\t@' .. state.top_control().after)
                    end
    )
end

-- `loop` ends a `for` loop: it increments the counter and then jumps to the start
-- of the loop.
function modes.word_definition.loop(state)
    assert(state.top_control().type == 'for',
           '`loop` outside `for` on line ' .. state.line_num)
    -- Increment the counter and jump back to start
    state.emit('\tlocal\t' .. state.local_dictionary[state.top_control().counter])
    state.emit('\tadd\t1')
    state.emit('\tsetlocal\t' .. state.local_dictionary[state.top_control().counter])
    state.emit('\tjmpr\t@' .. state.top_control().start)
    -- The after label
    state.emit(state.top_control().after .. ':')
    -- Remove the counter variable
    state.local_dictionary[state.top_control().counter] = nil
    -- Shrink the stack size back (it might matter)
    state.current_frame_size = state.current_frame_size - 2
    state.emit('\tframe\t' .. state.current_frame_size)
    state.controls:remove(#state.controls)
end

-- ### Local variables
-- Locals have syntax almost exactly like global variables, but use the `local` and
-- `setlocal` instructions instead of `load` and `store`.
modes.word_definition['local'] = function(state)
    state.read_name('local',
                    function(name, state)
                        assert(not state.local_dictionary[name], 'Reused name \"' .. name .. '\" on line ' .. state.line_num)
                        -- Put it in the dictionary and change our frame size and mode
                        state.local_dictionary[name], state.current_frame_size = state.current_frame_size, state.current_frame_size + 1
                        state.emit('\tframe\t' .. state.current_frame_size)
                    end
    )
end

-- since these are only usable inside word definitions, they're handled here instead
--  of in the dictionary, even though all they do is emit one instruction
modes.word_definition[':@'] = function(state)
    state.emit('\tlocal')
end

modes.word_definition[':!'] = function(state)
    state.emit('\tsetlocal')
end

return { read = read, compile = compile }
