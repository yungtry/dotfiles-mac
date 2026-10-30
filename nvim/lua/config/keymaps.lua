-- Regular-editor shortcuts. They work in Normal and Insert mode and on selections.
local map = vim.keymap.set
local util = require("config.util")
local claude = require("claude")

local all = { "n", "i", "v" }
local function pum(key, fallback) -- keep the key's default meaning while the completion menu is open
  return function() return vim.fn.pumvisible() == 1 and key or fallback end
end

-- file
map(all, "<C-s>", util.save, { desc = "Save" })
map({ "n", "i" }, "<C-n>", pum("<C-n>", "<Cmd>enew<CR>"), { expr = true, desc = "New file" })
map({ "n", "i", "v", "t" }, "<C-q>", "<Cmd>confirm qall<CR>", { desc = "Quit" })

-- editing
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
map("v", "<C-z>", "<Esc>u", { desc = "Undo" })
map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })

map("v", "<C-c>", '"+y', { desc = "Copy" })
map("n", "<C-c>", '"+yy', { desc = "Copy line" })
map("i", "<C-c>", '<C-o>"+yy', { desc = "Copy line" })
map("v", "<C-x>", '"+d', { desc = "Cut" })
map("n", "<C-x>", '"+dd', { desc = "Cut line" })
map("n", "<C-v>", '"+P', { desc = "Paste" })
map("i", "<C-v>", "<C-r><C-o>+", { desc = "Paste" })
map("v", "<C-v>", '"+P', { desc = "Paste" })
map("c", "<C-v>", "<C-r>+", { desc = "Paste" })
map("x", "<BS>", '"_d', { desc = "Delete selection" })
map("x", "<Del>", '"_d', { desc = "Delete selection" })

map("n", "<C-a>", "ggVG<C-g>", { desc = "Select all" })
map({ "i", "v" }, "<C-a>", "<Esc>ggVG<C-g>", { desc = "Select all" })

map("x", "<Tab>", ">gv", { desc = "Indent" })
map("x", "<S-Tab>", "<gv", { desc = "Outdent" })
map("i", "<S-Tab>", "<C-d>", { desc = "Outdent" })

-- Ctrl+/ (terminals send it as Ctrl+_)
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", key, "gcc", { remap = true, desc = "Toggle comment" })
  map("i", key, "<Cmd>normal gcc<CR>", { desc = "Toggle comment" })
  map("v", key, "gc", { remap = true, desc = "Toggle comment" })
end

-- search
map("n", "<C-f>", "/", { desc = "Find in file" })
map("i", "<C-f>", "<C-o>/", { desc = "Find in file" })
map({ "n", "i" }, "<F3>", "<Cmd>normal! n<CR>", { desc = "Find next" })
map({ "n", "i" }, "<S-F3>", "<Cmd>normal! N<CR>", { desc = "Find previous" })
map({ "n", "i" }, "<C-r>", util.find_replace, { desc = "Find and replace" })
map("n", "<Esc>", "<Cmd>nohlsearch<CR><Esc>")
map({ "n", "i" }, "<C-p>", pum("<C-p>", "<Cmd>Telescope find_files<CR>"), { expr = true, desc = "Quick open" })
map({ "n", "i" }, "<C-g>", "<Cmd>Telescope live_grep<CR>", { desc = "Search in project" })
map({ "n", "i" }, "<F1>", "<Cmd>Telescope commands<CR>", { desc = "Command palette" })
map({ "n", "i" }, "<C-S-p>", "<Cmd>Telescope commands<CR>", { desc = "Command palette" })

-- tabs and panels
map({ "n", "i" }, "<C-w>", function() util.close_buffer() end, { desc = "Close tab" })
local tabs = require("config.tabs")
map({ "n", "i" }, "<C-PageDown>", function() tabs.cycle(1) end, { desc = "Next tab" })
map({ "n", "i" }, "<C-PageUp>", function() tabs.cycle(-1) end, { desc = "Previous tab" })
map("n", "<Tab>", function() tabs.cycle(1) end, { desc = "Next tab" })
map("n", "<S-Tab>", function() tabs.cycle(-1) end, { desc = "Previous tab" })
map({ "n", "i", "v", "t" }, "<F9>", function() require("config.git").open() end, { desc = "Git panel" })
map(all, "<F10>", function() require("config.menubar").open("File") end, { desc = "Open the File menu" })
map({ "n", "i", "v" }, "<C-b>", "<Cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })

-- Claude
map({ "n", "i", "t" }, "<C-\\>", claude.focus_toggle, { desc = "Switch focus: editor ⇄ Claude" })
map("v", "<C-\\>", ":ClaudeSend<CR>", { silent = true, desc = "Send selection to Claude" })
map({ "n", "i", "t" }, "<F12>", claude.toggle, { desc = "Show/hide the Claude panel" })
map({ "n", "i" }, "<LeftRelease>", function() claude.click() end, { desc = "Click Accept/Revert buttons" })
map({ "n", "i" }, "<F7>", function() claude.next_change(1) end, { desc = "Next Claude change" })
map({ "n", "i" }, "<S-F7>", function() claude.next_change(-1) end, { desc = "Previous Claude change" })
map("n", "]c", function() claude.next_change(1) end, { desc = "Next Claude change" })
map("n", "[c", function() claude.next_change(-1) end, { desc = "Previous Claude change" })

-- context menu: right click where the terminal passes it through (not Terminal.app),
-- Option+click or Shift+F10
map(all, "<S-F10>", function() util.context_menu(false) end, { desc = "Context menu" })
map(all, "<A-LeftMouse>", function() util.context_menu(true) end, { desc = "Context menu" })

for _, group in ipairs({ "nvim.popupmenu", "nvim_popupmenu" }) do
  pcall(vim.api.nvim_del_augroup_by_name, group)
end
vim.cmd([[
  silent! aunmenu PopUp
  vnoremenu PopUp.Cut                              "+d
  vnoremenu PopUp.Copy                             "+y
  anoremenu PopUp.Paste                            "+gP
  vnoremenu PopUp.Paste                            "+P
  nnoremenu PopUp.Select\ All                      ggVG<C-g>
  inoremenu PopUp.Select\ All                      <Esc>ggVG<C-g>
  anoremenu PopUp.-1-                              <Nop>
  anoremenu PopUp.Find\ in\ Project                <Cmd>Telescope live_grep<CR>
  anoremenu PopUp.Close\ Tab                       <Cmd>lua require("config.util").close_buffer()<CR>
  anoremenu PopUp.-2-                              <Nop>
  nnoremenu PopUp.Claude:\ Send\ File              <Cmd>ClaudeSend<CR>
  inoremenu PopUp.Claude:\ Send\ File              <Cmd>ClaudeSend<CR>
  vnoremenu PopUp.Claude:\ Send\ Selection         :ClaudeSend<CR>
  anoremenu PopUp.Claude:\ Next\ Change            <Cmd>lua require("claude").next_change(1)<CR>
  anoremenu PopUp.Claude:\ Accept\ Changes         <Cmd>ClaudeAccept<CR>
  anoremenu PopUp.Claude:\ Accept\ This\ Change    <Cmd>ClaudeAcceptHunk<CR>
  anoremenu PopUp.Claude:\ Revert\ This\ Change    <Cmd>ClaudeRevertHunk<CR>
  anoremenu PopUp.Claude:\ Revert\ Whole\ File     <Cmd>ClaudeRevert<CR>
  anoremenu PopUp.Claude:\ List\ Changes           <Cmd>ClaudeChanges<CR>
]])
