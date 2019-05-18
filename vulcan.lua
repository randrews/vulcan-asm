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
        TERM = lpeg.Ct( lpeg.Cc('term') * lpeg.V('FACT') * (lpeg.C( lpeg.S('/*') ) * lpeg.V('FACT'))^0 ),
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

return statement
