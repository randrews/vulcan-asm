local VASM = require('vasm.vasm')

function load_asm(cpu, iterator)
    local bytes, start, address_lines, symbols = VASM.assemble(VASM.preprocess(iterator), true)

    for offset, byte in pairs(bytes) do
        cpu:poke(start + offset, byte)
    end

    return symbols
end

function load_forge(cpu, iterator)
    error('Forge is now deprecated, use 4th.asm instead')
    -- local asm = {}
    -- local function emit(str) table.insert(asm, str) end

    -- Forge.compile(iterator, emit)

    -- local i, e = nil, nil
    -- local asm_iterator = function()
    --     i, e = next(asm, i)
    --     return e
    -- end
    -- load_asm(cpu, asm_iterator)
end

return { asm=load_asm }
