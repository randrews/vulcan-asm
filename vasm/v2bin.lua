vasm = require('vasm.vasm')
lfs = require('lfs')

local success, err = pcall(function()
        lfs.chdir('4th')
        local code, start = vasm.assemble(vasm.preprocess(io.lines()), true)

        for i = 0, #code do
            io.write(string.char(code[i]))
        end

        -- local binary = '[' .. code[0] .. ',' .. table.concat(code,',') .. ']'

        -- local al_hash = {}
        -- for a, l in pairs(address_lines) do
        --     table.insert(al_hash, '"' .. a .. '":' .. l)
        -- end
        -- local al = '{' .. table.concat(al_hash, ',') .. '}'

        -- print('{"start":' .. start .. ',"binary":' .. binary .. ',"lines":' .. al .. '}')
end)

if not success then print(err) end
