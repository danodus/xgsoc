-- ed.lua

local function sys_set_tty_mode(mode)
    --call(0x1000165c, mode)
    setttymode(mode)
  end
  
  local function move_cursor(row, col)
    io.write(string.format("\027[%d;%dH", row, col))
    io.flush()
  end
  
  local function clear_screen()
    io.write("\027[2J")
    io.flush()
    move_cursor(1,1)
  end
  
  local function clear_line()
    io.write("\027[K")
    io.flush()
  end
  
  local function update_cursor()
    move_cursor(cur_row - win_row + 1, cur_col - win_col + 1)
  end
  
  local function draw_buf(dirty)
    local d = dirty or {win_row, win_row + screen_height - 1}
    if d[1] < win_row then d[1] = win_row end
    if d[2] > win_row + screen_height - 1 then d[2] = win_row + screen_height - 1 end
    local row = d[1] - win_row + 1
    for i=d[1],d[2] do
      --move_cursor(row, 1)
      io.write("\027[", tostring(row), ";1H")
      --clear_line()
      io.write("\027[K")
      if i <= #buf then
        local inside_block = i >= block_start_row and i < block_end_row
        if inside_block then io.write("\027[7m") end
        local v = buf[i]
        io.write(string.sub(v, win_col, win_col + #v - 1 > screen_width and win_col + screen_width - 1 or #v + win_col))
        if inside_block then io.write("\027[0m") end
      end
      row = row + 1
    end
    update_cursor()
  end
  
  local function get_key()
    sys_set_tty_mode(1)
    local c = io.read(1)
    sys_set_tty_mode(0)
    return string.byte(c)
  end
  
  local function update_win()
    local dirty = false
    if cur_row < win_row then
      win_row = cur_row
      dirty = true
    end
    if cur_col < win_col then
      win_col = cur_col
      dirty = true
    end
    if cur_col >= win_col + screen_width then
      win_col = cur_col - screen_width + 1
      dirty = true
    end
    if cur_row >= win_row + screen_height then
      win_row = cur_row - screen_height + 1
      dirty = true
    end
    if dirty then
      draw_buf()
    end
  end
  
  local function cursor_home()
    cur_col = 1
    update_win()
    update_cursor()
  end
  
  local function cursor_end()
    local s = buf[cur_row]
    cur_col = #s + 1
    update_win()
    update_cursor()
  end
  
  local function cursor_page_up()
    cur_row = cur_row - screen_height
    if cur_row < 1 then
      cur_row = 1
    end
    cur_col = 1
    win_row = cur_row
    win_col = cur_col
    draw_buf()
    update_cursor()
  end
  
  local function cursor_page_down()
    if #buf <= screen_height then
      cur_row = #buf
      cur_col = 1
      update_win()
      update_cursor()
      return
    end
    if #buf - cur_row >= 2 * screen_height then
      cur_row = cur_row + screen_height
    else
      cur_row = #buf - screen_height
    end
    cur_col = 1
    win_row = cur_row
    win_col = cur_col
    draw_buf()
    update_cursor()
  end
  
  local function cursor_up()
    if cur_row > 1 then
      cur_row = cur_row - 1
    end
    local n = #buf[cur_row]
    if cur_col > n + 1 then
      cur_col = n + 1
    end
    update_win()
    update_cursor()
  end
  
  local function cursor_down()
    if cur_row < #buf then
      cur_row = cur_row + 1
    end
    local n = #buf[cur_row]
    if cur_col > n + 1 then
      cur_col = n + 1
    end
    update_win()
    update_cursor()
  end
  
  local function cursor_left()
    if cur_col > 1 then
      cur_col = cur_col - 1
    end
    update_win()
    update_cursor()
  end
  
  local function cursor_right()
    local s = buf[cur_row]
    if #s and cur_col <= #s then
      cur_col = cur_col + 1
    end
    update_win()
    update_cursor()  
  end
  
  local function cursor_begin_file()
    cur_row = 1
    cur_col = 1
    update_win()
    update_cursor()
  end
  
  local function buf_insert(i, v)
    table.insert(buf, i, v)
    if block_start_row >= i then
      block_start_row = block_start_row + 1
    end
    if block_end_row >= i then
      block_end_row = block_end_row + 1
    end
  end
  
  local function buf_remove(i)
    table.remove(buf, i)
    if block_start_row >= i then
      block_start_row = block_start_row - 1
    end
    if block_end_row >= i then
      block_end_row = block_end_row - 1
    end
  end
  
  local function insert_chars(c)
    local s = buf[cur_row]
    if cur_col > #s then
      -- append
      buf[cur_row] = string.format("%s%s", s, c)
    else
      -- insert
      buf[cur_row] = string.format("%s%s%s", string.sub(s, 1, cur_col - 1), c, string.sub(s, cur_col, -1))
    end
    --cursor_right()
    cur_col = cur_col + #c
    update_win()
    draw_buf({cur_row, cur_row})
    modified = true
  end
  
  local function insert_cr()
    local s = buf[cur_row]
    local s1 = string.sub(s, 1, cur_col - 1)
    local s2 = string.sub(s, cur_col, -1)
    buf[cur_row] = s1
    buf_insert(cur_row + 1, s2)
    cur_row = cur_row + 1
    cur_col = 1
    update_win()
    draw_buf({cur_row - 1, #buf})
    modified = true
  end
  
  local function insert_tab()
    local m = (cur_col - 1) % tab_size
    insert_chars(string.rep(' ', tab_size - m))
    modified = true
  end
  
  local function delete_line()
    if #buf > 1 then
      buf_remove(cur_row)
      if cur_row > #buf then
        cur_row = #buf
      end
      cur_col = 1
    end
    update_win()
    draw_buf({cur_row, #buf + 1})
    modified = true
  end
  
  local function backspace()
    if cur_col > 1 then
      local s = buf[cur_row]
      local s1 = cur_col > 2 and string.sub(s, 1, cur_col - 2) or ""
      local s2 = string.sub(s, cur_col, -1)
      buf[cur_row] = string.format("%s%s", s1, s2)
      cur_col = cur_col - 1
      update_win()
      draw_buf({cur_row, cur_row})
    else
      if cur_row > 1 then
        local ns = buf[cur_row]
        buf_remove(cur_row)
        cur_row = cur_row - 1
        local s = buf[cur_row]
        cur_col = #s + 1
        buf[cur_row] = string.format("%s%s", s, ns)
        update_win()
        draw_buf({cur_row, #buf + 1})
      end
    end
    modified = true
  end
  
  local function delete()
    local s = buf[cur_row]
    if cur_col <= #s then
      local s1 = string.sub(s, 1, cur_col - 1)
      local s2 = string.sub(s, cur_col + 1, -1)
      buf[cur_row] = string.format("%s%s", s1, s2)
      -- note: no window update required
      draw_buf({cur_row, cur_row})
    else
      if cur_row < #buf then
        local ns = buf[cur_row + 1]
        buf_remove(cur_row + 1)
        buf[cur_row] = string.format("%s%s", s, ns)
        draw_buf({cur_row, #buf + 1})      
      end
    end
    modified = true
  end
  
  local function update_status()
    move_cursor(screen_height + 1, 1)
    clear_line()
    io.write(string.format("\027[7m%s%s (%d,%d) %s\027[0m", filename, modified and "*" or "", cur_row, cur_col, status))
    io.flush()
  end
  
  local function load()
    buf = {}
    local f = io.open(filename, "r")
    if f == nil then
      return false
    end
    for line in f:lines() do
      buf[#buf + 1] = string.gsub(line, "\t", "")
    end
    if #buf == 0 then buf = {""} end
    f:close()
    modified = false
    return true
  end
  
  local function save()
    if modified then
      status = "Saving..."
      update_status()
      local f = io.open(filename, "w")
      for _,s in ipairs(buf) do
        f:write(s, "\n")
      end
      f:close()
      modified = false
      status = ""
    end 
  end
  
  local function hide_cursor()
    io.write("\027[?25l")
    io.flush()
  end
  
  local function show_cursor()
    io.write("\027[?25h")
    io.flush()
  end
  
  local function set_block_start()
    block_start_row = cur_row
    if block_end_row < block_start_row then block_end_row = block_start_row end
    draw_buf()
  end
  
  local function set_block_end()
    block_end_row = cur_row
    if block_start_row > block_end_row then block_start_row = block_end_row end
    draw_buf()
  end
  
  local function clear_block_selection()
    block_start_row = 0
    block_end_row = 0
    draw_buf()
  end
  
  local function copy_block()
    if block_start_row == block_end_row then return end
    local tbuf = {}
    for i = block_start_row, block_end_row - 1 do
      table.insert(tbuf, buf[i])
    end
    for _,v in ipairs(tbuf) do
      table.insert(buf, cur_row, v)
      cur_row = cur_row + 1
    end
    clear_block_selection()
    update_win()
    draw_buf()
    modified = true  
  end
  
  local function delete_block()
    if block_start_row == block_end_row then return end
    for i = block_start_row, block_end_row - 1 do
      table.remove(buf, block_start_row)
    end
    cur_row = block_start_row
    cur_col = 1
    clear_block_selection()
    update_win()
    draw_buf()
    modified = true
  end
  
  local function move_block()
    if block_start_row == block_end_row then return end
    local tbuf = {}
    for i = block_start_row, block_end_row - 1 do
      table.insert(tbuf, buf[i])
    end
    for i = block_start_row, block_end_row - 1 do
      table.remove(buf, block_start_row)
      if cur_row >= block_start_row then
        cur_row = cur_row - 1
      end
    end
    for _,v in ipairs(tbuf) do
      table.insert(buf, cur_row, v)
      cur_row = cur_row + 1
    end
    cur_col = 1
    clear_block_selection()
    update_win()
    draw_buf()
    modified = true
  end
  
  local function write_block(filename)
    if block_start_row == block_end_row then return end
    local f = io.open(filename, "w")
    for i = block_start_row, block_end_row - 1 do
        f:write(buf[i], "\n")
    end
    f:close()
    clear_block_selection()
    draw_buf()
  end
  
  local function read_block(filename)
    local f = io.open(filename, "r")
    if not f then return end
    for v in f:lines() do
      table.insert(buf, cur_row, v)
      cur_row = cur_row + 1
    end
    f:close()
    clear_block_selection()
    update_win()
    draw_buf()
    modified = true  
  end
  
  ---------
  
  function ed(arg_filename)
  
    tab_size = 2
  
    screen_height = 59
    screen_width = 106
  
    win_row = 1
    win_col = 1
  
    cur_row = 1
    cur_col = 1
  
    block_start_row = 0
    block_end_row = 0
  
    modified = false
  
    filename = arg_filename
  
    buf = {""}
  
    status = ""
  
    io.write("\027)")
  
    hide_cursor()
  
    if not load() then
      print(string.format("Unable to open %s", filename))
      get_key()
    end
  
    draw_buf()
  
    local c = 0
    local last_c = 0
    local quit = false
    repeat
      update_status()
      update_cursor()
      show_cursor()
      c = get_key()
      hide_cursor()
      if c == 27 then
        if last_c == 27 then
          break
        end
        last_c = c
        c = get_key()
        last_c = c
        --print(string.format("%d",c))
        if c == string.byte('[') then
          c = get_key()
          last_c = c
          if c == string.byte('A') then
            cursor_up()
          elseif c == string.byte('B') then
            cursor_down()
          elseif c == string.byte('C') then
            cursor_right()
          elseif c == string.byte('D') then
            cursor_left()
          elseif c == string.byte('1') then
            c = get_key()
            last_c = c
            if c == string.byte('~') then
              cursor_home()
            end
          elseif c == string.byte('4') then
            c = get_key()
            last_c = c
            if c == string.byte('~') then
              cursor_end()
            end
          elseif c == string.byte('5') then
            c = get_key()
            last_c = c
            if c == string.byte('~') then
              cursor_page_up()
            end
          elseif c == string.byte('6') then
            c = get_key()
            last_c = c
            if c == string.byte('~') then
              cursor_page_down()
            end
          elseif c == string.byte('3') then
            c = get_key()
            last_c = c
            if c == string.byte('~') then
              delete()
            end
          else
            move_cursor(screen_height + 1, 1)
            io.write(string.format("ESC [ %c", c))
            io.flush()
          end
        end
      else
        if c >= 32 and c < 128 then
          insert_chars(string.char(c))
        elseif c == 13 then
          insert_cr()
        elseif c == 8 then
          backspace()
        elseif c == 9 then
          insert_tab()
        elseif c == 25 then
          -- ^Y
          delete_line()
        elseif c == 11 then
          -- ^K
          c = get_key()
          last_c = c
          if c == string.byte('x') or c == string.byte('X') then
            save()
            quit = true
          elseif c == string.byte('s') or c == string.byte('S') then
            save()
          elseif c == string.byte('q') or c == string.byte('Q') then
            quit = true
          elseif c == string.byte('b') or c == string.byte('B') then
            set_block_start()
          elseif c == string.byte('k') or c == string.byte('K') then
            set_block_end()
          elseif c == string.byte('c') or c == string.byte('C') then
            copy_block()
          elseif c == string.byte('v') or c == string.byte('V') then
            move_block()
          elseif c == string.byte('y') or c == string.byte('Y') then
            delete_block()
          elseif c == string.byte('w') or c == string.byte('W') then
            write_block("block.txt")
          elseif c == string.byte('r') or c == string.byte('R') then
            read_block("block.txt")
          end
        elseif c == 17 then
          -- ^Q
          c = get_key()
          if c == string.byte('r') or c == string.byte('R') then
            cursor_begin_file()
          end
        end
      end
      --print(string.format("%d",c))
    until quit
  
    show_cursor()
  
    io.write("\027(")
  
    clear_screen()
  end
  