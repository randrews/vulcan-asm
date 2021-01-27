vasm = require('vasm.vasm')

local code, start, address_lines = vasm.assemble(io.lines(), true)

local binary = '[' .. table.concat(code,',') .. ']'

local al_hash = {}
for a, l in pairs(address_lines) do
    table.insert(al_hash, '"' .. a .. '":' .. l)
end
local al = '{' .. table.concat(al_hash, ',') .. '}'

print('{"start":' .. start .. ',"binary":' .. binary .. ',"lines":' .. al .. '}')
