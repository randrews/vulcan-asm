local mnemonic_to_code = {
    push = 0,
    nop = 0
}

local code_to_mnemonic = {
    [0] = 'push'
}

local mnemonic_list = {'push', 'nop'}

local counter = 1
function add_opcode(mnemonic)
    mnemonic_to_code[mnemonic] = counter
    code_to_mnemonic[counter] = mnemonic
    table.insert(mnemonic_list, mnemonic)
    counter = counter + 1
end

add_opcode('add')
add_opcode('sub')
add_opcode('mul')
add_opcode('div')
add_opcode('mod')
add_opcode('copy')
add_opcode('and')
add_opcode('or')
add_opcode('xor')
add_opcode('not')
add_opcode('gt')
add_opcode('lt')
add_opcode('agt')
add_opcode('alt')
add_opcode('lshift')
add_opcode('rshift')
add_opcode('arshift')
add_opcode('pop')
add_opcode('dup')
add_opcode('swap')
add_opcode('pick')
add_opcode('rot')
add_opcode('jmp')
add_opcode('jmpr')
add_opcode('call')
add_opcode('ret')
add_opcode('brz')
add_opcode('brnz')
add_opcode('hlt')
add_opcode('load')
add_opcode('loadw')
add_opcode('store')
add_opcode('storew')
add_opcode('setint')
add_opcode('setiv')
add_opcode('sdp')
add_opcode('setsdp')
add_opcode('pushr')
add_opcode('popr')
add_opcode('peekr')
add_opcode('debug')

return {
    mnemonic_for = function(opcode)
        return code_to_mnemonic[opcode]
    end,

    opcode_for = function(mnemonic)
        return mnemonic_to_code[mnemonic]
    end,

    mnemonic_list = mnemonic_list
}
