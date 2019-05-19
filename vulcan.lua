-- ### Purpose
-- This is going to be an emulator / development tool for the Vulcan microcomputer.
-- It will be able to parse assembly files and run them, including an emulation of the
-- video display and keyboard in a window.

-- ### Dependencies
-- To parse Vulcan assembly, we'll need a parser library, so, LPeg:
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

-- # Assembly parser

-- Put this all in a function so we don't have a bunch of
-- stuff in the namespace
function statement_pattern()
    -- First, we want to define some basic patterns. `space` will be any sequence of whitespace,
    -- so we can ignore it easily:
    local space = lpeg.S(" \t")^0

    -- A comment will start with a semicolon and go to the end of the line. Actually everything is parsed
    -- line by line, so anything that starts with a semicolon is a comment:
    local comment = lpeg.P(';') * lpeg.P(1)^0

    -- Numbers are more complicated. We'll support three formats:
    --
    -- - Decimal numbers like 42
    -- - Hexadecimal like 0x2a
    -- - Binary like 0b00101010
    local dec_number = (lpeg.R('19') * lpeg.R('09')^0) / tonumber
    local hex_number = lpeg.P('0x') * lpeg.C(lpeg.R('09','af','AF')^1) / function(s) return tonumber(s, 16) end
    local bin_number = lpeg.P('0b') * lpeg.C(lpeg.S('01')^1) / function(s) return tonumber(s, 2) end
    local number = dec_number + hex_number + bin_number

    -- A label can be any sequence of C-identifier-y characters, as long as it doesn't start with
    -- a digit:
    local label_char = (lpeg.R('az', 'AZ') + lpeg.S('_$'))
    local label = lpeg.C(label_char * (label_char + lpeg.R('09'))^0)

    -- ## Opcodes
    -- An opcode is any one of several possible strings:
    local opcodes = {
        'push', 'nop', 'hlt', 'pop', -- Basic instructions
        'dup', '2dup', 'swap', 'pick', 'height', -- Stack instructions
        'add', 'sub', 'mul', 'div', 'mod', -- Arithmetic instructions
        'and', 'or', 'xor', 'not', 'lshift', 'rshift', 'arshift', -- Logic instructions
        'jmp', 'jmpr', 'call', 'ret', 'brz', 'brnz', 'brgt', 'brlt', -- Branching and jumping
        'load24', 'load16', 'load', 'vload24', 'vload16', 'vload', -- Loading from memory
        'store24', 'store16', 'store', 'vstore24', 'vstore16', 'vstore' -- Storing to memory
    }

    -- Combine the opcodes into one pattern:
    local opcode = lpeg.C(
        table.reduce(
            table.map(opcodes, lpeg.P),
            function(a, b)
                return a+b
            end
    ))

    -- ## Directives
    -- The assembler will support some directives:
    --
    -- - .org to set the current address
    -- - .db to embed some data
    -- - .equ to define some constants
    local directive = lpeg.C(lpeg.P('.org') + lpeg.P('.db') + lpeg.P('.equ'))

    -- The .equ directive isn't much use without the ability to have expressions based on
    -- symbols, so, a quick arithmetic expression parser:
    local expr = lpeg.P{
        'EXPR';
        EXPR = lpeg.Ct( lpeg.Cc('expr') * lpeg.V('TERM') * (lpeg.C( lpeg.S('+-') ) * lpeg.V('TERM'))^0 ),
        TERM = lpeg.Ct( lpeg.Cc('term') * lpeg.V('FACT') * (lpeg.C( lpeg.S('/*%') ) * lpeg.V('FACT'))^0 ),
        FACT = (space * '(' * lpeg.V('EXPR') * ')') + (space * (number + label) * space)
    }

    -- Likewise, .db would get tedious quick without a string syntax, so, let's define one of those. An escape
    -- sequence is a backslash followed by certain other characters:
    local escape = lpeg.C(lpeg.P('\\') * lpeg.S('trns0"\\'))

    -- And a string is a quoted sequence of escapes or other characters:
    local string_pattern = lpeg.Ct(lpeg.Cc('string') * lpeg.P('"') * lpeg.Ct((lpeg.C(lpeg.P(1)-lpeg.S('"\\')) + escape)^1) * '"')

    -- ## Parsing a line
    -- Normally an assembly line will be a sequence of "label, opcode, argument, comment."
    -- However, most of these elements are optional. An opcode is only required if an
    -- argument exists. Comments are parsed but don't capture anything.

    -- Some sub-patterns for the portions of a line:
    local label_group = lpeg.Cc('label') * label * ':'
    local argument_group = lpeg.Cc('argument') * (expr + string_pattern)
    local comment_group = comment

    -- An opcode might be an actual opcode, or a directive
    local opcode_group = lpeg.Cc('opcode') * opcode + lpeg.Cc('directive') * directive
    local instruction_group = opcode_group * space * argument_group^-1

    -- Finally the entire pattern for an assembly line:
    return lpeg.Ct(label_group^-1 * space * instruction_group^-1 * space * comment_group^-1 * lpeg.P(-1))
end

statement = statement_pattern()

-- # Assembler

-- ## First pass
-- Assembly parser. This will take in an iterator from which we can load lines of assembly, and return a
-- list of parsed lines, but with expressions un-evaluated:
function parse_assembly(iterator)
    -- This will store the eventual output
    local lines = {}

    -- A count of the line number
    local line_num = 1

    -- Parse each line, throw out all the semantically blank ones:
    for line in iterator do
        local ast = statement:match(line)

        -- If we weren't able to parse it, blow up:
        if ast == nil then
            error('Parse error on line ' .. line_num .. ': ' .. string.format('%q', line))
        end

        -- If it parsed to a null statement (nothing but a comment / whitespace)
        -- then just skip it:
        if #ast > 0 then
            -- Otherwise, start by converting it to a more useful key/value format,
            -- and embed the line number in it while we're at it:
            local obj = { line=line_num }
            for n = 1, #ast, 2 do
                obj[ast[n]] = ast[n+1]
            end

            -- We'll identify two possible errors here, just because we can: if a line
            -- has a string argument and it _isn't_ a `.db` directive, then that's a
            -- syntax error and we'll say so:
            if obj.argument and obj.argument[1] == 'string' and obj.directive ~= '.db' then
                error('String argument outside .db directive on line ' .. line_num)
            end

            -- Also, a .equ without a label or argument makes no sense, so we'll error
            -- on that as well:
            if obj.directive == '.equ' and (obj.argument == nil or obj.label == nil) then
                error('.equ directive missing label or argument on line' .. line_num)
            end

            -- Tack it on to the list of actual lines:
            table.insert(lines, obj)
        end

        -- Next line number:
        line_num = line_num + 1
    end

    return lines
end

-- ## Evaluating expressions
-- Now that we have a parsed file, that file has a bunch of numeric symbols in it: labels,
-- .equ directives, that sort of thing. We need to resolve all of those to constant values
-- before we can generate code. So, first part of that is being able to evaluate expressions.

-- Evaluate an expression in the context of a symbol table:
function evaluate(expr, symbols)
    -- The bottom of a parse tree, just return a number
    if type(expr) == 'number' then
        return expr

        -- A symbol that had better be defined
    elseif type(expr) == 'string' then
        if symbols[expr] then return symbols[expr]
        else error('Symbol not defined: ' .. expr) end

        -- This is a list of terms separated by arithmetic operators. So,
        -- evaluate the first one...
    elseif expr[1] == 'expr' or expr[1] == 'term' then
        local val = evaluate(expr[2], symbols)

        -- Then go through the list two at a time...
        for i = 3, #expr, 2 do
            local operator = expr[i]
            -- Evaluating the rest...
            local rhs = evaluate(expr[i+1], symbols)
            -- And adding or subtracting them or whatever
            if operator == '+' then
                val = val + rhs
            elseif operator == '-' then
                val = val - rhs
            elseif operator == '*' then
                val = val * rhs
            elseif operator == '/' then
                -- Lua has floating point division, but Vulcan will only support integer
                -- truncating division
                val = math.floor(val / rhs)
            elseif operator == '%' then
                val = val % rhs
            end
        end
        return val
    end
end

-- Return a list of all symbols referenced by this expression:
function references(expr)
    -- A set (map from name to 'true') of all references
    refs = {}

    -- A helper function to do the recursion
    local function search(e)
        -- If it's a reference, then add it to the 
        if type(e) == 'string' then refs[e] = true
            -- Otherwise we need to recurse on a sub-tree:
        elseif type(e) == 'table' then
            search(e[2])
            for i = 4, #e, 2 do search(e[i]) end
        end
    end

    -- Convert refs to a list:
    local ref_list = {}
    for k, _ in pairs(refs) do table.insert(ref_list, k) end
    return ref_list
end

-- ## Second pass
-- This will solve all the .equ directives and return a symbol table of them.
-- .equ directives must be able to be solved in order, that is, in terms of
-- only preceding .equ directives. Anything else is an error.
function solve_equs(lines)
    local symbols = {}

    for _, line in ipairs(lines) do
        -- Is this a .equ?
        if line.directive == '.equ' then
            -- Try to solve it with what we know so far:
            local success, ret = pcall(evaluate, line.argument, symbols)
            -- Put it in the symbols, or blow up:
            if success then
                symbols[line.label] = ret
            else
                error('Cannot resolve .equ on line ' .. line.line .. ': ' .. ret)
            end
        end
    end

    return symbols
end

-- ## Third pass
-- We need to figure out the instruction lengths. We'll do this naively; if we can't
-- immediately tell that an instruction needs only a 0/1/2 byte argument (because it's
-- a constant, or a .equ that we've solved, or something) then we'll assume it's a
-- full 24-bit argument.
function measure_instructions(lines, symbols)
    for _, line in ipairs(lines) do
        -- Does this even represent any real output bytes?
        if not(line.opcode or line.directive == '.db') then
            line.length = 0
        elseif line.directive == '.db' then
            -- .dbs with string arguments, we know the length.
            -- Else, set aside 3 bytes for a number. (Even if it fits in fewer,
            -- it may be a variable that we're setting aside space for)
            if line.argument[1] == 'string' then
                line.length = #(line.argument[2])
            else
                line.length = 3
            end
        elseif line.opcode then
            -- If it has no argument, then it's only one byte obviously
            if not line.argument then
                line.length = 1
            else
                -- Evaluate the argument, if we can with just .equs:
                local success, val = pcall(evaluate, line.argument, symbols)
                -- If we failed to do that, then let's just set aside the
                -- full 24 bits:
                if not success then line.length = 4
                else
                    -- Otherwise let's see what we got. If it's less than 256,
                    -- it fits in a byte, and so on:
                    if val < 256 then line.length = 2
                    elseif val < 65536 then line.length = 3
                    else line.length = 4 end
                end
            end
        end
    end
end

-- -- We want to calculate where the labels are, as the first step in calculating the values of
-- -- all the symbols. 
-- -- is less than four bytes, then we'll assume it's four bytes.
-- function calculate_labels(lines)
--     local address = 0
--     -- Go through each line...
--     for _, line in ipairs(lines) do
--         -- If the line is a .org directive, then we evaluate the argument as a constant,
--         -- 
--     end

--     return dependencies
-- end

return {
    statement=statement,
    parse_assembly=parse_assembly,
    evaluate=evaluate,
    solve_equs=solve_equs,
    measure_instructions=measure_instructions
}
