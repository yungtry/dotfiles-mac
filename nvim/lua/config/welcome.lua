-- Welcome screen: shown when nvim starts without files, after closing the last tab,
-- and from Help > Welcome Screen. Every entry can be clicked or opened with its key.
local M = {}
local api = vim.api

local ns = api.nvim_create_namespace("welcome")
local projects_file = vim.fn.stdpath("state") .. "/recent-projects"
local WIDTH = 52

local logo = {
  "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██║   ██║██║████╗ ████║",
  "██╔██╗ ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

---------------------------------------------------------------------------
-- recent projects
---------------------------------------------------------------------------

local function projects()
  local ok, lines = pcall(vim.fn.readfile, projects_file)
  return vim.tbl_filter(function(d) return vim.fn.isdirectory(d) == 1 end, ok and lines or {})
end

function M.remember(dir)
  local list = { dir }
  for _, d in ipairs(projects()) do
    if d ~= dir and #list < 10 then list[#list + 1] = d end
  end
  pcall(vim.fn.writefile, list, projects_file)
end

-- switch the whole editor (tree, Claude) to another folder
function M.open_project(dir)
  dir = vim.fn.fnamemodify(dir, ":p"):gsub("/$", "")
  vim.cmd.cd(vim.fn.fnameescape(dir))
  M.remember(dir)
  vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(dir))
  require("claude").restart_here()
  if vim.bo.filetype == "welcome" then M.render(api.nvim_get_current_buf()) end
end

local function recent_files()
  local cwd = vim.fn.getcwd() .. "/"
  local out = {}
  for _, f in ipairs(vim.v.oldfiles) do
    if #out >= 5 then break end
    if f:sub(1, #cwd) == cwd and vim.fn.filereadable(f) == 1 then out[#out + 1] = f end
  end
  return out
end

---------------------------------------------------------------------------
-- screen
---------------------------------------------------------------------------

local function cmd(c) return function() vim.cmd(c) end end

local function entries()
  local e = {
    { section = "Start" },
    { key = "n", label = "New File", run = cmd("enew") },
    { key = "f", label = "Open File…", run = cmd("Telescope find_files") },
    { key = "o", label = "Open Folder…", run = function() require("config.menubar").actions.open_folder() end },
    { key = "g", label = "Find in Project…", run = cmd("Telescope live_grep") },
    { key = "c", label = "Ask Claude", run = function() require("claude").open(true) end },
    { key = "v", label = "Git Panel", run = function() require("config.git").open() end },
  }
  local files = recent_files()
  if #files > 0 then
    e[#e + 1] = { section = "Recent Files" }
    for i, f in ipairs(files) do
      e[#e + 1] = { key = tostring(i), label = vim.fn.fnamemodify(f, ":."), run = cmd("edit " .. vim.fn.fnameescape(f)) }
    end
  end
  local dirs = vim.tbl_filter(function(d) return d ~= vim.fn.getcwd() end, projects())
  if #dirs > 0 then
    e[#e + 1] = { section = "Recent Projects" }
    for i = 1, math.min(#dirs, 4) do
      e[#e + 1] = { key = tostring(5 + i), label = vim.fn.fnamemodify(dirs[i], ":~"), run = function() M.open_project(dirs[i]) end }
    end
  end
  e[#e + 1] = { section = "Help" }
  e[#e + 1] = { key = "?", label = "Keyboard Shortcuts", run = cmd("Shortcuts") }
  e[#e + 1] = { key = "q", label = "Quit", run = cmd("confirm qall") }
  return e
end

local function center(text, width)
  return string.rep(" ", math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))) .. text
end

function M.render(buf)
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  local width = api.nvim_win_get_width(win)
  local list = entries()
  local lines, marks, items = {}, {}, {}
  local function add(text, hl)
    lines[#lines + 1] = text
    if hl then marks[#marks + 1] = { #lines - 1, 0, #text, hl } end
  end

  local body = #logo + 3 + #list * 1 + 6
  for _ = 1, math.max(1, math.floor((api.nvim_win_get_height(win) - body) / 3)) do add("") end
  for _, l in ipairs(logo) do add(center(l, width), "WelcomeLogo") end
  add("")
  add(center("Neovim  +  Claude Code", width), "WelcomeTagline")

  local pad = string.rep(" ", math.max(0, math.floor((width - WIDTH) / 2)))
  for _, e in ipairs(list) do
    if e.section then
      add("")
      add(pad .. e.section, "WelcomeSection")
    else
      local label = e.label
      if vim.fn.strdisplaywidth(label) > WIDTH - 8 then label = "…" .. label:sub(-(WIDTH - 9)) end
      local line = pad .. "  " .. label .. string.rep(" ", WIDTH - 4 - vim.fn.strdisplaywidth(label)) .. e.key
      add(line)
      marks[#marks + 1] = { #lines - 1, #line - #e.key, #line, "WelcomeKey" }
      items[#lines] = e
    end
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end

  -- keys
  for _, e in pairs(items) do
    vim.keymap.set("n", e.key, e.run, { buffer = buf, nowait = true, desc = e.label })
  end
  local function run_line(line)
    local e = items[line]
    if e then e.run() end
  end
  vim.keymap.set("n", "<CR>", function() run_line(api.nvim_win_get_cursor(0)[1]) end, { buffer = buf })
  vim.keymap.set("n", "<LeftRelease>", function() run_line(vim.fn.getmousepos().line) end, { buffer = buf })

  -- start with the cursor on the first entry
  for l = 1, #lines do
    if items[l] then
      api.nvim_win_set_cursor(win, { l, #pad + 2 })
      break
    end
  end
end

function M.show()
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "welcome"
  api.nvim_win_set_buf(0, buf)
  local wo = vim.wo[0][0] -- [0]: this window only, like :setlocal
  wo.number, wo.relativenumber, wo.signcolumn, wo.cursorline = false, false, "no", true
  wo.list, wo.wrap, wo.colorcolumn, wo.foldcolumn = false, false, "", "0"
  vim.w.welcome = true
  vim.cmd.stopinsert()
  M.render(buf)
  api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    buffer = buf,
    callback = function() if api.nvim_buf_is_valid(buf) then M.render(buf) end end,
  })
end

local function set_hl()
  api.nvim_set_hl(0, "WelcomeLogo", { link = "Keyword", default = true })
  api.nvim_set_hl(0, "WelcomeTagline", { link = "Comment", default = true })
  api.nvim_set_hl(0, "WelcomeSection", { link = "Title", default = true })
  api.nvim_set_hl(0, "WelcomeKey", { link = "Special", default = true })
end

function M.setup()
  set_hl()
  api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
  api.nvim_create_user_command("Welcome", M.show, { desc = "Show the welcome screen" })
  -- a file opened from the welcome screen gets the normal editor look back
  api.nvim_create_autocmd("BufWinEnter", {
    callback = function()
      if not vim.w.welcome or vim.bo.filetype == "welcome" then return end
      vim.w.welcome = nil
      for _, opt in ipairs({ "number", "relativenumber", "signcolumn", "cursorline", "list", "wrap", "colorcolumn", "foldcolumn" }) do
        vim.wo[0][0][opt] = vim.go[opt]
      end
    end,
  })
end

return M
