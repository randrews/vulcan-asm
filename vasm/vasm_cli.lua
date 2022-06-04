ARGS = { ... }
VERSION = 'v0.1, June 2022'

--------------------------------------------------------------------------------

function print_usage()
    local usage = {
        'Usage: vasm [input file] [flags]',
        'Flags:',
        '\t-h',
        '\t\tPrint this message and exit',
        '\t-v',
        string.format('\t\tPrint version, which is %q', VERSION),
        '\t-e',
        '\t\tRead input from stdin',
        '\t-o [output file]',
        '\t\tSend output to file',
        '\t-i',
        '\t\tPrint info about assembled file',
        '\t-f [format]',
        '\t\tWhat format to output, "json" or "binary" (default binary)',
    }
    for _, line in ipairs(usage) do print(line) end
end

function verify_lib(lib)
    local success, err = pcall(require, lib)
    if not success then -- Not able to load, nice error message
        print(string.format("vasm requires %s to work! Please ensure that lpeg exists on lua's cpath\n", lib))
        print('Current package.cpath:')
        print(package.cpath)
        print('\nError:')
        print(err)
        os.exit(1)
    end
end

function fail(message, ...)
    warn(message, ...)
    os.exit(1)
end

function warn(message, ...)
    print(string.format(message, ...))
end

function exists(file)
    local f = io.open(file)
    if f then
        f:close()
        return true
    else
        return false
    end
end

function parse_args(args)
    local mode = 'start' -- Changed as we parse flags
    local entrypoint = nil -- Which file we start reading from
    local stdin = false -- Whether we should read stdin
    local output = nil -- Where output will go
    local format = 'binary' -- What format output is
    local info = false -- Whether to print info

    for _, arg in ipairs(args) do
        if mode == 'start' then
            if arg == '-e' then
                stdin = true
            elseif arg == '-o' then
                mode = 'output'
            elseif arg == '-f' then
                mode = 'format'
            elseif arg == '-h' then
                print_usage()
                os.exit(0)
            elseif arg == '-i' then
                info = true
            elseif arg == '-v' then
                print(string.format('Vulcan Assembler %s', VERSION))
                os.exit(0)
            else
                if stdin then
                    fail('Told to read from stdin but also given input file name %q', arg)
                end
                if entrypoint then
                    fail('Given multiple input files, expected to enter at %q', entrypoint)
                end
                if not arg:match('[.]asm$') then
                    warn('Warning: input file %q does not end in ".asm"', arg)
                end
                entrypoint = arg
            end
        elseif mode == 'output' then
            if not arg:match('[.]rom$') then
                warn('Warning: output file %q does not end in ".rom"', arg)
            end
            output = arg
            mode = 'start'
        elseif mode == 'format' then
            if arg ~= 'binary' and arg ~= 'json' then
                fail('Invalid format %q', arg)
            else
                format = arg
                mode = 'start'
            end
        end
    end

    if mode ~= 'start' then fail('Failed to parse argument list') end
    if not entrypoint and not stdin then fail('No input!') end

    if not output then
        local basename = nil
        if entrypoint then basename = entrypoint:match('(.*)[.]asm$') end
        if stdin or not basename then fail("No destination given, can't deduce one") end
        output = basename .. '.rom'

        if exists(output) then fail('No destination given, default destination of %q exists, pass "-o %s" to overwrite', output, output) end
        warn('No destination given, writing to %q', output)
    end

    return { entrypoint = entrypoint, stdin = stdin, output = output, format = format, info = info }
end

--------------------------------------------------------------------------------

verify_lib('lpeg')
verify_lib('lfs')

-- First arg from the shell script is always the dirname of vasm, so:
local dirname = table.remove(ARGS,1)
package.path = package.path .. ';' .. dirname .. '/?.lua'

if #ARGS < 1 then
    print_usage()
    os.exit(0)
end

local opts = parse_args(ARGS)

local lfs = require('lfs')
local vasm = require('vasm')

--------------------------------------------------------------------------------

local success, err = pcall(function()
        -- The last entry in this table is the directory we should currently be in
        local dir_stack = {lfs.currentdir()}

        -- Set the current dir to the last entry in the table
        local setdir = function()
            local dir = dir_stack[#dir_stack]
            lfs.chdir(dir)
        end

        local include = function(filename)
            -- Add wherever this file is to the dir stack
            if filename:match('^[^/]+$') then -- no dir, just a filename
                table.insert(dir_stack, '.') -- Push the current directory
            else
                local dir, name = filename:match('(.*)/([^/]+)')
                assert(dir and name, string.format('Weird-looking include file: %q', filename))
                table.insert(dir_stack, dir)
            end

            local success, err_or_file = pcall(io.lines, filename)
            if success then
                setdir() -- cd into the dir so this file's relative paths will work
                return err_or_file -- This is a file, so give it to vasm
            else
                print(string.format('Error opening %q:\n%s', filename, err_or_file))
                os.exit(1)
            end
        end

        local close = function()
            table.remove(dir_stack) -- pop a directory
            setdir() -- cd back to where we were before
        end

        local lines = opts.stdin and io.lines() or include(opts.entrypoint)
        local preprocessor = vasm.preprocess(lines, include, close)
        local code, start = vasm.assemble(preprocessor, true)

        if opts.info then
            -- Add 1 to the number of bytes because #code won't notice the 0th element
            print(string.format('Assembled %d bytes, origin at 0x%x', #code + 1, start))
        end

        if opts.format == 'binary' then
            local out = io.open(opts.output, 'w')
            for i = 0, #code do
                out:write(string.char(code[i]))
            end
            out:close()
        elseif opts.format == 'json' then
            print('JSON format is not supported yet. :/')
            os.exit(2)
        end
end)

if not success then print(err) end
