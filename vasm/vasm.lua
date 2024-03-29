-- ### Purpose
-- This is going to be an emulator / development tool for the Vulcan microcomputer.
-- It will be able to parse assembly files and run them, including an emulation of the
-- video display and keyboard in a window.

-- ### Dependencies
-- To parse Vulcan assembly, we'll need a parser library, so, LPeg:
lpeg = require('lpeg')
opcodes = require('util.opcodes')

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

-- Used for an error handler that doesn't indicate position (because the cause is
-- in the source, not the assembler)
function input_error(err)
    error(err, 0)
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
    -- - Decimal zero needs its own pattern: it's not a decimal because
    --   it starts with a 0, but it has to be matched after hex and bin
    --   because otherwise any "0x" will parse as "decimal 0 followed
    --   by unparseable x"
    local dec_number = (lpeg.R('19') * lpeg.R('09')^0) / tonumber
    local neg_number = (lpeg.P('-') * dec_number) / function(n) return n * -1 end
    local hex_number = lpeg.P('0x') * lpeg.C(lpeg.R('09','af','AF')^1) / function(s) return tonumber(s, 16) end
    local bin_number = lpeg.P('0b') * lpeg.C(lpeg.S('01')^1) / function(s) return tonumber(s, 2) end
    local dec_zero = lpeg.P('0') / tonumber
    local number = dec_number + hex_number + bin_number + dec_zero + neg_number

    -- A label can be any sequence of C-identifier-y characters, as long as it doesn't start with
    -- a digit:
    local label_char = (lpeg.R('az', 'AZ') + lpeg.S('_$'))
    local label = lpeg.C(label_char * (label_char + lpeg.R('09'))^0)

    -- To make relative jumps easier, we'll also allow an '@' at the start of a label, and interpret
    -- that as meaning "relative to the first byte of this instruction:"
    local relative_label = lpeg.C(lpeg.P('@') * (label_char * (label_char + lpeg.R('09'))^0))

    -- We'll also have a special form, $+nnn (and $-nnn) which is the first byte of the an earlier or later line:
    local absolute_line_offset = lpeg.P('$') * lpeg.Ct(lpeg.Cc('line-offset') * lpeg.Cc('absolute') * (lpeg.P('+') * number + lpeg.P('-') * (number / function(n) return n * -1 end)))

    -- And the relative form of that, @+nnn and @-nnn:
    local relative_line_offset = lpeg.P('@') * lpeg.Ct(lpeg.Cc('line-offset') * lpeg.Cc('relative') * (lpeg.P('+') * number + lpeg.P('-') * (number / function(n) return n * -1 end)))

    -- ## Opcodes
    -- An opcode is any one of several possible strings.
    -- Combine the opcodes into one pattern:

    -- First, we need to match the longer opcodes first, because none of these matches are greedy:
    local sorted_mnemonics = { table.unpack(opcodes.mnemonic_list) }
    table.sort(sorted_mnemonics, function(a, b) return #a > #b end)

    -- Reduce the sorted opcodes to one pattern:
    local opcode = lpeg.C(
        table.reduce(
            table.map(sorted_mnemonics, lpeg.P),
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
        FACT = (space * '(' * lpeg.V('EXPR') * ')') + (space * (number + relative_line_offset + relative_label + absolute_line_offset + label) * space)
    }

    -- Likewise, .db would get tedious quick without a string syntax, so, let's define one of those. An escape
    -- sequence is a backslash followed by certain other characters:
    local escape = lpeg.C(lpeg.P('\\') * lpeg.S('trn0"\\'))

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
-- list of parsed lines, but with expressions un-evaluated.
--
-- The main goal here is to strip out semantically blank lines (comments, whitespace, blanks) and return
-- a list of parsed instructions we can then work with.
--
-- - If we can't parse a line, throw an error
-- - If it parsed to an empty list (because it's just whitespace), skip it
--
-- Otherwise, we have a line like: `{'label', 'foo', 'opcode', 'add'}`. We want to convert that to a more
-- convenient format of `{label='foo', opcode='add'}`. We're also going to store in each object the line
-- number from the original iterator that it represents, to make giving error messages later on possible.
--
-- Then, there are three errors that are easy to figure out here, so we'll catch them:
--
-- - A string argument can't go on anything except a .db directive, so we'll error on that.
-- - A .equ directive doesn't make sense without a label to define the value of and a value to assign to
--   it, so we'll error on that too.
-- - A .org doesn't make sense without an argument, so that will also be an error.
function parse_assembly(iterator)
    local lines = {} -- This will store the eventual output
    local line_num = 1 -- A count of the line number

    for line in iterator do
        local ast = statement:match(line)

        if ast == nil then
            input_error('Parse error on line ' .. line_num .. ': ' .. string.format('%q', line))
        end

        if #ast > 0 then
            local obj = { line=line_num }
            for n = 1, #ast, 2 do
                obj[ast[n]] = ast[n+1]
            end

            if obj.argument and obj.argument[1] == 'string' and obj.directive ~= '.db' then
                input_error('String argument outside .db directive on line ' .. line_num)
            end

            if obj.directive == '.equ' and (obj.argument == nil or obj.label == nil) then
                input_error('.equ directive missing label or argument on line' .. line_num)
            end

            if obj.directive == '.org' and obj.argument == nil then
                input_error('.org directive missing argument on line ' .. line_num)
            end

            table.insert(lines, obj)
        end

        line_num = line_num + 1
    end

    return lines
end

-- ## Evaluating expressions
-- Now that we have a parsed file, that file has a bunch of numeric symbols in it: labels,
-- .equ directives, that sort of thing. We need to resolve all of those to constant values
-- before we can generate code. So, first part of that is being able to evaluate expressions.
--
-- This evaluates an expression in the context of a symbol table, and returns either what the
-- expression evaluates to (a number) or throws an error (if it references a symbol not in
-- the given symbol table).
--
-- It's a depth-first recursive traversal of the expression AST:
--
-- - If the node is a number, then it returns that number.
-- - If the node is a string, it tries to look it up in the symbol table or explodes.
-- - If the node is a relative label, it tries to look it up in the symbol table, and then
--   subtracts a given start_address. If start_address is nil (as when we're solving .equs)
--   then it errors.
-- - If the node is an expr or term, then it evaluates the children: the children are a
--   sequence of evaluate-able nodes separated by operators. So first evaluate the left-most
--   child, then use the operator to combine it with the following one, and so on.
-- - If the node is a parsed string (table with the first element being 'string'), it
--   turns the second element into an array of bytes (parsing out escape sequences) and returns it.
-- - If the node is an absolute or relative line offset (table with the first element being
--   'line-offset'), it attempts to look up the start of the given line in the table of lines
--   and gives that address relatively or absolutely
--
-- This works because the parser handles all the order-of-operations stuff in parsing, so
-- we don't need to care what actual type of node it is, expr or term.
--
-- One tricky point is that we call `math.floor` when dividing, because Lua has all floating-
-- point math but Vulcan only has fixed-point, truncating division.
function evaluate(expr, symbols, start_address, lines, line_num)
    if type(expr) == 'number' then
        return expr
    elseif type(expr) == 'string' then
        if expr:sub(1,1) == '@' then
            if not start_address then input_error('Cannot resolve relative label') end
            local label_name = expr:sub(2)
            if label_name:sub(1,1) == '-' or label_name:sub(1,1) == '+' then -- relative offset
                return start_address + tonumber(label_name)
            else
                if symbols[label_name] then return symbols[label_name] - start_address
                else input_error('Symbol not defined: ' .. label_name) end
            end
        elseif symbols[expr] then return symbols[expr]
        else input_error('Symbol not defined: ' .. expr) end
    elseif expr[1] == 'expr' or expr[1] == 'term' then
        local val = evaluate(expr[2], symbols, start_address, lines, line_num)

        for i = 3, #expr, 2 do
            local operator = expr[i]
            local rhs = evaluate(expr[i+1], symbols, start_address, lines, line_num)
            if operator == '+' then
                val = val + rhs
            elseif operator == '-' then
                val = val - rhs
            elseif operator == '*' then
                val = val * rhs
            elseif operator == '/' then
                val = math.floor(val / rhs)
            elseif operator == '%' then
                val = val % rhs
            end
        end
        return val
    elseif expr[1] == 'string' then
        local string_bytes = {}
        for _,ch in ipairs(expr[2]) do
            if ch:sub(1,1) == '\\' then
                local escaped = ch:sub(2,2)
                if escaped == 't' then table.insert(string_bytes, string.byte('\t')) end
                if escaped == 'r' then table.insert(string_bytes, string.byte('\r')) end
                if escaped == 'n' then table.insert(string_bytes, string.byte('\n')) end
                if escaped == '0' then table.insert(string_bytes, string.byte('\0')) end
                if escaped == '"' then table.insert(string_bytes, string.byte('"')) end
                if escaped == '\\' then table.insert(string_bytes, string.byte('\\')) end
            else
                table.insert(string_bytes, string.byte(ch))
            end
        end
        return string_bytes
    elseif expr[1] == 'line-offset' then
        if line_num then
            local target_line_num = line_num + expr[3]
            if lines and line_num and lines[target_line_num] and lines[target_line_num].address then
                if expr[2] == 'relative' then
                    return lines[target_line_num].address - start_address
                elseif expr[2] == 'absolute' then
                    return lines[target_line_num].address
                end
            else
                input_error("Can't calculate start of line " .. target_line_num)
            end
        else
            input_error("Can't calculate line offset")
        end
    else
        input_error('Unrecognized argument: type "' .. type(expr) .. '"')
    end
end

-- ## Second pass
-- This will solve all the .equ directives and return a symbol table of them.
-- .equ directives must be able to be solved in order, that is, in terms of
-- only preceding .equ directives. Anything else is an error.
function solve_equs(lines)
    local symbols = {}

    for _, line in ipairs(lines) do
        if line.directive == '.equ' then
            local success, ret = pcall(evaluate, line.argument, symbols)
            if success then symbols[line.label] = ret
            else input_error('Cannot resolve .equ on line ' .. line.line .. ': ' .. ret) end
        end
    end

    return symbols
end

-- ## Third pass
-- We need to figure out the instruction lengths. We'll do this naively; if we can't
-- immediately tell that an instruction needs only a 0/1/2 byte argument (because it's
-- a constant, or a .equ that we've solved, or something) then we'll assume it's a
-- full 24-bit argument.
--
-- - Lines that don't represent output (.equ, .org, etc) have length 0
-- - .db directives are either strings (set aside the length of the string), or
--   numbers (set aside three bytes. If it's shorter than that it still may be a variable,
--   which might grow to be larger).
-- - Opcodes with no argument are 1 byte long.
-- - Opcodes with an argument, if that argument is a constant or decidable solely with
--   what we know right now (.equs), are however long that argument is. If we don't
--   know right now (based on a label, say) then we'll set aside the full 3 bytes (so it's
--   4 bytes long, with the instruction byte).
function measure_instructions(lines, symbols)
    for _, line in ipairs(lines) do
        if not(line.opcode or line.directive == '.db') then
            line.length = 0
        elseif line.directive == '.db' then
            if line.argument[1] == 'string' then
                line.length = #(line.argument[2])
            else
                line.length = 3
            end
        elseif line.opcode then
            if not line.argument then
                line.length = 1
            else
                local success, val = pcall(evaluate, line.argument, symbols)
                if not success then line.length = 4
                else
                    if val < 0 then line.length = 4 -- If it's negative, we need the full 3 bytes
                    elseif val < 256 then line.length = 2
                    elseif val < 65536 then line.length = 3
                    else line.length = 4 end
                end
            end
        end
    end
end

-- ## Fourth pass
-- Time to start placing labels. The tricky part here is the .org directives, which can have
-- expressions as their arguments. We'll compromise a little bit and say that a .org directive
-- can only refer to labels that precede it, so, you can use .orgs to generate (say) a jump table
-- but still make it easy for me to figure out what refers to what.
--
-- We'll have an `address` variable and go through the lines, adding each one's length (calculated
-- in the third pass) to it. If it has a label, we'll add that label's new value to `symbols`.
--
-- But, we'll skip labels that come before .equs: that would make every .equ set to its address,
-- rather than the argument.
--
-- For code generation, we also need to have the start and end addresses, so we'll take this
-- opportunity to calculate them and store them as `$start` and `$end` in the symbol table.
--
-- This means that this function will alter `lines`, by adding an `address` key to each one,
-- and `symbols`, by adding all the labels' addresses to it. It might also throw an error, if
-- it encounters a .org that refers to something it shouldn't.
function place_labels(lines, symbols)
    local address = 0
    local start_addr = math.maxinteger
    local end_addr = 0

    for _, line in ipairs(lines) do
        if line.directive == '.org' then
            local success, ret = pcall(evaluate, line.argument, symbols)
            if success then
                address = ret
            else
                input_error('Unable to resolve .org on line ' .. line.line .. ': ' .. ret)
            end
        end

        start_addr = math.min(start_addr, address)
        end_addr = math.max(end_addr, address + line.length - 1)

        line.address = address
        address = address + line.length

        if line.label and line.directive ~= '.equ' then
            symbols[line.label] = line.address
        end
    end

    symbols['$start'] = start_addr
    symbols['$end'] = end_addr
end

-- ## Fifth pass
-- At this point we have everything we need to calculate the arguments, so we'll do that.
-- This will take the array of lines and map of symbols, and iterate through each line.
-- If the line has an argument, evaluate it based on the symbol table, and change it to
-- a number.
function calculate_args(lines, symbols)
    for line_num, line in ipairs(lines) do
        if line.argument then
            local success, ret = pcall(evaluate, line.argument, symbols, line.address, lines, line_num)
            if success then
                line.argument = ret
            else
                input_error('Unable to evaluate argument on line ' .. line.line .. ': ' .. ret)
            end
        end
    end
end

-- ## Code generation
-- At this point all lines have addresses and lengths, and all arguments are reduced to
-- numeric constants. It's time to generate code. This function takes the fully-resolved
-- `lines` array, start and end addresses, and returns an array of bytes, as numbers,
-- between 0 and 255.
--
-- The array of bytes will start at index 0, regardless of what the start address is. So,
-- if you pass in a list of instructions 5 bytes long, and a start af 100, you get back
-- an array of five elements that should correspond to memory addresses 100-104.
--
-- The reason we need the end address is that we're going to fill gaps with zeroes, which
-- correspond to nops. So, the whole code generation process:
--
-- - Make an array of zeroes, indexed from 0 to (end-start-1)
-- - Go through the list of instructions, generating code for them:
-- - .db instructions turn into byte values starting at `line.address - start`
-- - Opcodes turn into instruction bytes at `line.address - start` followed (maybe) by
--   arguments.
-- - Any other directive is skipped (even .orgs, we already have the addresses calculated)
--
-- The instruction bytes are formed of six bits defining the instruction followed by two
-- bits denoting how many bytes of argument follow it. We know how long the argument is
-- because of `line.length` and we know which instruction it is because of `line.opcode`.
--
-- Vulcan is a little-endian architecture: multi-byte arguments / .dbs will store the
-- least-significant byte at the lowest address, then the more significant bytes following.
function generate_code(lines, start_addr, end_addr)
    local mem = {}

    for a = 0, (end_addr - start_addr - 1) do
        mem[a] = 0
    end

    for _, line in ipairs(lines) do
        if line.directive == '.db' then
            if type(line.argument) == 'table' then
                local a = line.address - start_addr
                for i = 1, #line.argument do
                    mem[a] = line.argument[i]
                    a = a + 1
                end
            else
                mem[line.address - start_addr] = line.argument & 0xff
                mem[line.address - start_addr + 1] = (line.argument >> 8) & 0xff
                mem[line.address - start_addr + 2] = (line.argument >> 16) & 0xff
            end
        elseif line.opcode then
            local instruction = opcodes.opcode_for(line.opcode) or input_error('Unrecognized opcode on line ' .. line.line .. ': ' .. line.opcode)

            instruction = (instruction << 2) + (line.length - 1)
            mem[line.address - start_addr] = instruction
            if line.length > 1 then mem[line.address - start_addr + 1] = line.argument & 0xff end
            if line.length > 2 then mem[line.address - start_addr + 2] = (line.argument >> 8) & 0xff end
            if line.length > 3 then mem[line.address - start_addr + 3] = (line.argument >> 16) & 0xff end
        end
    end

    return mem
end

-- ## Assemble function
-- Bring everything else together to go from an iterator on lines of code, to a final array
-- of bytes ready to be written to something (or interpreted by a CPU)
function assemble(iterator, debuginfo)
    local lines = parse_assembly(iterator)
    local symbols = solve_equs(lines)
    measure_instructions(lines, symbols)
    place_labels(lines, symbols)
    calculate_args(lines, symbols)

    if debuginfo then
        local address_lines = {}
        for _, line in ipairs(lines) do
            address_lines[line.address] = line.line
        end
        return generate_code(lines, symbols['$start'], symbols['$end']), symbols['$start'], address_lines, symbols
    else
        return generate_code(lines, symbols['$start'], symbols['$end']), symbols['$start']
    end
end

-- ## Preprocessor
-- Takes an iterator over lines including preprocessor directives, and returns another iterator,
-- which iterates over just normal lines. Also takes an optional include hook that is called to
-- open a new file for #include, and a close_hook that is called when a file is finished.

-- Assembler macros! Using gensym. turn into asm lines, in the preprocessor.
-- #if / #unless / #else / #end
-- #while / #until / #do / #end
-- Example: #if compiles to "brz @{gensym()}" and #end (for an if) compiles to "{that_sym}:"
-- Example:
-- #while
-- load blah
-- gt 10
-- #do
-- ...
-- #end
-- Compiles to the while being a gensym, the do being a brz to the line after the end, and the end (because the
-- top two things are a do and a while) being a jr to the while followed by another gensym.
--
-- Important rule is that everything you can do in macros is preprocessor-level, it will become new lines of
-- code and not affect later assembler stages
function preprocess(iterator, include_hook, close_hook)
    -- Today we'll just recognize one directive: the humble include
    local space = lpeg.S(" \t")^0
    local string_pattern = lpeg.P('"') * lpeg.C((lpeg.P(1)-lpeg.S('"\\'))^1) * '"'
    local preprocess_pattern = space * '#' * (lpeg.C('include') * space * string_pattern +
                                              lpeg.C('if') + lpeg.C('unless') + lpeg.C('else') +
                                              lpeg.C('while') + lpeg.C('until') + lpeg.C('do') +
                                              lpeg.C('end'))

    -- A default include hook that just opens files in the current directory. A real one of
    -- these would use lfs or something to handle changing directories and relative paths,
    -- but to keep this only dependent on the Lua standard library, we'll offer this basic
    -- one:
    include_hook = include_hook or io.lines
    close_hook = close_hook or function() end

    -- We'll keep a stack of files that we're reading from, so files can include other files
    local file_stack = { iterator }

    -- We'll also keep a stack of open flow-control directives
    local control_stack = { }

    -- A function to generate unique (hopefully!) labels
    local gensym_idx = 0
    local function gensym()
        gensym_idx = gensym_idx + 1
        return '__gensym_' .. gensym_idx
    end

    -- Some preprocessor directives generate lines. When they do, they get put in this
    -- table, which fetch_line will read from preferentially until it's empty.
    local generated_lines = { }

    local function fetch_line()
        local line
        repeat
            if #generated_lines > 0 then
                line = table.remove(generated_lines, 1)
            else
                success, line = pcall(file_stack[#file_stack]) -- Fetch a line
                if not success or not line then -- If we're done with this file, then:
                    table.remove(file_stack) -- Remove this file from the stack
                    close_hook() -- Call the close hook so our includer can pop a directory or whatever
                    if #file_stack == 0 then return nil end -- If it was the last file then we're done overall
                    line = (file_stack[#file_stack])() -- Otherwise grab another line from the file that included us
                end
            end
        until line
        return line -- At this point either we have a line or we've returned nil (and killed the iterator)
    end

    return function()
        local line = fetch_line()
        local directive, file
        repeat
            -- Now we're going to try to parse the line. Is it a preprocessor directive?
            if line then
                directive, filename = preprocess_pattern:match(line)
                if directive == 'include' then
                    table.insert(file_stack, (include_hook(filename))) -- Add it to the file stack
                elseif directive == 'if' then -- Insert a brz to the corresponding end
                    local label = gensym()
                    table.insert(control_stack, { 'target', label = label })
                    table.insert(generated_lines, 'brz @' .. label)
                elseif directive == 'unless' then -- Insert a brnz to the corresponding end
                    local label = gensym()
                    table.insert(control_stack, { 'target', label = label })
                    table.insert(generated_lines, 'brnz @' .. label)
                elseif directive == 'else' then -- Jmp to the end, and resolve the previous if / unless with a label
                    local if_dir = table.remove(control_stack)
                    if if_dir[1] ~= 'target' then error('Mismatched #else') end
                    local label = gensym()
                    table.insert(control_stack, { 'target', label = label })
                    table.insert(generated_lines, 'jmpr @' .. label)
                    table.insert(generated_lines, if_dir.label .. ':')
                elseif directive == 'while' or directive == 'until' then -- Insert a start-of-loop label
                    local label = gensym()
                    table.insert(control_stack, { 'loop', label = label, type = directive })
                    table.insert(generated_lines, label .. ':')
                elseif directive == 'do' then -- brz / brnz to the end, based on the condition
                    local last_dir = table.remove(control_stack)
                    if not last_dir or last_dir[1] ~= 'loop' then error('Mismatched #do') end
                    local after = gensym()
                    table.insert(control_stack, { 'loop-do', start = last_dir.label, after = after })
                    if last_dir.type == 'while' then
                        table.insert(generated_lines, 'brz @' .. after)
                    elseif last_dir.type == 'until' then
                        table.insert(generated_lines, 'brnz @' .. after)
                    end
                elseif directive == 'end' then -- Does many things based on what it's ending:
                    local last_dir = table.remove(control_stack)
                    if not last_dir then error('Mismatched #end')
                    elseif last_dir[1] == 'target' then -- For an if / unless / else, just put a label to land on
                        table.insert(generated_lines, last_dir.label .. ':')
                    elseif last_dir[1] == 'loop-do' then -- jmp back to the loop start, then resolve the label for `do` to land on
                        table.insert(generated_lines, 'jmpr @' .. last_dir.start)
                        table.insert(generated_lines, last_dir.after .. ':')
                    end
                end

                if directive then line = fetch_line() end
            else
                directive = nil -- A nil line can't be a directive...
            end
        until not directive
        return line
    end
end

return {
    statement=statement,
    parse_assembly=parse_assembly,
    evaluate=evaluate,
    solve_equs=solve_equs,
    measure_instructions=measure_instructions,
    place_labels=place_labels,
    calculate_args=calculate_args,
    preprocess=preprocess,
    assemble=assemble
}
