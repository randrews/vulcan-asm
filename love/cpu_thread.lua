local CPU = require './cpu'

local random_seed = os.time()
local cpu = CPU.new(random_seed)

while true do
    print('nooop')
end
