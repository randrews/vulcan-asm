CPU = require('libvlua')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')

lfs = require('lfs')
lfs.chdir('4th')

local Symbols = nil
TIB = 80000 -- Just a convenient place to stick a terminal input buffer for the repl. Could be any otherwise-unused address.

function init_cpu(code)
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.lines('test_init.asm')
    Symbols = Loader.asm(cpu, iterator)

    return cpu
end

function readloop(cpu)
    local line
    while true do
        line = io.read('*l')
        if not line then break end

        line = { line:byte(1, #line) } -- Convert to an array
        table.insert(line, 0) -- Null terminate it
        for i, b in ipairs(line) do cpu:poke(TIB + i - 1, b) end -- Put in TIB
        
        cpu:push_data(TIB) -- The buffer we want to eval
        cpu:push_call(Symbols.stop) -- Where we want to return to after the eval
        cpu:set_pc(Symbols.eval) -- Start running at eval
        cpu:run() -- Run until we're through
        print(get_output(cpu)) -- Read the output buffer and print it
        reset_output_buffer(cpu)
    end
end

function get_output(cpu)
    local start = 0x10000
    local len = cpu:peek24(Symbols.emit_cursor)
    local str = ''
    for a = start, len+start-1 do
        str = str .. string.char(cpu:peek(a))
    end
    return str
end

function reset_output_buffer(cpu)
    cpu:poke24(Symbols.emit_cursor, 0)
end

local cpu = init_cpu()
cpu:run()
readloop(cpu)
