function e()
    edit("mon.lua")
end

function r()
    dofile("mon.lua")
    for i=0x294,0x300,4 do dump(i) end
end

function dump(addr)
    local v = peek(addr)
    print(string.format("%08x %s", v, dasm(v)))
end

function dasm(v)
    local op = v & 0x7F
    local funct3 = (v >> 12) & 0x7
    local funct7 = (v >> 25) & 0x7F
    local rd = (v >> 7) & 0x1F
    local rs1 = (v >> 15) & 0x1F
    local rs2 = (v >> 20) & 0x1F
    local imm_i = (v >> 20) & 0xFFF
    local imm_u = (v >> 12) & 0xFFFFF
    local s = ""
    if op == 0x03 then
            s = "l"
    elseif op == 0x0F then
            s = "fence"
    elseif op == 0x13 then
            -- I
            if funct3 == 0x0 then
                    if funct7 == 0x00 then
                            s = "addi"
                    end
            end
            s = s .. string.format(" x%d,x%d,$%x", rd, rs1, imm_i)
    elseif op == 0x33 then
            -- R
            if funct3 == 0x0 then
                    if funct7 == 0x00 then
                            s = "add"
                    elseif funct == 0x20 then
                            s = "sub"
                    end
            end
            s = s .. string.format(" x%d,x%d,x%d", rd, rs1, rs2)
    elseif op == 0x37 then
            -- U
            s = "lui"
            s = s .. string.format(" x%d,$%x", rd, imm_u)
    elseif op == 0x6F then
            -- UJ
    end
    return s
end
