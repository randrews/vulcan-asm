local CPU = require './cpu'

local random_seed = os.time()
local cpu = CPU.new(random_seed)
local iterator = io.open('rom.asm')

local rom = { start = 1024, binary = {125,11,156,1,0,1,65,85,1,164,4,128,5,2,76,38,96,9,115,243,255,255,160,72,116} }

for a, b in ipairs(rom.binary) do cpu:poke(a + rom.start - 1, b) end
cpu:reset()

local channel = {
    zeropage = love.thread.getChannel('zeropage'),
    vram = love.thread.getChannel('vram')
}

local register_device = {
    peek = function(addr)
        channel.zeropage:push{ false, addr }
        return 0xff
    end
}

local display_device = {
    
}

cpu:install_device(0, 255, register_device)

cpu:run()
