vim.g.mapleader = " "

-- File icons need a Nerd Font in the terminal. After installing one, e.g.
--   brew install --cask font-jetbrains-mono-nerd-font
-- select it in the terminal settings and set this to true.
vim.g.have_nerd_font = false

-- true: files open straight into typing (Insert) mode, like a regular editor.
-- Esc still switches to Vim's Normal mode.
vim.g.modeless = true

-- the file tree replaces netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local o = vim.opt

o.mouse = "a"
o.mousemodel = "popup_setpos" -- right click = context menu (in terminals that pass it through)
o.clipboard = "unnamedplus"   -- system clipboard
o.keymodel = "startsel,stopsel" -- Shift+arrows select
o.selectmode = "mouse,key"    -- typing replaces the selection
o.whichwrap:append("<,>,[,]") -- arrows move across line ends

o.number = true
o.cursorline = true
o.signcolumn = "yes"
o.termguicolors = true
o.showtabline = 2
o.laststatus = 3
o.showmode = false
o.wrap = false
o.scrolloff = 5
o.sidescrolloff = 8
o.fillchars = { eob = " " }
o.splitright = true
o.splitbelow = true

o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true

o.ignorecase = true
o.smartcase = true
o.undofile = true
o.swapfile = false -- no .swp warnings when Claude edits an open file
o.confirm = true
o.autoread = false -- reloading files is handled by lua/claude (live diff)
o.updatetime = 250

o.completeopt = { "menuone", "noselect", "popup" }
o.autocomplete = true
