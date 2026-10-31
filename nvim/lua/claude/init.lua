-- Claude Code side panel + live view of the edits Claude makes to files.
--
-- How it works:
--   * Claude runs in a terminal in the panel, started with PreToolUse/PostToolUse hooks
--     (bin/claude-hook.sh) that call back into this Neovim over $NVIM.
--   * pre:  the file Claude is about to edit is opened in the editor and scrolled to the
--           fragment that is going to change.
--   * post: the buffer is reloaded from disk (Ctrl+Z undoes the whole edit) and the difference
--           to the version before Claude's first change is drawn inline: new lines green,
--           removed lines as red virtual lines.
--   * a recursive file watcher + FileChangedShell catch everything else (changes made via
--     Bash, formatters, git ...).

local M = {}

M.config = {
  cmd = { "claude" },
  width = 0.38,          -- default panel width as a fraction of the screen (resizing it is remembered)
  follow = true,         -- open and scroll to the files Claude edits
  autosave = true,       -- save files when switching to the panel, so Claude sees your changes
  auto_open = true,      -- open the panel when nvim starts without files / on a directory
  max_deleted_lines = 40,
}

local api = vim.api
local uv = vim.uv
local ns = api.nvim_create_namespace("claude_live")
local ns_flash = api.nvim_create_namespace("claude_live_flash")
local hook_script = vim.fn.stdpath("config") .. "/bin/claude-hook.sh"
local width_file = vim.fn.stdpath("state") .. "/claude-panel-width"

local term = {}      -- { buf, job }
local reviews = {}   -- bufnr -> { base = lines before Claude's changes, hunks, tick, new_file }
local disk = {}      -- bufnr -> lines last read from disk
local snapshots = {} -- path -> lines before Claude's edit (false = the file did not exist)
local last_editor_win
local last_typed = -math.huge

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function realpath(p)
  p = vim.fn.fnamemodify(p, ":p")
  local real = uv.fs_realpath(p)
  if real then return real end
  local dir = uv.fs_realpath(vim.fs.dirname(p))
  return dir and (dir .. "/" .. vim.fs.basename(p)) or vim.fs.normalize(p)
end

local function find_buf(path)
  local want = realpath(path)
  for _, b in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(b)
    if name ~= "" and vim.bo[b].buftype == "" and realpath(name) == want then return b end
  end
end

local function read_lines(path, dos)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  if s == "" then return {} end
  if s:sub(-1) == "\n" then s = s:sub(1, -2) end
  local lines = vim.split(s, "\n", { plain = true })
  if dos then
    for i, l in ipairs(lines) do lines[i] = (l:gsub("\r$", "")) end
  end
  return lines
end

local function buf_lines(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines == 1 and lines[1] == "" then return {} end
  return lines
end

local function hunks(a, b)
  local function text(l) return #l == 0 and "" or table.concat(l, "\n") .. "\n" end
  return vim.text.diff(text(a), text(b), { result_type = "indices", algorithm = "histogram" })
end

-- first and last line (in the new version) touched by a hunk
local function hunk_range(h)
  local first = h[4] > 0 and h[3] or h[3] + 1
  return first, first + math.max(h[4], 1) - 1
end

local function git_base(path)
  local res = vim.system({ "git", "-C", vim.fs.dirname(path), "show", ":./" .. vim.fs.basename(path) }, { text = true }):wait(1000)
  if res.code ~= 0 then return nil end
  return vim.split((res.stdout:gsub("\n$", "")), "\n", { plain = true })
end

---------------------------------------------------------------------------
-- windows
---------------------------------------------------------------------------

local function claude_win()
  if not (term.buf and api.nvim_buf_is_valid(term.buf)) then return end
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_buf(w) == term.buf then return w end
  end
end

local function is_editor_win(win)
  if not (win and api.nvim_win_is_valid(win)) then return false end
  if api.nvim_win_get_config(win).relative ~= "" then return false end
  if api.nvim_win_get_tabpage(win) ~= api.nvim_get_current_tabpage() then return false end
  local buf = api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" or vim.bo[buf].filetype == "welcome"
end

-- panel width in columns: the last width you dragged it to, or config.width
local function panel_width()
  local f = io.open(width_file, "r")
  local saved = f and tonumber(f:read("*l"))
  if f then f:close() end
  local w = saved or math.floor(vim.o.columns * M.config.width)
  return math.max(20, math.min(w, vim.o.columns - 20))
end

local function save_width(w)
  local f = io.open(width_file, "w")
  if f then
    f:write(tostring(w))
    f:close()
  end
end

-- the window files are shown in (the last used editor window)
function M.editor_win()
  if is_editor_win(last_editor_win) then return last_editor_win end
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if is_editor_win(w) then return w end
  end
  local cw = claude_win()
  if not cw then return end
  local cur = api.nvim_get_current_win()
  api.nvim_set_current_win(cw)
  vim.cmd("leftabove vnew")
  local w = api.nvim_get_current_win()
  api.nvim_win_set_width(cw, panel_width())
  api.nvim_set_current_win(cur)
  return w
end

-- don't jump around while the user is typing in the editor
local function can_follow()
  if not M.config.follow then return false end
  if api.nvim_get_current_win() == claude_win() then return true end
  return uv.now() - last_typed > 3000 and not api.nvim_get_mode().mode:find("^c")
end

local function flash(buf, first, last)
  api.nvim_buf_clear_namespace(buf, ns_flash, 0, -1)
  for l = first, last do
    pcall(api.nvim_buf_set_extmark, buf, ns_flash, l - 1, 0, { line_hl_group = "ClaudeFlash", priority = 200 })
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then api.nvim_buf_clear_namespace(buf, ns_flash, 0, -1) end
  end, 900)
end

-- show the buffer in the editor window and scroll to the line (without stealing focus from the panel)
local function reveal(buf, first, last)
  local n = api.nvim_buf_line_count(buf)
  first = math.max(1, math.min(first, n))
  last = math.max(first, math.min(last or first, n))
  flash(buf, first, last)
  if not can_follow() then return end
  local win = M.editor_win()
  if not win then return end
  if api.nvim_win_get_buf(win) ~= buf then api.nvim_win_set_buf(win, buf) end
  api.nvim_win_set_cursor(win, { first, 0 })
  api.nvim_win_call(win, function() vim.cmd("normal! zz") end)
end

local function load_buf(path)
  local buf = find_buf(path) or vim.fn.bufadd(path)
  vim.bo[buf].buflisted = true
  if not api.nvim_buf_is_loaded(buf) then
    pcall(vim.fn.bufload, buf)
    if vim.bo[buf].filetype == "" then
      api.nvim_buf_call(buf, function() vim.cmd("filetype detect") end)
    end
  end
  disk[buf] = buf_lines(buf)
  return buf
end

---------------------------------------------------------------------------
-- live diff
---------------------------------------------------------------------------

local BUTTON_OFFSET = 1 -- Neovim leaves one cell between the end of the text and eol virtual text
local BUTTONS = {
  { text = " ✓ Accept ", action = "accept" },
  { text = " ↺ Revert ", action = "revert" },
}

local function render(buf)
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local r = reviews[buf]
  if not r then return end
  local cur = buf_lines(buf)
  r.hunks = hunks(r.base, cur)
  if #r.hunks == 0 then
    reviews[buf] = nil
    return
  end
  local width = math.max(vim.o.columns, 80)
  local tab = string.rep(" ", vim.bo[buf].tabstop)
  local max = M.config.max_deleted_lines
  r.buttons = {}
  for idx, h in ipairs(r.hunks) do
    local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
    for l = sb, sb + cb - 1 do
      api.nvim_buf_set_extmark(buf, ns, l - 1, 0, { line_hl_group = "ClaudeAdd", number_hl_group = "ClaudeAddNr", priority = 50 })
    end
    if ca > 0 then
      local virt = {}
      for i = sa, math.min(sa + ca - 1, sa + max - 1) do
        local text = r.base[i]:gsub("\t", tab)
        virt[#virt + 1] = { { text .. string.rep(" ", width - vim.fn.strdisplaywidth(text)), "ClaudeDelete" } }
      end
      if ca > max then
        virt[#virt + 1] = { { ("… %d more deleted lines"):format(ca - max), "ClaudeDelete" } }
      end
      local row, above
      if cb > 0 then
        row, above = sb - 1, true
      elseif sb < #cur then
        row, above = sb, true
      else
        row, above = math.max(#cur - 1, 0), false
      end
      api.nvim_buf_set_extmark(buf, ns, row, 0, { virt_lines = virt, virt_lines_above = above })
    end
    -- clickable [Accept] [Revert] after the first line of the change (see M.click)
    local row = cb > 0 and sb - 1 or math.max(math.min(sb, #cur - 1), 0)
    if not r.buttons[row + 1] then
      r.buttons[row + 1] = idx
      api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { " " }, { BUTTONS[1].text, "ClaudeButtonAccept" }, { " " }, { BUTTONS[2].text, "ClaudeButtonRevert" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

-- read the new version of the file from disk and show the difference.
-- :edit! (rather than replacing lines) updates the file's read time, so Ctrl+S doesn't warn
-- "file has been changed", and thanks to 'undoreload' Ctrl+Z undoes Claude's whole edit.
function M.reload(buf)
  if not (api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf)) or vim.bo[buf].modified then return end
  local old = buf_lines(buf)
  local new = read_lines(api.nvim_buf_get_name(buf), vim.bo[buf].fileformat == "dos")
  if not new or vim.deep_equal(old, new) then return end
  api.nvim_buf_call(buf, function() vim.cmd("silent! noautocmd edit!") end)
  new = buf_lines(buf)
  disk[buf] = new
  local r = reviews[buf]
  if not r then
    r = { base = old }
    reviews[buf] = r
  end
  r.tick = api.nvim_buf_get_changedtick(buf)
  render(buf)
  local hs = hunks(old, new)
  if hs[1] then reveal(buf, hunk_range(hs[1])) end
end

local function on_file_changed(ev)
  local buf, reason = ev.buf, vim.v.fcs_reason
  vim.v.fcs_choice = ""
  local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":~:.")
  if reason == "changed" then
    vim.schedule(function() M.reload(buf) end)
  elseif reason == "conflict" then
    local now = read_lines(api.nvim_buf_get_name(buf), vim.bo[buf].fileformat == "dos")
    if disk[buf] and vim.deep_equal(now, disk[buf]) then return end
    vim.schedule(function()
      vim.notify(("%s changed on disk while you have unsaved changes in it.\n"
        .. ":ClaudeReload takes the version on disk, Ctrl+S overwrites it with yours."):format(name), vim.log.levels.WARN)
    end)
  elseif reason == "deleted" then
    vim.schedule(function() vim.notify(name .. " was deleted from disk", vim.log.levels.WARN) end)
  end
end

---------------------------------------------------------------------------
-- Claude Code hooks
---------------------------------------------------------------------------

local function on_hook(phase, path, input)
  local key = realpath(path)
  local buf = find_buf(path)
  local loaded = buf and api.nvim_buf_is_loaded(buf)

  if phase == "pre" then
    if not can_follow() or vim.fn.filereadable(path) == 0 then return end
    if not loaded then
      buf = load_buf(path)
      local snap = snapshots[key]
      snapshots[key] = nil
      if snap ~= nil and not vim.deep_equal(snap or {}, buf_lines(buf)) then -- Claude already wrote it
        reviews[buf] = { base = snap or {}, new_file = snap == false, tick = api.nvim_buf_get_changedtick(buf) }
        render(buf)
        local r = reviews[buf]
        if r and r.hunks[1] then reveal(buf, hunk_range(r.hunks[1])) end
        return
      end
    end
    local needle = input.old_string
    if type(input.edits) == "table" and input.edits[1] then needle = input.edits[1].old_string end
    local first, last = 1, 1
    if type(needle) == "string" and needle ~= "" then
      local text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      local s = text:find(needle, 1, true)
      if s then
        first = select(2, text:sub(1, s):gsub("\n", "")) + 1
        last = first + select(2, needle:gsub("\n", ""))
      end
    end
    reveal(buf, first, last)
    return
  end

  -- post
  if loaded then
    vim.cmd("checktime " .. buf) -- -> FileChangedShell -> M.reload
    vim.schedule(function()
      if api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then M.reload(buf) end
    end)
    return
  end
  local base = snapshots[key]
  snapshots[key] = nil
  if base == nil then base = git_base(path) end
  buf = load_buf(path)
  if base ~= nil then
    reviews[buf] = { base = base or {}, new_file = base == false, tick = api.nvim_buf_get_changedtick(buf) }
    render(buf)
  end
  local r = reviews[buf]
  if r and r.hunks[1] then
    reveal(buf, hunk_range(r.hunks[1]))
  else
    reveal(buf, 1)
  end
end

-- called by bin/claude-hook.sh: nvim --server $NVIM --remote-expr "v:lua.ClaudeLiveHook(...)"
function _G.ClaudeLiveHook(phase, file)
  local f = io.open(file, "r")
  if not f then return 0 end
  local raw = f:read("*a")
  f:close()
  os.remove(file)
  local ok, data = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= "table" or type(data.tool_input) ~= "table" then return 0 end
  local input = data.tool_input
  local path = input.file_path
  if type(path) ~= "string" then return 0 end
  if phase == "pre" then
    -- snapshot right away: Claude may write the file before vim.schedule gets to run
    local buf = find_buf(path)
    if not (buf and api.nvim_buf_is_loaded(buf)) then
      snapshots[realpath(path)] = read_lines(path) or false
    end
  end
  vim.schedule(function() on_hook(phase, path, input) end)
  return 0
end

local function settings_json()
  local function hook(phase)
    return { { type = "command", command = vim.fn.shellescape(hook_script) .. " " .. phase } }
  end
  local matcher = "Edit|MultiEdit|Write"
  return vim.json.encode({
    hooks = {
      PreToolUse = { { matcher = matcher, hooks = hook("pre") } },
      PostToolUse = { { matcher = matcher, hooks = hook("post") } },
    },
  })
end

---------------------------------------------------------------------------
-- panel
---------------------------------------------------------------------------

local function job_alive()
  return term.job ~= nil and vim.fn.jobwait({ term.job }, 0)[1] == -1
end

local function start_job()
  if term.buf and api.nvim_buf_is_valid(term.buf) then pcall(api.nvim_buf_delete, term.buf, { force = true }) end
  term.buf = api.nvim_create_buf(false, false)
  return term.buf
end

function M.open(focus)
  local win = claude_win()
  local fresh = false
  if not win then
    local prev = api.nvim_get_current_win()
    vim.cmd("botright vsplit")
    win = api.nvim_get_current_win()
    api.nvim_win_set_width(win, panel_width())
    if job_alive() then
      api.nvim_win_set_buf(win, term.buf)
    else
      fresh = true
      local buf = start_job()
      api.nvim_win_set_buf(win, buf)
      local cmd = vim.list_extend(vim.deepcopy(M.config.cmd), { "--settings", settings_json() })
      term.job = vim.fn.jobstart(cmd, {
        term = true,
        env = { CLAUDE_NVIM_BIN = vim.v.progpath },
        on_exit = function()
          term.job = nil
          vim.schedule(function()
            if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete, buf, { force = true }) end
          end)
        end,
      })
      vim.bo[buf].buflisted = false
      vim.bo[buf].filetype = "claude"
      api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        buffer = buf,
        callback = function()
          term.used = true
          if M.config.autosave then M.save_all() end
          vim.cmd.startinsert()
        end,
      })
      -- after scrolling with the wheel: click to type again
      vim.keymap.set("n", "<LeftRelease>", "<Cmd>startinsert<CR>", { buffer = buf })
    end
    local wo = vim.wo[win][0] -- [0]: this window only, like :setlocal
    wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
    wo.cursorline, wo.scrolloff, wo.sidescrolloff = false, 0, 0
    wo.winfixwidth, wo.winfixbuf = true, true
    if not focus and api.nvim_win_is_valid(prev) then api.nvim_set_current_win(prev) end
  end
  if focus then
    api.nvim_set_current_win(win)
    vim.cmd.startinsert()
  end
  return fresh
end

-- save modified files, skipping those that changed on disk in the meantime
function M.save_all()
  for _, b in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(b)
    if api.nvim_buf_is_loaded(b) and vim.bo[b].modified and vim.bo[b].buftype == "" and name ~= "" then
      local now = read_lines(name, vim.bo[b].fileformat == "dos")
      if not now or not disk[b] or vim.deep_equal(now, disk[b]) then
        pcall(api.nvim_buf_call, b, function() vim.cmd("silent write") end)
      end
    end
  end
end

-- start Claude again in the current directory (after switching projects).
-- Asks first if you've already used the running session.
function M.restart_here()
  if not job_alive() then return end
  local where = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
  if term.used and vim.fn.confirm("Restart Claude in " .. where .. "?", "&Yes\n&No", 1) ~= 1 then return end
  local visible = claude_win() ~= nil
  vim.fn.jobstop(term.job)
  vim.wait(2000, function() return not job_alive() end)
  if term.buf and api.nvim_buf_is_valid(term.buf) then pcall(api.nvim_buf_delete, term.buf, { force = true }) end
  term.used = false
  if visible then M.open(false) end
end

-- Ctrl+\ : editor ⇄ Claude
function M.focus_toggle()
  local win = claude_win()
  if win and api.nvim_get_current_win() == win then
    local ed = M.editor_win()
    if ed then api.nvim_set_current_win(ed) end
  else
    M.open(true)
  end
end

-- hide the panel; Claude keeps running in the background
function M.hide()
  local win = claude_win()
  if not win or #api.nvim_tabpage_list_wins(0) == 1 then return false end
  if api.nvim_get_current_win() == win then vim.cmd.stopinsert() end
  save_width(api.nvim_win_get_width(win))
  api.nvim_win_hide(win)
  return true
end

-- F12 : show / hide the panel
function M.toggle()
  if not M.hide() then M.open(true) end
end

-- :ClaudeWidth 80 / 40% / (nothing = default)
function M.set_width(arg)
  local w
  if not arg or arg == "" then
    os.remove(width_file)
    w = panel_width()
  else
    local pct = arg:match("^(%d+)%%$")
    w = pct and math.floor(vim.o.columns * tonumber(pct) / 100) or tonumber(arg)
    if not w then return vim.notify("Usage: :ClaudeWidth 80 | 40% | (empty for default)", vim.log.levels.WARN) end
    w = math.max(20, math.min(w, vim.o.columns - 20))
    save_width(w)
  end
  local win = claude_win()
  if win then api.nvim_win_set_width(win, w) end
end

-- insert an @file or @file#from-to reference into the chat
function M.send(path, l1, l2)
  if not path or path == "" then return end
  local ref = "@" .. vim.fn.fnamemodify(path, ":.")
  if l1 then ref = ref .. (l1 == l2 and ("#%d"):format(l1) or ("#%d-%d"):format(l1, l2)) end
  local fresh = M.open(true)
  local function go() if term.job then vim.fn.chansend(term.job, ref .. " ") end end
  if fresh then vim.defer_fn(go, 2500) else go() end
end

---------------------------------------------------------------------------
-- reviewing changes
---------------------------------------------------------------------------

function M.next_change(dir)
  local buf = api.nvim_get_current_buf()
  local r = reviews[buf]
  if not r or #r.hunks == 0 then
    -- go to the next file with changes
    for b, rv in pairs(reviews) do
      if b ~= buf and api.nvim_buf_is_valid(b) and rv.hunks[1] then
        api.nvim_win_set_buf(0, b)
        api.nvim_win_set_cursor(0, { (hunk_range(rv.hunks[1])), 0 })
        vim.cmd("normal! zz")
        return
      end
    end
    return vim.notify("No Claude changes to review")
  end
  local cur = api.nvim_win_get_cursor(0)[1]
  local starts = vim.tbl_map(function(h) return (hunk_range(h)) end, r.hunks)
  local target
  if dir > 0 then
    for _, s in ipairs(starts) do if s > cur then target = s break end end
    target = target or starts[1]
  else
    for i = #starts, 1, -1 do if starts[i] < cur then target = starts[i] break end end
    target = target or starts[#starts]
  end
  api.nvim_win_set_cursor(0, { math.min(target, api.nvim_buf_line_count(buf)), 0 })
  vim.cmd("normal! zz")
end

function M.accept(buf)
  buf = buf or api.nvim_get_current_buf()
  reviews[buf] = nil
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.accept_all()
  for buf in pairs(reviews) do
    if api.nvim_buf_is_valid(buf) then M.accept(buf) end
  end
  reviews = {}
end

local function write(buf)
  api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
end

function M.revert(buf)
  buf = buf or api.nvim_get_current_buf()
  local r = reviews[buf]
  if not r then return vim.notify("No Claude changes in this file") end
  if r.new_file then
    if vim.fn.confirm("Claude created this file. Delete it?", "&Yes\n&No", 2) ~= 1 then return end
    os.remove(api.nvim_buf_get_name(buf))
    reviews[buf] = nil
    require("config.util").close_buffer(buf)
    return
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, r.base)
  write(buf)
  M.accept(buf)
end

-- put the old lines of one change back and save
local function revert_at(buf, h)
  local r = reviews[buf]
  local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
  local old = vim.list_slice(r.base, sa, sa + ca - 1)
  if cb == 0 then
    api.nvim_buf_set_lines(buf, sb, sb, false, old)
  else
    api.nvim_buf_set_lines(buf, sb - 1, sb - 1 + cb, false, old)
  end
  write(buf)
  render(buf)
end

-- keep one change: copy its new lines into the base so it no longer shows as a diff
local function accept_at(buf, h)
  local r = reviews[buf]
  local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
  local cur = buf_lines(buf)
  local base = vim.list_slice(r.base, 1, sa + (ca == 0 and 0 or -1))
  vim.list_extend(base, vim.list_slice(cur, sb, sb + cb - 1))
  vim.list_extend(base, vim.list_slice(r.base, sa + ca + (ca == 0 and 1 or 0)))
  r.base = base
  render(buf)
end

local function hunk_at_cursor(buf)
  local r = reviews[buf]
  if not r then return end
  local line = api.nvim_win_get_cursor(0)[1]
  for _, h in ipairs(r.hunks) do
    local first, last = hunk_range(h)
    if h[4] == 0 then first = h[3] end
    if line >= first and line <= last then return h end
  end
end

function M.revert_hunk()
  local buf = api.nvim_get_current_buf()
  if not reviews[buf] then return vim.notify("No Claude changes in this file") end
  local h = hunk_at_cursor(buf)
  if not h then return vim.notify("The cursor is not on a Claude change") end
  revert_at(buf, h)
end

function M.accept_hunk()
  local buf = api.nvim_get_current_buf()
  if not reviews[buf] then return vim.notify("No Claude changes in this file") end
  local h = hunk_at_cursor(buf)
  if not h then return vim.notify("The cursor is not on a Claude change") end
  accept_at(buf, h)
end

-- mouse release: was it on one of the [Accept] [Revert] buttons drawn after a line?
-- Returns true when it handled the click.
function M.click()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or pos.line == 0 then return false end
  local buf = api.nvim_win_get_buf(pos.winid)
  local r = reviews[buf]
  local idx = r and r.buttons and r.buttons[pos.line]
  if not idx then return false end
  local info = vim.fn.getwininfo(pos.winid)[1]
  local leftcol = api.nvim_win_call(pos.winid, function() return vim.fn.winsaveview().leftcol end)
  local text = api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1] or ""
  -- cells past the end of the text, counting from 1
  local past = pos.wincol - info.textoff + leftcol - vim.fn.strdisplaywidth(text)
  local start = BUTTON_OFFSET + 1 -- the " " chunk before the first button
  for _, b in ipairs(BUTTONS) do
    local w = vim.fn.strdisplaywidth(b.text)
    if past > start and past <= start + w then
      local h = r.hunks[idx]
      if b.action == "accept" then accept_at(buf, h) else revert_at(buf, h) end
      return true
    end
    start = start + w + 1
  end
  return false
end

function M.list()
  local items = {}
  for buf, r in pairs(reviews) do
    if api.nvim_buf_is_valid(buf) then
      for _, h in ipairs(r.hunks) do
        local first = hunk_range(h)
        items[#items + 1] = { bufnr = buf, lnum = first, text = ("Claude: +%d −%d"):format(h[4], h[2]) }
      end
    end
  end
  if #items == 0 then return vim.notify("No Claude changes to review") end
  vim.fn.setqflist({}, " ", { title = "Claude changes", items = items })
  vim.cmd("botright copen")
end

function M.status()
  local n = 0
  for buf in pairs(reviews) do
    if api.nvim_buf_is_valid(buf) then n = n + 1 end
  end
  return n > 0 and ("● Claude changes: %d"):format(n) or ""
end

---------------------------------------------------------------------------
-- file watcher
---------------------------------------------------------------------------

local watcher
local timer = uv.new_timer()
local changed = {}

local function flush()
  local paths = changed
  changed = {}
  for path in pairs(paths) do
    local b = find_buf(path)
    if b and api.nvim_buf_is_loaded(b) then pcall(vim.cmd, "checktime " .. b) end
  end
end

local function watch(root)
  if watcher then
    watcher:stop()
    watcher:close()
  end
  root = realpath(root)
  watcher = uv.new_fs_event()
  watcher:start(root, { recursive = true }, function(err, fname)
    if err or not fname or fname:find("^%.git/") or fname:find("node_modules/", 1, true) then return end
    changed[fname:sub(1, 1) == "/" and fname or (root .. "/" .. fname)] = true
    timer:stop()
    timer:start(80, 0, vim.schedule_wrap(flush))
  end)
end

---------------------------------------------------------------------------

local function set_hl()
  local function hl(name, opts)
    if opts.link then opts.default = true end
    api.nvim_set_hl(0, name, opts)
  end
  hl("ClaudeAdd", { link = "DiffAdd" })
  hl("ClaudeAddNr", { link = "Added" })
  hl("ClaudeDelete", { link = "DiffDelete" })
  hl("ClaudeFlash", { link = "Visual" })
  -- solid "pill" buttons in the theme's green and red
  local function color(names, key)
    for _, n in ipairs(names) do
      local c = api.nvim_get_hl(0, { name = n, link = false })[key]
      if c then return c end
    end
  end
  local bg = color({ "Normal" }, "bg")
  hl("ClaudeButtonAccept", { fg = bg, bg = color({ "Added", "DiagnosticOk", "String" }, "fg"), bold = true })
  hl("ClaudeButtonRevert", { fg = bg, bg = color({ "Removed", "DiagnosticError", "ErrorMsg" }, "fg"), bold = true })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  set_hl()

  local group = api.nvim_create_augroup("claude_live", { clear = true })
  local au = function(event, o)
    o.group = group
    api.nvim_create_autocmd(event, o)
  end
  au("ColorScheme", { callback = set_hl })
  au("FileChangedShell", { callback = on_file_changed })
  au({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    callback = function()
      if not api.nvim_get_mode().mode:find("^c") then vim.cmd("silent! checktime") end
    end,
  })
  au("WinEnter", {
    callback = function()
      local win = api.nvim_get_current_win()
      if is_editor_win(win) then last_editor_win = win end
    end,
  })
  au({ "InsertCharPre", "TextChangedI" }, { callback = function() last_typed = uv.now() end })
  local pending = {}
  au({ "TextChanged", "TextChangedI" }, {
    callback = function(ev)
      local r = reviews[ev.buf]
      if not r or api.nvim_buf_get_changedtick(ev.buf) == r.tick or pending[ev.buf] then return end
      pending[ev.buf] = true
      vim.defer_fn(function()
        pending[ev.buf] = nil
        if api.nvim_buf_is_valid(ev.buf) then render(ev.buf) end
      end, 150)
    end,
  })
  au({ "BufReadPost", "BufWritePost" }, {
    callback = function(ev)
      if vim.bo[ev.buf].buftype == "" then disk[ev.buf] = buf_lines(ev.buf) end
    end,
  })
  au("BufWipeout", {
    callback = function(ev)
      reviews[ev.buf], disk[ev.buf] = nil, nil
    end,
  })
  -- remember the panel width after you drag its border with the mouse
  au("WinResized", {
    callback = function()
      local win = claude_win()
      if win and vim.tbl_contains(vim.v.event.windows, win) then save_width(api.nvim_win_get_width(win)) end
    end,
  })
  au("DirChanged", { callback = function() watch(vim.fn.getcwd()) end })
  au("VimLeavePre", {
    callback = function()
      if watcher then watcher:stop() end
      local win = claude_win()
      if win then save_width(api.nvim_win_get_width(win)) end
    end,
  })
  watch(vim.fn.getcwd())

  local cmd = api.nvim_create_user_command
  cmd("Claude", M.focus_toggle, { desc = "Switch focus editor ⇄ Claude" })
  cmd("ClaudeToggle", M.toggle, { desc = "Show/hide the Claude panel" })
  cmd("ClaudeWidth", function(o) M.set_width(o.args) end, { nargs = "?", desc = "Set the Claude panel width (80, 40%)" })
  cmd("ClaudeSend", function(o)
    local buf = api.nvim_get_current_buf()
    if vim.bo[buf].buftype ~= "" then return end
    M.send(api.nvim_buf_get_name(buf), o.range > 0 and o.line1 or nil, o.range > 0 and o.line2 or nil)
  end, { range = true, desc = "Send file/selection to Claude" })
  cmd("ClaudeAccept", function() M.accept() end, { desc = "Accept changes in this file (hide the diff)" })
  cmd("ClaudeAcceptAll", M.accept_all, { desc = "Accept all changes" })
  cmd("ClaudeRevert", function() M.revert() end, { desc = "Revert all Claude changes in this file" })
  cmd("ClaudeRevertHunk", M.revert_hunk, { desc = "Revert the change under the cursor" })
  cmd("ClaudeAcceptHunk", M.accept_hunk, { desc = "Accept the change under the cursor" })
  cmd("ClaudeChanges", M.list, { desc = "List Claude changes" })
  cmd("ClaudeReload", function()
    local buf = api.nvim_get_current_buf()
    vim.bo[buf].modified = false
    M.reload(buf)
  end, { desc = "Reload the file from disk (discards unsaved changes)" })
end

return M
