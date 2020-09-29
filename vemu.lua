SDL = require('SDL')
SDL.image = require('SDL.image')
local Display = require('display')
local logger = require('logger')
--local CPU = require('cpu')
local CPU = require('cvemu')
local Loader = require('loader')

local random_seed = os.time()
math.randomseed(random_seed)

local argv = {...}
if argv[1] then
    local iterator = io.open(argv[1])
    local cpu = CPU.new(random_seed)

    local display = Display.new(false)
    display:install(cpu)

    logger(cpu, 200, print)

    if argv[1]:match('%.asm$') then
        Loader.asm(cpu, iterator:lines())
    elseif argv[1]:match('%.f$') then
        Loader.forge(cpu, iterator:lines())
    end

    iterator:close()
    cpu:reset()

    while display.active do
        cpu:run()
        -- While we're halted, we won't run instructions but we'll still
        -- tick devices, and eventually one of them might fire an interrupt
        cpu:tick_devices()
    end

    print('Random seed: ' .. random_seed)
    cpu:print_stack()
end
