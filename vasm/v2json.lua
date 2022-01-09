vasm = require('vasm.vasm')

local lua = ({...})[1] == '--lua'

local success, err = pcall(function()
        local code, start, address_lines = vasm.assemble(io.lines(), true)

        local binary = code[0] .. ',' .. table.concat(code,',')

        local al_hash = {}
        for a, l in pairs(address_lines) do
            table.insert(al_hash, '"' .. a .. '":' .. l)
        end
        local al = table.concat(al_hash, ',')

        if lua then
            print('{ start = ' .. start .. ', binary = {' .. binary .. '} }')
        else
            print('{"start":' .. start .. ',"binary":[' .. binary .. '],"lines":[' .. al .. ']}')
        end
end)

if not success then
    print(string.format('{"error":%q}', err))
end
