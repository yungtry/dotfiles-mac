-- Menu bar in the top row of the screen. Clicking a name opens its menu below it;
-- F10 opens the File menu. The menus are ordinary Neovim :menu entries.
local M = {}
local api = vim.api

M.menus = { "File", "Edit", "View", "Go", "Claude", "Help" }

local function prompt(text, default, completion)
  local ok, value = pcall(vim.fn.input, { prompt = text, default = default or "", completion = completion })
  return ok and value or ""
end

-- small actions the menus call
M.actions = {
  open_folder = function()
    local dir = prompt("Open folder: ", vim.fn.getcwd() .. "/", "dir")
    if dir == "" or vim.fn.isdirectory(dir) == 0 then return end
    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(vim.fn.getcwd()))
  end,
  save_as = function()
    local name = prompt("Save as: ", vim.fn.expand("%:p"), "file")
    if name ~= "" then pcall(vim.cmd, "saveas " .. vim.fn.fnameescape(name)) end
  end,
  close_all = function()
    for _, b in ipairs(api.nvim_list_bufs()) do
      if vim.bo[b].buflisted then require("config.util").close_buffer(b) end
    end
  end,
  go_to_line = function()
    local n = tonumber(prompt("Go to line: "))
    if n then
      pcall(api.nvim_win_set_cursor, 0, { math.min(n, api.nvim_buf_line_count(0)), 0 })
      vim.cmd("normal! zz")
    end
  end,
  panel_width = function()
    local w = prompt("Claude panel width (e.g. 90 or 40%): ")
    if w ~= "" then require("claude").set_width(w) end
  end,
}

local function esc(s) return (s:gsub("([ .\\|])", "\\%1")) end

-- item("File", "Save", "Ctrl+S", "<Cmd>...<CR>") ; modes: "a" (all), "n", "v", "i"
-- The terminal popup doesn't show :menu's <Tab> shortcut text, so the shortcut is padded into the label.
local function item(menu, label, keys, rhs, modes)
  if keys then label = label .. string.rep(" ", math.max(2, 26 - vim.fn.strdisplaywidth(label))) .. keys end
  local name = menu .. "." .. esc(label)
  for m in (modes or "a"):gmatch(".") do
    vim.cmd(("%snoremenu <silent> %s %s"):format(m, name, rhs))
  end
end

local function sep(menu, n) vim.cmd(("anoremenu %s.-sep%d- <Nop>"):format(menu, n)) end

local function a(name) return ("<Cmd>lua require('config.menubar').actions.%s()<CR>"):format(name) end

local function define()
  for _, m in ipairs(M.menus) do vim.cmd("silent! aunmenu " .. m) end

  item("File", "New File", "Ctrl+N", "<Cmd>enew<CR>")
  item("File", "Open File…", "Ctrl+P", "<Cmd>Telescope find_files<CR>")
  item("File", "Open Recent…", nil, "<Cmd>Telescope oldfiles<CR>")
  item("File", "Open Folder…", nil, a("open_folder"))
  sep("File", 1)
  item("File", "Save", "Ctrl+S", "<Cmd>lua require('config.util').save()<CR>")
  item("File", "Save As…", nil, a("save_as"))
  item("File", "Save All", nil, "<Cmd>silent! wall<CR>")
  sep("File", 2)
  item("File", "Close Tab", "Ctrl+W", "<Cmd>lua require('config.util').close_buffer()<CR>")
  item("File", "Close All Tabs", nil, a("close_all"))
  sep("File", 3)
  item("File", "Quit", "Ctrl+Q", "<Cmd>confirm qall<CR>")

  item("Edit", "Undo", "Ctrl+Z", "<Cmd>undo<CR>")
  item("Edit", "Redo", "Ctrl+Y", "<Cmd>redo<CR>")
  sep("Edit", 1)
  item("Edit", "Cut", "Ctrl+X", '"+d', "v")
  item("Edit", "Copy", "Ctrl+C", '"+y', "v")
  item("Edit", "Paste", "Ctrl+V", "<Cmd>normal! \"+gP<CR>", "ni")
  item("Edit", "Paste", "Ctrl+V", '"+P', "v")
  item("Edit", "Select All", "Ctrl+A", "<Esc>ggVG<C-g>", "ni")
  sep("Edit", 2)
  item("Edit", "Find…", "Ctrl+F", "<Cmd>call feedkeys('/', 'n')<CR>")
  item("Edit", "Find and Replace…", "Ctrl+R", "<Cmd>lua require('config.util').find_replace()<CR>")
  item("Edit", "Find in Project…", "Ctrl+G", "<Cmd>Telescope live_grep<CR>")
  sep("Edit", 3)
  item("Edit", "Toggle Comment", "Ctrl+/", "<Cmd>normal gcc<CR>", "ni")
  item("Edit", "Toggle Comment", "Ctrl+/", ":normal gcc<CR>", "v")

  item("View", "Command Palette…", "F1", "<Cmd>Telescope commands<CR>")
  item("View", "File Tree", "Ctrl+B", "<Cmd>Neotree toggle<CR>")
  item("View", "Claude Panel", "F12", "<Cmd>ClaudeToggle<CR>")
  sep("View", 1)
  item("View", "Word Wrap", nil, "<Cmd>setlocal wrap! linebreak!<CR>")
  item("View", "Line Numbers", nil, "<Cmd>setlocal number!<CR>")
  sep("View", 2)
  item("View", "Theme: Follow System", nil, "<Cmd>lua require('config.theme').set_mode('system')<CR>")
  item("View", "Theme: Light", nil, "<Cmd>lua require('config.theme').set_mode('light')<CR>")
  item("View", "Theme: Dark", nil, "<Cmd>lua require('config.theme').set_mode('dark')<CR>")

  item("Go", "Go to File…", "Ctrl+P", "<Cmd>Telescope find_files<CR>")
  item("Go", "Go to Line…", nil, a("go_to_line"))
  sep("Go", 1)
  item("Go", "Next Tab", "Ctrl+PgDn", "<Cmd>lua require('config.tabs').cycle(1)<CR>")
  item("Go", "Previous Tab", "Ctrl+PgUp", "<Cmd>lua require('config.tabs').cycle(-1)<CR>")
  sep("Go", 2)
  item("Go", "Next Claude Change", "F7", "<Cmd>lua require('claude').next_change(1)<CR>")
  item("Go", "Previous Claude Change", "Shift+F7", "<Cmd>lua require('claude').next_change(-1)<CR>")

  item("Claude", "Focus Claude", "Ctrl+\\", "<Cmd>Claude<CR>")
  item("Claude", "Show/Hide Panel", "F12", "<Cmd>ClaudeToggle<CR>")
  item("Claude", "Panel Width…", nil, a("panel_width"))
  sep("Claude", 1)
  item("Claude", "Send File", nil, "<Cmd>ClaudeSend<CR>", "ni")
  item("Claude", "Send Selection", "Ctrl+\\", ":ClaudeSend<CR>", "v")
  sep("Claude", 2)
  item("Claude", "Next Change", "F7", "<Cmd>lua require('claude').next_change(1)<CR>")
  item("Claude", "List Changes", nil, "<Cmd>ClaudeChanges<CR>")
  item("Claude", "Accept Changes in File", nil, "<Cmd>ClaudeAccept<CR>")
  item("Claude", "Accept All Changes", nil, "<Cmd>ClaudeAcceptAll<CR>")
  item("Claude", "Revert This Change", nil, "<Cmd>ClaudeRevertHunk<CR>")
  item("Claude", "Revert Whole File", nil, "<Cmd>ClaudeRevert<CR>")

  item("Help", "Keyboard Shortcuts", nil, "<Cmd>Shortcuts<CR>")
  item("Help", "Neovim Help", nil, "<Cmd>help<CR>")
end

-- open a menu; the editor window gets focus so the menu acts on the file
function M.open(name)
  if vim.bo.buftype ~= "" then
    local win = require("claude").editor_win()
    if win then api.nvim_set_current_win(win) end
  end
  vim.schedule(function() pcall(vim.cmd, "popup " .. name) end)
end

function _G.MenuBarClick(i)
  M.open(M.menus[i])
end

function M.render()
  local out = { "%#MenuBar# " }
  for i, name in ipairs(M.menus) do
    out[#out + 1] = "%" .. i .. "@v:lua.MenuBarClick@ " .. name .. " %X"
  end
  out[#out + 1] = "%=%#MenuBarTitle#" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. " "
  return table.concat(out)
end

local function set_hl()
  api.nvim_set_hl(0, "MenuBar", { link = "TabLineFill", default = true })
  api.nvim_set_hl(0, "MenuBarTitle", { link = "TabLineFill", default = true })
end

function M.setup()
  define()
  set_hl()
  api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.require'config.menubar'.render()"
end

return M
