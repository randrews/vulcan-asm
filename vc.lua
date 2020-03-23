lpeg = require('lpeg')

-- # Vulcan Compiler
-- Being a compiler for an un-named high level language for the Vulcan computer.

-- ## Language design

-- ### Statements and expressions
-- A Vulcan program is a series of statements. A statement can be any of:
--
-- - An assignment
-- - A variable declaration
-- - A struct declaration
-- - A preprocessor directive
-- - An expression

-- An expression can be any of:
--
-- - A mathematical expression like `2+3*(4-1)`
-- - A function call like `foo(2, 34)`
-- - A identifier like `blah`
-- - A string like `"Hello\n"`
-- - An address reference like `@{blah + 3}`
-- - A function declaration like `lambda {|x| x*x}`
-- - A struct reference like `player.x`
-- - An array reference like `coords[3]`

-- Variables in Vulcan all have the same type: they are a single Vulcan word long (24 bits).
-- Any data type that can be longer than a single word (a function, an array, string, etc) is
-- stored as a variable containing the address of the first byte.

-- ### Assignment statements
-- An assignment statement conists of an lvalue, which must evaluate to an address, and an
-- rvalue, which evaluates to a word, separated by the assignment operator `=`.

-- Valid lvalues are:
--
-- - Any address reference: `@{blah + 3}`
-- - Any array reference: `blah[3]` (being equivalent to the above address reference)
-- - Any identifier name: `foo` (being equivalent to an address reference `@{foo}`)
-- - Any struct member reference: `foo.blah`

-- Valid rvalues are any expression

-- ### Variable declarations
-- Variables must be declared before being used.
--
-- - Variable declarations can declare a variable as a word: `var foo`
-- - As an array of words: `var foo[10]`
-- - As an instance of a struct: `struct Player p`
-- - As a string: `string name(64)`

-- ## Parser

-- Identify whitespace: spaces and tabs
local space = lpeg.S(" \t\n")^0

-- Identifiers are any sequence of letters, digits, underscores, or dollar signs, not starting with a digit
local identifier = (function()
        local identifier_char = (lpeg.R('az', 'AZ') + lpeg.S('_$'))
        return lpeg.C(identifier_char * (identifier_char + lpeg.R('09'))^0) end)()

function expr_pattern()
    -- A number can be expressed in decimal, binary, or hex
    local number = (function()
            local dec_number = (lpeg.S('-')^-1 * lpeg.R('19') * lpeg.R('09')^0) / tonumber
            local hex_number = lpeg.P('0x') * lpeg.C(lpeg.R('09','af','AF')^1) / function(s) return tonumber(s, 16) end
            local bin_number = lpeg.P('0b') * lpeg.C(lpeg.S('01')^1) / function(s) return tonumber(s, 2) end
            local dec_zero = lpeg.P('0') / tonumber
            return dec_number + hex_number + bin_number + dec_zero end)()

    -- A string is a quoted sequence of escapes or other characters:
    local string_pattern = (function()
            local escape = lpeg.C(lpeg.P('\\') * lpeg.S('trn0"\\'))
            return lpeg.Ct(lpeg.Cc('string') * lpeg.P('"') * lpeg.Ct((lpeg.C(lpeg.P(1)-lpeg.S('"\\')) + escape)^1) * '"') end)()

    -- An expression is a mathematical expression with parens or the standard five operators, with the atoms being:
    --
    -- - numbers
    -- - identifiers
    -- - strings
    -- - array references
    -- - struct references
    -- - function calls
    -- - memory references
    -- - assignments
    -- - conditionals
    return lpeg.P{
        'EXPR';
        EXPR = lpeg.Ct( lpeg.Cc('expr') * space * (lpeg.V('TERM') * (lpeg.C( lpeg.S('+-') ) * lpeg.V('TERM'))^0) * lpeg.S(';')^-1 ),
        TERM = lpeg.Ct( lpeg.Cc('term') * space * lpeg.V('FACT') * (lpeg.C( lpeg.S('/*%') ) * lpeg.V('FACT'))^0 ),
        FACT = space * (
            '(' * lpeg.V('EXPR') * ')' +
                lpeg.V('NEW') +
                lpeg.V('ASSIGN') +
                number +
                lpeg.V('SHORTCOND') +
                lpeg.V('NAME') +
                lpeg.V('ADDRESS') +
                string_pattern) * space,

        NAME = lpeg.Ct( lpeg.Cc('id') * identifier * (lpeg.V('SUBSCRIPT') + lpeg.V('PARAMS') + lpeg.V('MEMBER'))^-1 ),
        SUBSCRIPT = lpeg.Ct( lpeg.Cc('subscript') * space * '[' * lpeg.V('EXPR') * ']' ),
        PARAMS = lpeg.Ct( lpeg.Cc('params') * space * (('(' * space * ')') + ('(' * lpeg.V('EXPR') * (',' * lpeg.V('EXPR'))^0 * ')' )) ),
        MEMBER = lpeg.Ct( lpeg.Cc('member') * space * '.' * identifier * lpeg.V('SUBSCRIPT')^-1 ),

        ADDRESS = lpeg.Ct( lpeg.Cc('address') * '@{' * lpeg.V('EXPR') * '}' ),

        ASSIGN = lpeg.Ct( lpeg.Cc('assign') * lpeg.V('LVALUE') * space * '=' * space * lpeg.V('EXPR') ),
        LVALUE = lpeg.Ct( (lpeg.Cc('id') * identifier * (lpeg.V('SUBSCRIPT') + lpeg.V('MEMBER'))^-1) ) + lpeg.V('ADDRESS'),
        NEW = lpeg.Ct( lpeg.Cc('new') * space * 'new' * space * identifier ),

        SHORTCOND = lpeg.Ct( lpeg.Cc('if') * '(' * space * lpeg.V('EXPR') * space * '?' * space * lpeg.V('EXPR') * space * ':' * space * lpeg.V('EXPR') * space * ')' ),
    }
end

local expr = expr_pattern()

function statement_pattern(expr)
    return lpeg.P{
        'STMT';
        STMT = lpeg.Ct( lpeg.Cc('stmt') *
                            (lpeg.V('FUNC') +
                                 lpeg.V('STRUCT') +
                                 lpeg.V('VAR') +
                                 lpeg.V('LOOP') +
                                 lpeg.V('COND') +
                                 expr)
        ),

        BODY = lpeg.Ct( lpeg.Cc('body') *
                            (lpeg.V('VAR') +
                                 lpeg.V('LOOP') +
                                 lpeg.V('COND') +
                                 lpeg.V('BREAK') +
                                 lpeg.V('RETURN') +
                                 expr
                            )^0 ),

        RETURN = lpeg.Ct( lpeg.Cc('return') * space * 'return' * space * expr ),
        BREAK = lpeg.Ct( lpeg.Cc('break') * space * 'break' * space ),

        VAR = lpeg.Ct( lpeg.Cc('var') * space * 'var' * space * identifier * lpeg.V('TYPE')^-1 * lpeg.V('INITIAL')^-1 ),
        TYPE = lpeg.Ct(lpeg.Cc('type') * space * ':' * space * identifier),
        INITIAL = lpeg.Ct(lpeg.Cc('init') * space * '=' * expr),

        FUNC = lpeg.Ct(
            lpeg.Cc('func') * space *
                'function' * space *
                identifier * space *
                '(' * space * lpeg.V('ARGLIST')^-1 * space * ')' * space *
                '{' * space * lpeg.V('BODY') * space * '}'
        ),
        ARGLIST = lpeg.Ct( lpeg.Cc('args') * identifier * (space * ',' * space * identifier)^0 ),

        STRUCT = lpeg.Ct(
            lpeg.Cc('struct') * space *
                'struct' * space *
                identifier * space *
                '{' * space * lpeg.V('MEMBERLIST') * space * '}'
        ),
        MEMBERLIST = space * lpeg.V('MEMBER') * (space * ',' * lpeg.V('MEMBER') * space)^0,
        MEMBER = lpeg.Ct( lpeg.Cc('member') * space * identifier * space * (lpeg.V('LENGTH') + lpeg.V('INITIAL'))^-1),
        LENGTH = lpeg.Ct( lpeg.Cc('length') * space * '(' * space * expr * space * ')' * space ),

        LOOP = lpeg.Ct(
            lpeg.Cc('loop') * space *
                'loop' * space *
                '{' * space * lpeg.V('BODY') * space * '}'
        ),

        COND = lpeg.Ct(
            lpeg.Cc('if') * space *
            'if' * space *
                '(' * space * expr * space * ')' * space *
                '{' * space * lpeg.V('BODY') * space * '}' *
            (space * 'else' * space *
                 '{' * space * lpeg.V('BODY') * space * '}'
            )^-1 ),
    }
end

local statement = statement_pattern(expr)

return { expr = expr, statement = statement }
