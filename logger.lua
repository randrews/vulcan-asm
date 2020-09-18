return function(cpu, address, print)
    local start_time = os.clock()
    local last_time = start_time

    local function poke(_addr, val)
        local current = os.clock()
        local delta = current - last_time
        last_time = current
        print(string.format('%f (+%f)\t0x%x <- 0x%x (%d)', current - start_time, delta, address, val, val))
    end

    cpu:install_device(address, address, { poke = poke })
end
