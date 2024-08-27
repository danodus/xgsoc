-- asm.lua

local function split(str, sep)
    if not sep then sep = "%s" end
    local t={}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
      table.insert(t, s)
    end
    return t
  end
  
  local rregs = {
    x0 = 0, x1 = 1, x2 = 2, x3 = 3,
    x4 = 4, x5 = 5, x6 = 6, x7 = 7,
    x8 = 8, x9 = 9, x10 = 10, x11 = 11,
    x12 = 12, x13 = 13, x14 = 14, x15 = 15,
    x16 = 16, x17 = 17, x18 = 18, x19 = 19,
    x20 = 20, x21 = 21, x22 = 22, x23 = 23,
    x24 = 24, x25 = 25, x26 = 26, x27 = 27,
    x28 = 28, x29 = 29, x30 = 30, x31 = 31,
    zero = 0, ra = 1, sp = 2, gp = 3,
    tp = 4, t0 = 5, t1 = 6, t2 = 7,
    s0 = 8, s1 = 9, a0 = 10, a1 = 11,
    a2 = 12, a3 = 13, a4 = 14, a5 = 15,
    a6 = 16, a7 = 17, s2 = 18, s3 = 19,
    s4 = 20, s5 = 21, s6 = 22, s7 = 23,
    s8 = 24, s9 = 25, s10 = 26, s11 = 27,
    t3 = 28, t4 = 29, t5 = 30, t6 = 31
  }
  
  function preprocess(s)
    local r = string.gsub(s, "%-%-[^\n\r]+", "")
    r = string.gsub(r, "%b{}", function(n)
      return tostring(load("return " .. string.sub(n, 2, -2))())
    end)
    return r
  end
  
  function asm(s)
    local words = split(s)
    local instr
    local label
    local opcode
    local params
    if #words >= 3 then
      label = words[1]
      opcode = words[2]
      params = words[3]
    elseif #words == 2 then
      opcode = words[1]
      params = words[2]
    elseif #words == 1 then
      if string.find(words[1], "(%w+):") then
        label = words[1]
      else
        opcode = words[1]
      end
    end
    --print(string.format("label: %s, opcode: %s, params: %s", label, opcode, params))
    if label then label = string.gsub(label, "(%w+):", "%1") end
    if params then params = split(params, ",") end
    
    if opcode == "addi" then
      local funct3 = 0x0
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local imm = tonumber(params[3])
      instr = 0x13 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20)
    elseif opcode == "slli" then
      local funct3 = 0x1
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local funct7 = 0x0
      local imm = tonumber(params[3])
      instr = 0x13 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20) | (funct7 << 25)
    elseif opcode == "srli" then
      local funct3 = 0x5
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local funct7 = 0x0
      local imm = tonumber(params[3])
      instr = 0x13 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20) | (funct7 << 25)
    elseif opcode == "andi" then
      local funct3 = 0x7
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local imm = tonumber(params[3])
      instr = 0x13 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20)
    elseif opcode == "lw" then
      local funct3 = 0x2
      local rd = rregs[params[1]]
      local imm_s, rs1_s = string.match(params[2], "(%w+)%((%w+)%)")
      local rs1 = rregs[rs1_s]
      local imm = tonumber(imm_s)
      instr = 0x03 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20)
    elseif opcode == "sw" then
      local funct3 = 0x2
      local rs2 = rregs[params[1]]
      local imm_s, rs1_s = string.match(params[2], "(%w+)%((%w+)%)")
      local rs1 = rregs[rs1_s]
      local imm = tonumber(imm_s)
      instr = 0x23 | ((imm & 0x1F) << 7) | (funct3 << 12) | (rs1 << 15) | (rs2 << 20) | ((imm >> 5) << 25)
    elseif opcode == "add" then
      local funct3 = 0x0
      local funct7 = 0x00
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local rs2 = rregs[params[3]]
      instr = 0x33 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (rs2 << 20) | (funct7 << 25)
    elseif opcode == "sub" then
      local funct3 = 0x0
      local funct7 = 0x20
      local rd = rregs[params[1]]
      local rs1 = rregs[params[2]]
      local rs2 = rregs[params[3]]
      instr = 0x33 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (rs2 << 20) | (funct7 << 25)
    elseif opcode == "lui" then
      local rd = rregs[params[1]]
      local imm = tonumber(params[2])
      instr = 0x37 | (rd << 7) | (imm << 12)
    elseif opcode == "beq" or opcode == "bne" or opcode == "blt" or opcode == "bge" or opcode == "bltu" or opcode == "bgeu" then
      local funct3 = 0x0
      if opcode == "beq" then
        funct3 = 0x0
      elseif opcode == "bne" then
        funct3 = 0x1
      elseif opcode == "blt" then
        funct3 = 0x4
      elseif opcode == "bge" then
        funct3 = 0x5
      elseif opcode == "bltu" then
        funct3 = 0x6
      elseif opcode == "bgeu" then
        funct3 = 0x7
      end
      local rs1 = rregs[params[1]]
      local rs2 = rregs[params[2]]
      local imm = tonumber(params[3])
      instr = 0x63 | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 0x1) << 7)
      instr = instr | (funct3 << 12)
      instr = instr | (rs1 << 15) | (rs2 << 20)
      instr = instr | (((imm >> 12) & 0x1) << 31) | (((imm >> 5) & 0x7F) << 25)
    elseif opcode == "jalr" then
      local funct3 = 0x0
      local rd = rregs[params[1]]
      local imm_s, rs1_s = string.match(params[2], "(%w+)%((%w+)%)")
      local rs1 = rregs[rs1_s]
      local imm = tonumber(imm_s)
      instr = 0x67 | (rd << 7) | (funct3 << 12) | (rs1 << 15) | (imm << 20)
    else
      if opcode then
        print(string.format("Unknown opcode: %s", opcode))
      end
    end
    return label, instr
  end
  
  function asm_str(s)
    local lines = split(preprocess(s), "\n")
    local d = {}
    for _,line in ipairs(lines) do
      local label, instr = asm(line)
      if instr then
        table.insert(d, instr)
      elseif not label then
        error("Unable to assemble \"" .. line .. "\"")
      end
    end
    local m = memory.create(#d * 4)
    local im = 1
    for i = 1,#d do
      _, im = m:pack("i4", im, d[i])
    end
    return m
  end
  
  function asm_function(s)
    local f={}
    f.bin = asm_str(s)
    setmetatable(f,{__call = function(cls, ...) return call(cls.bin:getptr(), ...) end})
    return f
  end
  