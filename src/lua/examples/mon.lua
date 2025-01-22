-- mon.lua

function split(str, sep)
  if not sep then sep = "%s" end
  local t={}
  for s in string.gmatch(str, "([^"..sep.."]+)") do
    table.insert(t, s)
  end
  return t
end

-----


function d(addr)
  for i=addr,addr+64-4,4 do dump(i) end
end

function db(addr)
  for i=0,127 do
    if (i > 0) and (i % 8 == 0) then
      print()
    end
    io.write(string.format("%02x ", peekb(addr + i)))
  end
  print()
end

function pbin(v)
  local s = ""
  for i=32,1,-1 do
    if i == 25 or i == 20 or i == 15 or i == 12 or i == 7 then
      s = s .. " "
    end
    s = s .. (((v >> (i-1)) & 0x1 == 0x1) and "1" or "0")
  end
  print(s)
end

function dump(addr)
  local v = peek(addr)
  print(string.format("%08x %08x %s", addr, v, dasm(v)))
end

function sext12(v)
  return ((v & 0x800) ~= 0) and (0xFFFFF000 | v) or v
end

local regs = {
  [0]  = "zero", [1]  = "ra", [2]  = "sp",  [3]  = "gp",
  [4]  = "tp",   [5]  = "t0", [6]  = "t1",  [7]  = "t2",
  [8]  = "s0",   [9]  = "s1", [10] = "a0",  [11] = "a1",
  [12] = "a2",   [13] = "a3", [14] = "a4",  [15] = "a5",
  [16] = "a6",   [17] = "a7", [18] = "s2",  [19] = "s3",
  [20] = "s4",   [21] = "s5", [22] = "s6",  [23] = "s7",
  [24] = "s8",   [25] = "s9", [26] = "s10", [27] = "s11",
  [28] = "t3",   [29] = "t4", [30] = "t5",  [31] = "t6"
}

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
    -- I
    s = "l"
    if funct3 == 0x0 then
      s = s .. "b"
    elseif funct3 == 0x1 then
      s = s .. "h"
    elseif funct3 == 0x2 then
      s = s .. "w"
    elseif funct3 == 0x3 then
      s = s .. "d"
    elseif funct3 == 0x4 then
      s = s .. "bu"
    elseif funct3 == 0x5 then
      s = s .. "hu"
    elseif funct3 == 0x6 then
      s = s .. "wu"
    end
    s = s .. string.format("\t%s,%d(%s)", regs[rd], imm_i, regs[rs1])
  elseif op == 0x0F then
    s = "fence"
  elseif op == 0x13 then
    local imm_mask = 0xFFF
    -- I
    if funct3 == 0x0 then
      s = "addi"
    elseif funct3 == 0x1 then
      if imm_i & 0x400 == 0x000 then
        s = "slli"
        imm_mask = 0x01F
      end
    elseif funct3 == 0x2 then
      s = "slti"
    elseif funct3 == 0x3 then
      s = "sltiu"
    elseif funct3 == 0x4 then
      s = "xori"
    elseif funct3 == 0x5 then
      if imm_i & 0x400 == 0x000 then
        s = "srli"
 imm_mask = 0x01F
      elseif imm_i & 0x400 == 0x400 then
        s = "srai"
        imm_mask = 0x01F
      end
    elseif funct3 == 0x6 then
        s = "ori"
    elseif funct3 == 0x7 then
        s = "andi"
    end
    s = s .. string.format("\t%s,%s,0x%x", regs[rd], regs[rs1], imm_i & imm_mask)
  elseif op == 0x23 then
    -- S
    local imm_s_t = {(v >> 25) & 0x7F, (v >> 7) & 0x1F}
    local imm_s = (imm_s_t[1] << 5) | imm_s_t[2]
    s = "s"
    if funct3 == 0x0 then
      s = s .. "b"
    elseif funct3 == 0x1 then
      s = s .. "h"
    elseif funct3 == 0x2 then
      s = s .. "w"
    elseif funct3 == 0x3 then
      s = s .. "d"
    end
    s = s .. string.format("\t%s,%d(%s)", regs[rs2], imm_s, regs[rs1])
  elseif op == 0x33 then
    -- R
    if funct3 == 0x0 then
      if funct7 == 0x00 then
        s = "add"
      elseif funct7 == 0x20 then
        s = "sub"
      end
    elseif funct3 == 0x1 then
      if funct7 == 0x00 then
        s = "sll"
      end
    elseif funct3 == 0x2 then
      if funct7 == 0x00 then
        s = "slt"
      end
    elseif funct3 == 0x3 then
      if funct7 == 0x00 then
        s = "sltu"
      end
    elseif funct3 == 0x4 then
      if funct7 == 0x00 then
        s = "xor"
      end
    elseif funct3 == 0x5 then
      if funct7 == 0x00 then
        s = "srl"
      elseif funct7 == 0x20 then
 s = "sra"
      end
    elseif funct3 == 0x6 then
      if funct7 == 0x00 then
        s = "or"
      end
    elseif funct3 == 0x7 then
      if funct7 == 0x00 then
        s = "and"
      end
    end
    s = s .. string.format("\t%s,%s,%s", regs[rd], regs[rs1], regs[rs2])
  elseif op == 0x37 then
    -- U
    s = "lui"
    s = s .. string.format("\t%s,0x%x", regs[rd], imm_u)
  elseif op == 0x63 then
    -- SB
    local imm_sb_t = {(v >> 31) & 0x1, (v >> 25) & 0x3F, (v >> 8) & 0xF, (v >> 7) & 0x1}
    local imm_sb = imm_sb_t[1] << 12
    imm_sb = imm_sb | (imm_sb_t[2] << 5)
    imm_sb = imm_sb | (imm_sb_t[3] << 1)
    imm_sb = imm_sb | (imm_sb_t[4] << 11)
    s = "b"
    if funct3 == 0x0 then
      s = s .. "eq"
    elseif funct3 == 0x1 then
      s = s .. "ne"
    elseif funct3 == 0x4 then
      s = s .. "lt"
    elseif funct3 == 0x5 then
      s = s .. "ge"
    elseif funct3 == 0x6 then
      s = s .. "ltu"
    elseif funct3 == 0x7 then
      s = s .. "geu"
    end
    local sext_imm_sb = (imm_sb & 0x1000 == 0x1000) and (0xFFFFF000 | imm_sb) or imm_sb
    s = s .. string.format("\t%s,%s,%d", regs[rs1], regs[rs2], sext_imm_sb)
  elseif op == 0x67 then
    -- I
    s = "jalr"
    s = s .. string.format("\t%s,%d(%s)", regs[rd], imm_i, regs[rs1])
  elseif op == 0x6F then
    -- UJ
    local imm_uj_t = {(v >> 31) & 0x1, (v >> 21) & 0x3FF, (v >> 20) & 0x1, (v >> 12) & 0xFF}
    local imm_uj = imm_uj_t[1] << 20
    imm_uj = imm_uj | (imm_uj_t[2] << 1)
    imm_uj = imm_uj | (imm_uj_t[3] << 11)
    imm_uj = imm_uj | (imm_uj_t[4] << 12)
    s = "jal"
    s = s .. string.format("\t%s,0x%x", regs[rd], imm_uj) 
  end
  return s
end

function pimm(n)
  -- sign extend low 12 bits
  local m = sext12(n & 0xFFF)
  -- upper 20 bits
  local k = ((n - m) >> 12)
  print(string.format("lui: %x", k & 0xFFFFF))
  print(string.format("addi: %x", m & 0xFFF))
  print(string.format("imm: %08x", (k << 12) + m))
end
