package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')
lfs = require('lfs')

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
local rom_file = ARGV[1]
if not rom_file then
    print('No ROM filename supplied! Using 4th as a default')
    lfs.chdir('4th')
    rom_file = '4th.asm'
end

local cpu = init_cpu(rom_file)
cpu:run()
readloop(cpu)
