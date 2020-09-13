SDL = require('SDL')
SDL.image = require('SDL.image')
local Display = require('display')
local CPU = require('cpu')

local random_seed = os.time()
math.randomseed(random_seed)

local argv = {...}
if argv[1] then
    local iterator = io.open(argv[1])
    local cpu = CPU.new()

    local display = Display.new(false)
    display:install(cpu)

    if argv[1]:match('%.asm$') then
        cpu:load_asm(iterator:lines())
    elseif argv[1]:match('%.f$') then
        cpu:load_forge(iterator:lines())
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
