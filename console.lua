package.cpath = package.cpath .. ';./cvemu/?.so'
CPU = require('cvemu')
-- CPU = require('vemu.cpu')
Loader = require('vemu.loader')

lfs = require('lfs')
lfs.chdir('4th')

function init_cpu(code)
    local random_seed = os.time()
    math.randomseed(random_seed)

    local cpu = CPU.new(random_seed)

    local iterator = io.lines('4th.asm')
    Loader.asm(cpu, iterator)

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

local cpu = init_cpu()
cpu:run()
readloop(cpu)
