SDL = require('SDL')
SDL.image = require('SDL.image')
local Display = require('display')
local CPU = require('cpu')

local random_seed = os.time()
math.randomseed(random_seed)

local argv = {...}
if argv[1] then
    local iterator = io.open(argv[1])
    local display = Display.new(false)
    local cpu = CPU.new(display)
    cpu:load(iterator:lines())
    iterator:close()
    cpu:reset()
    cpu:run()
    print('Random seed: ' .. random_seed)
    cpu:print_stack()
end
