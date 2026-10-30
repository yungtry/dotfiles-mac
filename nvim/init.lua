-- Neovim as a regular editor: mouse, tabs, file tree and a Claude Code panel.
-- Shortcut cheat sheet: :Shortcuts (or README.md in this directory).

require("config.options")

-- lazy.nvim (plugin manager), installs itself on first start
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

local nerd = vim.g.have_nerd_font
require("lazy").setup("plugins", {
  install = { colorscheme = { "xcodedark", "habamax" } },
  change_detection = { notify = false },
  ui = {
    border = "rounded",
    icons = nerd and {} or {
      cmd = "⌘ ", config = "⚙ ", event = "★ ", ft = "▤ ", init = "⚙ ", import = "→ ", keys = "⌨ ",
      lazy = "z ", loaded = "●", not_loaded = "○", plugin = "◆ ", runtime = "▶ ", require = "↳ ",
      source = "▤ ", start = "▶ ", task = "✔ ", list = { "●", "→", "★", "‒" },
    },
  },
})

require("claude").setup()
require("config.tabs").setup()
require("config.menubar").setup()
require("config.keymaps")
require("config.autocmds")
