lpeg = require('lpeg')

-- # Forge Compiler
-- Being a compiler for Forge, a high-level language for the Vulcan computer.

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

    -- Some things can't be used as word names:
    local reserved = {
        [':'] = true, [';'] = true, ['('] = true, [')'] = true
    }

    local sym_id = 0
    local function gensym()
        sym_id = sym_id + 1
        return '_gen_' .. sym_id
    end

    local mode = 'normal'
    local old_mode = nil
    for token, line_num in read(lines) do
        if token == '(' then
            old_mode, mode = mode, 'comment'
        elseif mode == 'comment' then
            if token == ')' then mode = old_mode end
        elseif mode == 'word-name' then
            assert(type(token) ~= 'number' and not reserved[token],
                   'Invalid name \"' .. token .. '\" for new word on line ' .. line_num)
            dictionary[token] = { label = gensym() }
            current_segment = 'words'
            mode = 'word-definition'
            emit(dictionary[token].label .. ':')
        elseif mode == 'word-definition' and token == ';' then
            emit('\tret')
            mode, current_segment = 'normal', 'global'
        else
            if type(token) == 'number' then emit('\tnop\t' .. token)
            elseif token == ':' then mode = 'word-name'
            else
                local def = dictionary[token]
                assert(def, 'Undefined word \"' .. token .. '\" on line ' .. line_num)
                if def.asm then emit('\t' .. def.asm)
                elseif def.label then emit('\t' .. 'call ' .. def.label) end
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
