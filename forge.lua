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

function compile(lines, final_emit)
    -- We have three segments in the program:
    --
    -- - Global, which gets emitted first and is all the expressions in the global context, followed by an implicit hlt
    -- - Words, emitted second and are all the functions
    -- - Variables, emitted last and containing the labels and .db's for variables (all initialized to 0, the initializers
    --   run where the declaration was, in text)
    local segments = { global = {}, words = {}, variables = {} }
    local current_segment = 'global'
    local function emit(line, segment)
        table.insert(segments[segment or current_segment], line)
    end

    -- The dictionary, which initially has only the primitive words in it: an entry here contains either a label or
    -- an opcode, and tells us how to handle each word. Initially all the words in it will be the single-opcode primitives:
    local dictionary = {
        ['+'] = { asm = 'add' }, ['-'] = { asm = 'sub' }, ['*'] = { asm = 'mul' }, ['/'] = { asm = 'div' }, mod = { asm = 'mod' },
        drop = { asm = 'pop' }, dup = { asm = 'dup' }, ['2dup'] = { asm = '2dup' }, swap = { asm = 'swap' },
        ['and'] = { asm = 'and' }, ['or'] = { asm = 'or' }, xor = { asm = 'xor' },
        ['>'] = { asm = 'agt' }, ['<'] = { asm = 'alt' },
        ['@'] = { asm = 'load24' }, ['!'] = { asm = 'store24' }
    }

    -- The dictionary of locals; all locals are just mapping a name to a stack-frame-index
    local local_dictionary = {}

    -- Some things can't be used as word names:
    local reserved = {
        [':'] = true, [';'] = true, ['('] = true, [')'] = true, ['if'] = true, ['else'] = true, ['then'] = true
    }

    local sym_id = 0
    local function gensym()
        sym_id = sym_id + 1
        return '_gen_' .. sym_id
    end

    local mode = nil
    local old_mode = nil
    local comment_start_line = nil
    local current_frame_size = 0

    -- A stack of currently-open control structures. Each contains, at the least, a `type`
    -- and a `line` field
    local controls = setmetatable({}, {__index = table})
    local function top_control(...)
        local types = {...}
        if #types > 0 then
            return controls:rfind(function(ctrl) return table.index(types, ctrl.type) end)
        else return controls[#controls] or {} end
    end

    -- A table of functions that get called for every token depending on
    -- the mode. If the corresponding function returns true, then it was
    -- able to handle the token; otherwise, pass it through to the default
    -- behavior.
    local modes = {
        comment = function(token)
            -- Region comments go until a close paren
            if token == ')' then mode = old_mode end
            return true
        end,

        -- We're already handling this before the mode check
        line_comment = function() return true end,

        word_name = function(token, line_num)
            -- Ensure it's a valid name
            assert(type(token) ~= 'number' and not reserved[token],
                   'Invalid name \"' .. token .. '\" for new word on line ' .. line_num)
            -- Put it in the dictionary and change our mode and segment
            dictionary[token] = { label = gensym() }
            mode, current_segment = 'word_definition', 'words'
            -- Emit a label for the entry point of this function
            emit(dictionary[token].label .. ':')
            return true
        end,

        word_definition = function(token, line_num)
            if token == ':' then error('Already defining a word on line ' .. line_num)
            elseif token == 'if' then
                controls:insert{ type = 'if', line = line_num, after = gensym() }
                emit('\tbrz\t@' .. controls[#controls].after)
                return true
            elseif token == 'else' then
                assert(top_control().type == 'if',
                       '`else` outside `if` on line ' .. line_num)
                assert(not top_control().has_else,
                       'Extra `else` on line ' .. line_num)
                local top = top_control()
                local old_after = top.after
                top.after, top.has_else = gensym(), true
                emit('\tjr\t@' .. top_control().after)
                emit(old_after .. ':')
                return true
            elseif token == 'then' then
                assert(top_control().type == 'if',
                       '`then` outside `if` on line ' .. line_num)
                emit(top_control().after .. ':')
                controls:remove(#controls)
                return true
            elseif token == 'begin' then
                controls:insert{ type = 'begin', line = line_num, start = gensym(), after = gensym() }
                emit(top_control().start .. ':')
                return true
            elseif token == 'break' then
                assert(top_control('begin', 'for'),
                       '`break` outside loop on line ' .. line_num)
                emit('\tjr\t@' .. top_control('begin', 'for').after)
                return true
            elseif token == 'while' then
                assert(top_control().type == 'begin',
                       '`while` outside loop on line ' .. line_num)
                emit('\tbrz\t@' .. top_control().after)
                return true
            elseif token == 'again' then
                assert(top_control().type == 'begin',
                       '`again` outside `begin` on line ' .. line_num)
                emit('\tjr\t@' .. top_control().start)
                emit(top_control().after .. ':')
                controls:remove(#controls)
                return true
            elseif token == 'local' then
                mode, old_mode = 'local_name', mode
                return true
            elseif token == ':@' then
                emit('\tlocal')
                return true
            elseif token == ':!' then
                emit('\tsetlocal')
                return true
            elseif token == 'for' then
                mode, old_mode = 'for_name', mode
                return true
            elseif token == 'loop' then
                assert(top_control().type == 'for',
                       '`loop` outside `for` on line ' .. line_num)
                -- Increment the counter and jump back to start
                emit('\tlocal\t' .. local_dictionary[top_control().counter])
                emit('\tadd\t1')
                emit('\tsetlocal\t' .. local_dictionary[top_control().counter])
                emit('\tjr\t@' .. top_control().start)
                -- The after label
                emit(top_control().after .. ':')
                -- Remove the counter variable
                local_dictionary[top_control().counter] = nil
                -- Shrink the stack size back (it might matter)
                current_frame_size = current_frame_size - 2
                emit('\tframe\t' .. current_frame_size)
                controls:remove(#controls)
                return true
            elseif token == ';' then
                -- First check we're not leaving any open blocks
                if #controls > 0 then
                    error('Unclosed `' .. controls[1].type .. '` on line ' .. controls[1].line)
                end
                -- To end a word, emit a return and reset our mode and segment
                emit('\tret')
                mode, current_segment = nil, 'global'
                return true
            end
        end,

        variable_name = function(token, line_num)
            -- Ensure it's a valid name
            assert(type(token) ~= 'number' and not reserved[token],
                   'Invalid name \"' .. token .. '\" for variable on line ' .. line_num)
            -- Put it in the dictionary and change our mode and segment
            dictionary[token] = { variable = gensym() }
            -- Emit a label and .db for the variable
            emit(dictionary[token].variable .. ':\t.db 0', 'variables')
            mode = old_mode
            return true
        end,

        local_name = function(token, line_num)
            -- Ensure it's a valid name
            assert(type(token) ~= 'number' and not reserved[token],
                   'Invalid name \"' .. token .. '\" for local on line ' .. line_num)
            -- Ensure it's unused
            assert(not local_dictionary[token],
                   'Reused name \"' .. token .. '\" for local on line ' .. line_num)
            -- Put it in the dictionary and change our frame size and mode
            local_dictionary[token], current_frame_size, mode = current_frame_size, current_frame_size + 1, old_mode
            emit('\tframe\t' .. current_frame_size)
            return true
        end,

        for_name = function(token, line_num)
            -- Ensure it's a valid name
            assert(type(token) ~= 'number' and not reserved[token],
                   'Invalid name \"' .. token .. '\" for local on line ' .. line_num)
            -- Ensure it's unused
            assert(not local_dictionary[token],
                   'Reused name \"' .. token .. '\" for local on line ' .. line_num)
            -- Put it in the dictionary and change our frame size
            -- Incrementing by two to store the upper limit also
            local_dictionary[token], current_frame_size, mode = current_frame_size, current_frame_size + 2, old_mode
            emit('\tframe\t' .. current_frame_size)
            -- Push a control
            controls:insert{ type = 'for', line = line_num, start = gensym(), after = gensym(), limit = current_frame_size - 1, counter = token }
            -- Set counter to the start value and limit to the end value
            emit('\tsetlocal\t' .. local_dictionary[token])
            emit('\tsetlocal\t' .. top_control().limit)
            -- Start of loop label
            emit(top_control().start .. ':')
            -- Check if the counter == limit, brz to after:
            emit('\tlocal\t' .. local_dictionary[token])
            emit('\tlocal\t' .. top_control().limit)
            emit('\tsub')
            emit('\tbrz\t@' .. top_control().after)
            return true
        end
    }

    for token, line_num in read(lines) do
        -- Comment stuff: detect comment opening tokens, and change the mode
        if token == '\\' then
            comment_start_line, old_mode, mode = line_num, mode, 'line_comment'
        elseif token == '(' then
            old_mode, mode = mode, 'comment'
        end

        -- Also detect the end of a line-comment
        if mode == 'line_comment' and line_num ~= comment_start_line then
            mode = old_mode
        end

        -- Mode stuff: everything else we do depends on our mode. We'll check
        -- the table of mode handlers for our current mode and see if it can
        -- handle this token. If not, then the default behavior fires
        if not modes[mode] or not modes[mode](token, line_num) then
            if type(token) == 'number' then
                emit('\tnop\t' .. token)
            elseif token == ':' then
                mode = 'word_name'
                local_dictionary, current_frame_size = {}, 0
            elseif token == 'variable' then
                old_mode, mode = mode, 'variable_name'
            elseif local_dictionary[token] then
                emit('\tnop\t' .. local_dictionary[token])
            else
                local def = dictionary[token]
                assert(def,
                       'Undefined word \"' .. token .. '\" on line ' .. line_num)
                if def.asm then emit('\t' .. def.asm)
                elseif def.label then emit('\t' .. 'call\t' .. def.label)
                elseif def.variable then emit('\tnop\t' .. def.variable) end
            end
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
    emit_segment(segments.global)
    final_emit('\thlt')
    emit_segment(segments.words)
    emit_segment(segments.variables)
end

return { read = read, compile = compile }
