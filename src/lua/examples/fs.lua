-- fs.lua

function dir()
    local d = fsdir()
    if d then
      local total_size = 0
      local total_blocks = 0
      io.stdout:write("\27[97m")
      io.stdout:write(string.format("%-32s%-16s%-16s\n", "Name", "Size (bytes)", "First Block"))
      io.stdout:write("\27[39m")
      for k,v in pairs(d) do
        io.stdout:write(string.format("%-32s%-16d%-16d\n", k, v.size, v.fblock))
        total_size = total_size + v.size
        total_blocks = total_blocks + math.floor((v.size + 512 - 1) / 512)
      end
      local free_blocks = 2*1024*1024/512 - total_blocks
      local free = free_blocks * 512
      io.stdout:write("\27[36m")
      io.stdout:write(string.format("Total size: %d bytes (%d blocks)\n", total_size, total_blocks))
      io.stdout:write(string.format("Free: %d bytes (%d blocks)\n", free, free_blocks))
      io.stdout:write("\27[39m")
    else
      print("Disk I/O error")
    end
  end
  
  
  function delete(filename)
    if fsdelete(filename) then
      print(string.format("\"%s\" deleted successfully", filename))
    else
      print(string.format("Unable to delete \"%s\"", filename))
    end
  end
  
  function rename(filename, new_filename)
    if fsrename(filename, new_filename) then
      print(string.format("\"%s\" renamed to \"%s\" successfully", filename, new_filename))
    else
      print(string.format("Unable to rename \"%s\"", filename))
    end
  end
  
  function copy(filename, new_filename)
    io.input(filename)
    local s = io.read("*all")
    io.input(io.stdin)
    io.output(new_filename)
    io.write(s)
    io.close()
    io.output(io.stdout)
  end
  
  function touch(filename)
    io.output(filename)
    io.write("\n")
    io.close()
    io.output(io.stdout)
  end
  
  function receive(filename)
    io.input("/dev/ttyS0")
    io.output(filename)
    local s = io.read("*all")
    io.write(s)
    io.close()
    io.input(io.stdin)
    io.output(io.stdout)
  end
  
  function send(filename)
    io.input(filename)
    io.output("/dev/ttyS0")
    local s = io.read("*all")
    io.write(s)
    io.write("\004")
    io.close()
    io.input(io.stdin)
    io.output(io.stdout)
  end
  