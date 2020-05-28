
Hope = {}
Assertion = {}

function Hope:test(target)
    return Assertion.new(target)
end

function Assertion.new(target)
    return setmetatable({ target = target }, { __index = Assertion })
end

function Assertion:caller(depth)
    -- Default depth is 3: assertion:caller, whatever assertion called caller, and then the test
    local caller = debug.traceback(nil, depth or 3)
    return caller:match('\n%s+(.+)\n')
end

function Hope.add_assertion(name, compare)
    Assertion[name] = function(self, rvalue)
        local success, result = pcall(compare, self.target, rvalue)
        if not success then
            print('Error checking assertion: ' .. result .. ' at ' .. self:caller())
        elseif not result then
            print('Failed assertion: ' .. prettify(self.target) .. ' ' .. name .. ' ' .. prettify(rvalue) .. ' at ' .. self:caller())
        end
    end
end

function compare_values(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        local a_keys = {}
        local b_keys = {}
        for k in pairs(a) do table.insert(a_keys, k) end
        for k in pairs(b) do table.insert(b_keys, k) end
        if #a_keys ~= #b_keys then return false end
        table.sort(a_keys, function(i, j) return tostring(i) < tostring(j) end)
        table.sort(b_keys, function(i, j) return tostring(i) < tostring(j) end)
        for i, k in ipairs(a_keys) do
            if not compare_values(k, b_keys[i]) then return false
            elseif not compare_values(a[k], b[k]) then return false end
        end
        return true
    else
        return a == b
    end
end

function prettify(value)
    local kind = type(value)

    if kind == 'nil' then
        return '<nil>'
    elseif kind == 'string' then
        return string.format('%q', value)
    elseif kind == 'table' then
        local keys = {}
        local tuples = {}
        for k in pairs(value) do table.insert(keys, k) end
        table.sort(keys, function(i, j) return prettify(i) < prettify(j) end)
        for _, k in ipairs(keys) do table.insert(tuples, prettify(k) .. '=' .. prettify(value[k])) end
        return '{' .. table.concat(tuples, ', ') .. '}'
    else
        return tostring(value)
    end
end

Hope.add_assertion('equals', compare_values)
Hope.add_assertion('greater_than', function(a, b) return a > b end)
Hope.add_assertion('less_than', function(a, b) return a < b end)

return setmetatable(Hope, { __call = Hope.test })
