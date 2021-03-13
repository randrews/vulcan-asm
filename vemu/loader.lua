local VASM = require('vasm.vasm')
local Forge = require('forge.forge')

function load_asm(cpu, iterator)
    local bytes, start, address_lines, symbols = VASM.assemble(iterator, true)

    for offset, byte in pairs(bytes) do
        cpu:poke(start + offset, byte)
    end

    return symbols
end

function load_forge(cpu, iterator)
    local asm = {}
    local function emit(str) table.insert(asm, str) end

    Forge.compile(iterator, emit)

    local i, e = nil, nil
    local asm_iterator = function()
        i, e = next(asm, i)
        return e
    end
    load_asm(cpu, asm_iterator)
end

return { asm=load_asm, forge=load_forge }
