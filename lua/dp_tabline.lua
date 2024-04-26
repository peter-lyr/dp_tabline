local M = {}

local sta, B = pcall(require, 'dp_base')

if not sta then return print('Dp_base is required!', debug.getinfo(1)['source']) end

if B.check_plugins {
      -- 'git@github.com:peter-lyr/dp_init',
      'folke/which-key.nvim',
      'git@github.com:peter-lyr/dp_nvimtree',
    } then
  return
end

M.proj_bufs           = {}
M.proj_buf            = {}
M.cur_proj            = ''
M.cur_buf             = 0

M.simple_statusline   = 3

M.winbar              = " %1@SwitchWindow@%{v:lua.WinbarFname(expand('%'))} %= %{v:lua.WinbarProjRoot(expand('%'))}"
vim.opt.statusline    = [[%<%#Title#%{v:lua.StatusLineFname()} %h%m%r %#Character#%{mode()} %#Normal#%=%<%-14.(%l,%c%V%) %P]]

M.tabhiname           = 'tbltab'
M.light               = require 'nvim-web-devicons.icons-default'.icons_by_file_extension

M.color_table         = {
  ['0'] = '0x5',
  ['1'] = '0x6',
  ['2'] = '0x7',
  ['3'] = '0x8',
  ['4'] = '0x9',
  ['5'] = '0xa',
  ['6'] = '0xb',
  ['7'] = '0xc',
  ['8'] = '0xd',
  ['9'] = '0xe',
  ['a'] = '0xf',
  ['b'] = '0x0',
  ['c'] = '0x1',
  ['d'] = '0x2',
  ['e'] = '0x3',
  ['f'] = '0x4',
}

M.color_cnt           = 0
M.color_max           = 50

M.projs_diff_tabs_way = {}

M.bufs_to_show_last   = {}
M.cur_buf_last        = 1

M.tabs_way            = 2

M.window_equal        = {}

function WinbarFname(fname)
  local temp = vim.fn.deepcopy(fname)
  fname = B.rep_backslash_lower(vim.fn.fnamemodify(vim.fn.expand(fname), ':p'))
  local projroot = B.rep_backslash_lower(vim.fn['ProjectRootGet'](fname))
  if B.is(projroot) and string.sub(fname, 1, #projroot) == projroot then
    return string.sub(fname, #projroot + 2, #fname)
  end
  return temp
end

function WinbarProjRoot(fname)
  if not B.file_exists(fname) then
    return ''
  end
  local projroot = vim.fn['ProjectRootGet'](fname)
  if B.is(projroot) then
    return string.format('%s ', B.rep_backslash_lower(projroot))
  end
  return '[not a proj]'
end

function GetWinbarFname(fname)
  WinbarRoot = ''
  fname = vim.fn.fnamemodify(fname, ':p')
  if B.is_file(fname) == 1 then
    WinbarRoot = B.rep_backslash_lower(vim.fn['ProjectRootGet'](fname))
  end
  return B.get_relative_fname(fname, WinbarRoot)
end

function GetWinbarRoot()
  return WinbarRoot
end

function StatusLineFname()
  return string.gsub(vim.api.nvim_buf_get_name(0), '\\', '/')
end

function M._get_root_short(project_root_path)
  local temp__ = vim.fn.tolower(vim.fn.fnamemodify(project_root_path, ':t'))
  if #temp__ >= 15 then
    local s1 = ''
    local s2 = ''
    for i = 15, 3, -1 do
      s2 = string.sub(temp__, #temp__ - i, #temp__)
      if vim.fn.strdisplaywidth(s2) <= 7 then
        break
      end
    end
    for i = 15, 3, -1 do
      s1 = string.sub(temp__, 1, i)
      if vim.fn.strdisplaywidth(s1) <= 7 then
        break
      end
    end
    return s1 .. '…' .. s2
  end
  local updir = vim.fn.tolower(vim.fn.fnamemodify(project_root_path, ':h:t'))
  if #updir >= 15 then
    local s1 = ''
    local s2 = ''
    for i = 15, 3, -1 do
      s2 = string.sub(updir, #updir - i, #updir)
      if vim.fn.strdisplaywidth(s2) <= 7 then
        break
      end
    end
    for i = 15, 3, -1 do
      s1 = string.sub(updir, 1, i)
      if vim.fn.strdisplaywidth(s1) <= 7 then
        break
      end
    end
    return s1 .. '…' .. s2
  end
  return updir .. '/' .. temp__
end

function M._is_cuf_buf_readable()
  if vim.fn.filewritable(B.buf_get_name()) == 1 then
    return 1
  end
  return nil
end

function M.b_prev_buf()
  if not M._is_cuf_buf_readable() then
    return
  end
  if M.proj_bufs[M.cur_proj] then
    local index
    if vim.v.count ~= 0 then
      index = vim.v.count
      if index > #M.proj_bufs[M.cur_proj] then
        index = #M.proj_bufs[M.cur_proj]
      end
    else
      index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf) - 1
    end
    if index < 1 then
      index = #M.proj_bufs[M.cur_proj]
    end
    local buf = M.proj_bufs[M.cur_proj][index]
    if buf then
      B.cmd('b%d', buf)
    end
    M.update()
  end
end

function M.b_next_buf()
  if not M._is_cuf_buf_readable() then
    return
  end
  if M.proj_bufs[M.cur_proj] then
    local index
    if vim.v.count ~= 0 then
      index = vim.v.count
      if index > #M.proj_bufs[M.cur_proj] then
        index = #M.proj_bufs[M.cur_proj]
      end
    else
      index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf) + 1
    end
    if index > #M.proj_bufs[M.cur_proj] then
      index = 1
    end
    local buf = M.proj_bufs[M.cur_proj][index]
    if buf then
      B.cmd('b%d', buf)
    end
    M.update()
  end
end

function M.bd_prev_buf(bwipeout)
  if not M._is_cuf_buf_readable() then
    return
  end
  if #M.proj_bufs[M.cur_proj] > 0 then
    local index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf)
    if index <= 1 then
      return
    end
    index = index - 1
    local buf = M.proj_bufs[M.cur_proj][index]
    if buf then
      if bwipeout then
        B.cmd('Bwipeout! %d', buf)
      else
        B.cmd('Bdelete! %d', buf)
      end
    end
    M.update()
  end
end

function M.bd_next_buf(bwipeout)
  if not M._is_cuf_buf_readable() then
    return
  end
  if #M.proj_bufs[M.cur_proj] > 0 then
    local index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf)
    if index >= #M.proj_bufs[M.cur_proj] then
      return
    end
    index = index + 1
    local buf = M.proj_bufs[M.cur_proj][index]
    if buf then
      if bwipeout then
        B.cmd('Bwipeout! %d', buf)
      else
        B.cmd('Bdelete! %d', buf)
      end
    end
    M.update()
  end
end

function M.bd_all_next_buf(bwipeout)
  if not M._is_cuf_buf_readable() then
    return
  end
  if #M.proj_bufs[M.cur_proj] > 0 then
    local index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf)
    if index >= #M.proj_bufs[M.cur_proj] then
      return
    end
    index = index + 1
    local bufs = {}
    for i = index, #M.proj_bufs[M.cur_proj] do
      local buf = M.proj_bufs[M.cur_proj][i]
      if buf then
        bufs[#bufs + 1] = buf
      end
    end
    for _, buf in ipairs(bufs) do
      if bwipeout then
        B.cmd('Bwipeout! %d', buf)
      else
        B.cmd('Bdelete! %d', buf)
      end
    end
    M.update()
  end
end

function M.bd_all_prev_buf(bwipeout)
  if not M._is_cuf_buf_readable() then
    return
  end
  if #M.proj_bufs[M.cur_proj] > 0 then
    local index = B.index_of(M.proj_bufs[M.cur_proj], M.cur_buf)
    if index <= 1 then
      return
    end
    index = index - 1
    local bufs = {}
    for i = 1, index do
      local buf = M.proj_bufs[M.cur_proj][i]
      if buf then
        bufs[#bufs + 1] = buf
      end
    end
    for _, buf in ipairs(bufs) do
      if bwipeout then
        B.cmd('Bwipeout! %d', buf)
      else
        B.cmd('Bdelete! %d', buf)
      end
    end
    M.update()
  end
end

function WinbarFname(fname)
  local temp = vim.fn.deepcopy(fname)
  fname = B.rep(vim.fn.fnamemodify(vim.fn.expand(fname), ':p'))
  local projroot = B.rep(vim.fn['ProjectRootGet'](fname))
  if B.is(projroot) and string.sub(fname, 1, #projroot) == projroot then
    return string.sub(fname, #projroot + 2, #fname)
  end
  return temp
end

function WinbarProjRoot(fname)
  if not B.file_exists(fname) then
    return ''
  end
  local projroot = vim.fn['ProjectRootGet'](fname)
  if B.is(projroot) then
    return string.format('%s ', B.rep(projroot))
  end
  return '[not a proj]'
end

function M._simple_statusline_do()
  if M.simple_statusline == 1 then
    vim.opt.showtabline = 2
    vim.opt.winbar      = ''
    M.HL()
  elseif M.simple_statusline == 2 then
    vim.opt.showtabline = 0
    vim.opt.winbar      = M.winbar
    M.HL()
  elseif M.simple_statusline == 3 then
    vim.opt.showtabline = 2
    vim.opt.winbar      = M.winbar
    M.HL()
  elseif M.simple_statusline == 4 then
    vim.opt.showtabline = 0
    vim.opt.winbar      = ''
  end
end

function M.simple_statusline_toggle()
  M.simple_statusline = M.simple_statusline + 1
  if M.simple_statusline > 4 then
    M.simple_statusline = 1
  end
  M._simple_statusline_do()
  print(M.simple_statusline)
end

M.timer_temp = B.set_interval(100, function()
  local hl = vim.api.nvim_get_hl(0, { name = 'WinBar', })
  if hl['bg'] == 4465288 and hl['bold'] == true and hl['fg'] == 16776960 then
    B.clear_interval(M.timer_temp)
  end
  M._simple_statusline_do()
end)

function M.update()
  M.update_bufs()
  M.refresh_tabline()
end

function M.titlestring(ev)
  pcall(vim.call, 'ProjectRootCD')
  local project = B.rep(vim.fn['ProjectRootGet'](vim.api.nvim_buf_get_name(ev.buf)))
  local titlestring = string.format('%s %s', M._get_root_short(project), vim.fn.fnamemodify(vim.fn.bufname(ev.buf), ':t'))
  if vim.api.nvim_buf_get_option(ev.buf, 'buftype') == 'terminal' then
    local temp = string.match(vim.fn.bufname(), 'term:.+//%d+:(.+)')
    temp = vim.fn.fnamemodify(temp, ':t:r')
    titlestring = string.format('%s %s', temp, titlestring)
  end
  vim.opt.titlestring = titlestring
end

function M._reverse_color(color)
  local new = '#'
  for i in string.gmatch(color, '%w') do
    new = new .. string.sub(M.color_table[i], 3, 3)
  end
  return new
end

function M.hi()
  vim.cmd [[
    hi tblsel guifg=#f8dfcf guibg=#777777 gui=bold
    hi tbltab guifg=#64e66e guibg=NONE gui=bold
    hi tblfil guifg=gray
    set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175
    hi CursorColumn guibg=#243548
  ]]
  for _, v in pairs(M.light) do
    if '' ~= v['icon'] then
      B.cmd('hi tbl%s guifg=%s guibg=%s gui=bold', v['name'], M._reverse_color(vim.fn.tolower(v['color'])), v['color'])
      B.cmd('hi tbl%s_ guifg=%s guibg=NONE gui=bold', v['name'], v['color'])
    end
  end
end

function M.HL()
  vim.cmd [[
    hi Comment      guifg=#6c7086 gui=NONE
    hi @comment     guifg=#6c7086 gui=NONE
    hi @lsp.type.comment guifg=#6c7086  gui=NONE
    hi TabLine     guibg=NONE guifg=#a4a4a4
    hi TabLineSel  guibg=NONE guifg=#a4a4a4
    hi TabLineFill guibg=NONE guifg=#a4a4a4
    hi WinBar      guibg=#442288 guifg=yellow gui=bold
    hi WinBarNC    guibg=#1a1a1a guifg=#999999 gui=bold
    hi StatusLine  guibg=#333333 guifg=brown gui=bold
    hi WinSeparator guibg=#333333 guifg=brown
    hi NvimTreeWinSeparator guibg=#333333 guifg=brown
    hi DiffviewWinSeparator guibg=#333333 guifg=brown
  ]]
end

M.hi()

B.aucmd('ColorScheme', 'tabline.colorscheme', {
  callback = function()
    B.set_timeout(10, function()
      M.hi()
      M.HL()
    end)
  end,
})

vim.cmd [[
  function! SwitchBuffer(bufnr, mouseclicks, mousebutton, modifiers)
    call v:lua.SwitchBuffer(a:bufnr, a:mouseclicks, a:mousebutton, a:modifiers)
  endfunction
  function! SwitchTab(tabnr, mouseclicks, mousebutton, modifiers)
    call v:lua.SwitchTab(a:tabnr, a:mouseclicks, a:mousebutton, a:modifiers)
  endfunction
  function! SwitchTabNext(tabnr, mouseclicks, mousebutton, modifiers)
    call v:lua.SwitchTabNext(a:tabnr, a:mouseclicks, a:mousebutton, a:modifiers)
  endfunction
  function! SwitchWindow(win_number, mouseclicks, mousebutton, modifiers)
    call v:lua.SwitchWindow(a:win_number, a:mouseclicks, a:mousebutton, a:modifiers)
  endfunction
  function! SwitchNone(win_number, mouseclicks, mousebutton, modifiers)
  endfunction
]]

function SwitchBuffer(bufnr, mouseclicks, mousebutton, modifiers)
  if mousebutton == 'm' then -- and mouseclicks == 1 then
    vim.cmd('Bdelete! ' .. bufnr)
    M.update()
  elseif mousebutton == 'l' then -- and mouseclicks == 1 then
    if vim.fn.buflisted(vim.fn.bufnr()) ~= 0 then
      vim.cmd('b' .. bufnr)
      M.update()
    end
  elseif mousebutton == 'r' and mouseclicks == 1 then
    B.system_run('start silent', 'cmd /c start "" "%s"', vim.api.nvim_buf_get_name(bufnr))
  end
end

function SwitchTab(tabnr, mouseclicks, mousebutton, modifiers)
  if mousebutton == 'm' then -- and mouseclicks == 1 then
    pcall(vim.cmd, tabnr .. 'tabclose')
    M.update()
  elseif mousebutton == 'l' and string.sub(modifiers, 2, 2) == 'c' then
    pcall(vim.cmd, tabnr .. 'tabclose')
  elseif mousebutton == 'l' and mouseclicks == 1 then
    vim.cmd(tabnr .. 'tabnext')
    pcall(vim.call, 'ProjectRootCD')
    M.update()
  elseif mousebutton == 'l' and mouseclicks == 2 then
    vim.cmd 'NvimTreeOpen'
  elseif mousebutton == 'r' and mouseclicks == 1 then
  end
end

function SwitchTabNext(tabnr, mouseclicks, mousebutton, modifiers)
  if mousebutton == 'm' then -- and mouseclicks == 1 then
    pcall(vim.cmd, tabnr .. 'tabclose')
    M.update()
  elseif mousebutton == 'l' and string.sub(modifiers, 2, 2) == 'c' then
    pcall(vim.cmd, tabnr .. 'tabclose')
  elseif mousebutton == 'l' and mouseclicks == 1 then
    local max_tabnr = vim.fn.tabpagenr '$'
    if tabnr < max_tabnr then
      tabnr = tabnr + 1
    else
      tabnr = 1
    end
    vim.cmd(tabnr .. 'tabnext')
    pcall(vim.call, 'ProjectRootCD')
    M.update()
  elseif mousebutton == 'l' and mouseclicks == 2 then
    vim.cmd 'NvimTreeOpen'
  elseif mousebutton == 'r' and mouseclicks == 1 then
  end
end

function SwitchWindow(win_number, mouseclicks, mousebutton, modifiers)
  if mousebutton == 'm' and mouseclicks == 1 then
    local click_winid = vim.fn.getmousepos()['winid']
    if B.is_buf_fts('NvimTree', vim.fn.winbufnr(click_winid)) then
      require 'dp_nvimtree'.open_all()
      return
    end
  elseif mousebutton == 'l' then
    local click_winid = vim.fn.getmousepos()['winid']
    if B.is_buf_fts('NvimTree', vim.fn.winbufnr(click_winid)) then
      require 'dp_nvimtree'.ausize_toggle()
      return
    end
    local cur_winid = vim.fn.win_getid()
    if cur_winid ~= click_winid then
      M.window_equal[B.get_proj_root()] = nil
      vim.fn.win_gotoid(click_winid)
    else
      if not M.window_equal[B.get_proj_root()] then
        B.win_max_height()
        M.window_equal[B.get_proj_root()] = 1
      else
        vim.cmd 'wincmd ='
        M.window_equal[B.get_proj_root()] = nil
      end
    end
  elseif mousebutton == 'r' and mouseclicks == 1 then
  end
end

function M._is_buf_to_show(buf)
  local file = B.rep(vim.api.nvim_buf_get_name(buf))
  if #file == 0 then
    return false
  end
  if not require 'plenary.path'.new(file):exists() then
    return false
  end
  if vim.fn.buflisted(buf) == 0 then
    return false
  end
  if vim.api.nvim_buf_get_option(buf, 'buftype') == 'quickfix' then
    return false
  end
  return true
end

function M.update_bufs()
  M.cur_buf = ev and ev.buf or vim.fn.bufnr()
  local cur_proj = B.rep(vim.fn['ProjectRootGet'](vim.api.nvim_buf_get_name(M.cur_buf)))
  if not B.is(M._is_buf_to_show(M.cur_buf)) then
    M.cur_proj = cur_proj
    return
  end
  local proj_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local file = B.rep(vim.api.nvim_buf_get_name(buf))
    if B.is(M._is_buf_to_show(buf)) then
      local proj = B.rep(vim.fn['ProjectRootGet'](file))
      if vim.tbl_contains(vim.tbl_keys(proj_bufs), proj) == false then
        proj_bufs[proj] = {}
      end
      proj_bufs[proj][#proj_bufs[proj] + 1] = buf
      if not M.proj_buf[proj] then
        M.proj_buf[proj] = buf
      end
    end
  end
  if B.is(proj_bufs) then
    M.proj_bufs = proj_bufs
    M.cur_proj = cur_proj
  end
end

function M._get_buf_name(only_name)
  local ext = string.match(only_name, '%.([^.]+)$')
  if vim.tbl_contains(vim.tbl_keys(M.light), ext) == true and M.light[ext]['icon'] ~= '' then
    return B.get_fname_short(vim.fn.fnamemodify(only_name, ':r')) .. ' ' .. M.light[ext]['icon']
  end
  return B.get_fname_short(only_name)
end

function M._get_buf_to_show(bufs, cur_buf, tab_len)
  local index = B.index_of(bufs, cur_buf)
  if index == -1 then
    return {}
  end
  local columns = vim.opt.columns:get()
  local buf_len = columns - tab_len
  local newbufnrs = { bufs[index], }
  local ll = #tostring(cur_buf)
  local ss = vim.fn.strdisplaywidth(tostring(#bufs))
  buf_len = buf_len - vim.fn.strdisplaywidth(M._get_buf_name(B.get_only_name(vim.fn.bufname(cur_buf)))) - 4 - ll - ss
  if buf_len < 0 then
    return newbufnrs
  end
  local cnt1 = 1
  local cnt2 = 1
  for i = 2, #bufs do
    if i % 2 == 0 then
      local ii = index + cnt1
      if ii > #bufs then
        ii = index - cnt2
        local only_name = M._get_buf_name(B.get_only_name(vim.fn.bufname(bufs[ii])))
        buf_len = buf_len - vim.fn.strdisplaywidth(only_name) - 4
        if #newbufnrs > 9 then
          buf_len = buf_len - 1
        end
        if buf_len < 0 then
          break
        end
        table.insert(newbufnrs, 1, bufs[ii])
        cnt2 = cnt2 + 1
      else
        local only_name = M._get_buf_name(B.get_only_name(vim.fn.bufname(bufs[ii])))
        buf_len = buf_len - vim.fn.strdisplaywidth(only_name) - 4
        if #newbufnrs > 9 then
          buf_len = buf_len - 1
        end
        if buf_len < 0 then
          break
        end
        table.insert(newbufnrs, bufs[ii])
        cnt1 = cnt1 + 1
      end
    else
      local ii = index - cnt2
      if ii < 1 then
        ii = index + cnt1
        local only_name = M._get_buf_name(B.get_only_name(vim.fn.bufname(bufs[ii])))
        buf_len = buf_len - vim.fn.strdisplaywidth(only_name) - 4
        if #newbufnrs > 9 then
          buf_len = buf_len - 1
        end
        if buf_len < 0 then
          break
        end
        table.insert(newbufnrs, bufs[ii])
        cnt1 = cnt1 + 1
      else
        local only_name = M._get_buf_name(B.get_only_name(vim.fn.bufname(bufs[ii])))
        buf_len = buf_len - vim.fn.strdisplaywidth(only_name) - 4
        if #newbufnrs > 9 then
          buf_len = buf_len - 1
        end
        if buf_len < 0 then
          break
        end
        table.insert(newbufnrs, 1, bufs[ii])
        cnt2 = cnt2 + 1
      end
    end
  end
  return newbufnrs
end

function M._one_tab()
  local tabs = ''
  local tab_len = 0
  local curtab = vim.fn.tabpagenr()
  local tabs_prefix = '%#tbltab#%' .. tostring(curtab) .. '@SwitchTabNext@'
  if vim.fn.tabpagenr '$' == 1 then
    tabs = tabs_prefix .. string.format(' %s ', M._get_root_short(vim.loop.cwd()))
  else
    tabs = tabs_prefix .. string.format(' %d/%d %s ', curtab, vim.fn.tabpagenr '$', M._get_root_short(vim.loop.cwd()))
  end
  tab_len = vim.fn.strdisplaywidth(tabs_prefix)
  return tabs, tab_len
end

function M._get_tab_to_show()
  if M.tabs_way == 1 then
    return M._one_tab()
  elseif M.tabs_way == 2 then
    if vim.fn.tabpagenr '$' == 1 then
      return M._one_tab()
    else
      local tabs = ''
      local tab_len = 0
      local projs = {}
      local cur_tabnr = vim.fn.tabpagenr()
      local tab_max = vim.fn.tabpagenr '$'
      for tabnr = 1, tab_max do
        local proj = ''
        local temp_file = ''
        for _, bufnr in ipairs(vim.fn.tabpagebuflist(tabnr)) do
          if tabnr == vim.fn.tabpagenr() then
            temp_file = B.buf_get_name()
          else
            temp_file = vim.api.nvim_buf_get_name(bufnr)
          end
          local temp_proj = B.rep(vim.fn['ProjectRootGet'](temp_file))
          if temp_proj ~= '.' and vim.fn.isdirectory(temp_proj) == 1 and vim.tbl_contains(projs, temp_proj) == false then
            projs[#projs + 1] = temp_proj
            proj = temp_proj
            break
          end
        end
        if #proj == 0 then
          proj = temp_file
        end
        if cur_tabnr == tabnr then
          tabs = tabs .. string.format('%%#%s#%%', M.tabhiname)
        else
          tabs = tabs .. '%#tblfil#%'
        end
        tabs = tabs .. tostring(tabnr) .. '@SwitchTab@'
        local temp = ''
        if cur_tabnr == tabnr then
          temp = string.format(' %d/%d %s ', tabnr, tab_max, M._get_root_short(proj))
        else
          temp = string.format(' %d %s ', tabnr, M._get_root_short(proj))
        end
        tab_len = tab_len + vim.fn.strdisplaywidth(temp)
        tabs = tabs .. temp
      end
      return tabs, tab_len
    end
  end
end

function M._one_buf(buf_index_first, index, cur_buf, buf)
  local bufs = {}
  local only_name = B.get_only_name(vim.fn.bufname(buf))
  local icon = ''
  local hiname = 'tblsel'
  local only_name_no_ext = vim.fn.fnamemodify(only_name, ':r')
  local ext = string.match(only_name, '%.([^.]+)$')
  if vim.tbl_contains(vim.tbl_keys(M.light), ext) == true and M.light[ext]['icon'] ~= '' then
    icon = M.light[ext]['icon']
    hiname = 'tbl' .. M.light[ext]['name']
  end
  local name = B.get_fname_short(only_name)
  if cur_buf == buf then
    M.tabhiname = hiname
    if B.is(icon) then
      icon = ' ' .. icon
      name = B.get_fname_short(only_name_no_ext)
    end
    if M.proj_bufs[M.cur_proj] then
      bufs[#bufs + 1] = string.format('%%#%s#%%%d@SwitchBuffer@ %d/%d %s%s ', hiname, buf, buf_index_first + index - 1, #M.proj_bufs[M.cur_proj], name, icon)
    else
      bufs[#bufs + 1] = string.format('%%#%s#%%%d@SwitchBuffer@ %d/%d %s%s ', hiname, buf, buf_index_first + index - 1, 1, name, icon)
    end
  else
    if B.is(icon) then
      icon = string.format(' %%#%s_#%s%%#tblfil#', hiname, icon)
      name = B.get_fname_short(only_name_no_ext)
    end
    bufs[#bufs + 1] = string.format('%%#tblfil#%%%d@SwitchBuffer@ %d %s%s ', buf, buf_index_first + index - 1, name, icon)
  end
  return vim.fn.join(bufs, '')
end

function M._get_buf_content(tab_len)
  local bufs_to_show = {}
  local buf_index_first = 1
  local cur_buf = M.cur_buf
  if M.proj_bufs[M.cur_proj] then
    bufs_to_show = M._get_buf_to_show(M.proj_bufs[M.cur_proj], cur_buf, tab_len)
    if #bufs_to_show == 0 then
      if #M.bufs_to_show_last > 0 then
        bufs_to_show = M.bufs_to_show_last
        cur_buf = M.cur_buf_last
      else
        bufs_to_show = M.proj_bufs[M.cur_proj]
      end
    else
      M.bufs_to_show_last = bufs_to_show
      M.cur_buf_last = cur_buf
    end
    buf_index_first = B.index_of(M.proj_bufs[M.cur_proj], bufs_to_show[1])
  else
    return M._one_buf(buf_index_first, 1, cur_buf, vim.fn.bufnr())
  end
  local res = ''
  for index, buf in ipairs(bufs_to_show) do
    res = res .. M._one_buf(buf_index_first, index, cur_buf, buf)
  end
  return res
end

function M.refresh_tabline()
  M.cur_buf = ev and ev.buf or vim.fn.bufnr()
  local tabs_to_show, tab_len = M._get_tab_to_show()
  vim.opt.tabline = M._get_buf_content(tab_len) .. '%#tblfil#%1@SwitchNone@%=%<%#tblfil#' .. tabs_to_show
end

function M.toggle_tabs_way()
  M.tabs_way = M.tabs_way + 1
  if M.tabs_way > 2 then
    M.tabs_way = 1
  end
  if M.tabs_way == 1 then
    B.notify_info 'only cur tab'
  elseif M.tabs_way == 2 then
    B.notify_info 'multi tabs'
  end
  local root_dir = B.rep(vim.fn['ProjectRootGet']())
  if B.is(root_dir) then
    M.projs_diff_tabs_way[root_dir] = M.tabs_way
  end
  M.update()
end

B.aucmd({ 'TabEnter', }, 'tabline.TabEnter', {
  callback = function()
    local root_dir = B.rep(vim.fn['ProjectRootGet']())
    if B.is(vim.tbl_contains(vim.tbl_keys(M.projs_diff_tabs_way), root_dir)) then
      M.tabs_way = M.projs_diff_tabs_way[root_dir]
      M.update()
    end
  end,
})

B.aucmd('BufEnter', 'tabline.BufEnter', {
  callback = function()
    M.update()
  end,
})

B.aucmd({ 'WinResized', }, 'tabline.WinResized', {
  callback = function()
    M.update()
  end,
})

B.aucmd({ 'DirChanged', 'TabEnter', }, 'tabline.DirChanged', {
  callback = function()
    M.update()
    pcall(vim.cmd, 'ProjectRootCD')
  end,
})

B.aucmd('BufEnter', 'tabline.BufEnter-vim-projectroot', {
  callback = function(ev)
    M.titlestring(ev)
  end,
})

B.aucmd({ 'BufEnter', }, 'tabline.BufEnter-proj_buf', {
  callback = function(ev)
    local file = vim.api.nvim_buf_get_name(ev.buf)
    if B.is_file(file) then
      local proj = B.rep(vim.fn['ProjectRootGet'](file))
      M.proj_buf[proj] = ev.buf
    end
  end,
})

require 'which-key'.register {
  ['<leader><c-s-l>'] = { function() M.bd_next_buf(1) end, 'tabline: bwipeout next buf force', mode = { 'n', 'v', }, silent = true, },
  ['<leader><c-s-h>'] = { function() M.bd_prev_buf(1) end, 'tabline: bwipeout prev buf force', mode = { 'n', 'v', }, silent = true, },
  ['<leader><c-s-.>'] = { function() M.bd_all_next_buf(1) end, 'tabline: bwipeout all next buf force', mode = { 'n', 'v', }, silent = true, },
  ['<leader><c-s-,>'] = { function() M.bd_all_prev_buf(1) end, 'tabline: bwipeout all prev buf force', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-l>'] = { function() M.bd_next_buf() end, 'tabline: bwipeout next buf ', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-h>'] = { function() M.bd_prev_buf() end, 'tabline: bwipeout prev buf', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-.>'] = { function() M.bd_all_next_buf() end, 'tabline: bwipeout all next buf', mode = { 'n', 'v', }, silent = true, },
  ['<c-s-,>'] = { function() M.bd_all_prev_buf() end, 'tabline: bwipeout all prev buf', mode = { 'n', 'v', }, silent = true, },
  ['<a-,>'] = { function() M.simple_statusline_toggle() end, 'tabline: simple statusline toggle', mode = { 'n', 'v', }, silent = true, },
  ['<a-.>'] = { function() M.toggle_tabs_way() end, 'tabline: toggle tabs way', mode = { 'n', 'v', }, silent = true, },
}

return M
