package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')

function init_cpu(code)
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.open(code)
    if code:match('%.asm$') then
        Loader.asm(cpu, iterator:lines())
    elseif code:match('%.f$') then
        Loader.forge(cpu, iterator:lines())
    end

    cpu:install_device(2, 2,
                       { poke = function(addr, val) io.write(string.char(val)) end })

    return cpu
end

function readloop(cpu)
    local line
    while true do
        line = io.read('*l')
        if not line then break end
        for i = 1, #line do
            local ch = line:byte(i, i)
            cpu:interrupt(ch, 65)
            cpu:run()
        end
        cpu:interrupt(10, 65) -- The newline
        cpu:run()
    end
end

local ARGV = {...}
if not ARGV[1] then
    error('No ROM supplied! Pass a .asm or .f filename as an argument')
end

local cpu = init_cpu(ARGV[1])
cpu:run()
readloop(cpu)
