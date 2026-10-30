local nerd = vim.g.have_nerd_font
local icons = nerd and { "nvim-tree/nvim-web-devicons" } or {}

return {
  -- Xcode colors, light/dark following macOS (lua/config/theme.lua)
  {
    "arzg/vim-colors-xcode",
    lazy = false,
    priority = 1000,
    config = function() require("config.theme").setup() end,
  },

  -- file tree on the left
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    dependencies = vim.list_extend({ "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" }, icons),
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      open_files_do_not_replace_types = { "terminal", "claude", "qf", "trouble" },
      default_component_configs = {
        icon = nerd and {} or {
          folder_closed = "▸",
          folder_open = "▾",
          folder_empty = "▹",
          default = " ",
          provider = function() end,
        },
        modified = { symbol = "●" },
        git_status = {
          symbols = nerd and {} or {
            added = "+", modified = "~", deleted = "✕", renamed = "»",
            untracked = "?", ignored = "◌", unstaged = "", staged = "✓", conflict = "!",
          },
        },
      },
      window = {
        width = 30,
        mappings = {
          ["<LeftRelease>"] = "open", -- a single click opens a file / folder
          ["@"] = {
            function(state) require("claude").send(state.tree:get_node():get_id()) end,
            desc = "Send to Claude",
          },
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        hijack_netrw_behavior = "open_default",
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          never_show = { ".git", ".DS_Store" },
        },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = icons,
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        icons_enabled = nerd,
        component_separators = "│",
        section_separators = "",
        disabled_filetypes = { statusline = {} },
        refresh = { statusline = 1000 }, -- keeps the clock current
      },
      sections = {
        lualine_x = {
          { function() return require("claude").status() end, color = "DiagnosticWarn" },
          "encoding",
          "filetype",
        },
        lualine_z = {
          "location",
          { function() return os.date("%H:%M") end },
        },
      },
    },
  },

  -- Ctrl+P / Ctrl+G
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = vim.list_extend({ "nvim-lua/plenary.nvim" }, icons),
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          prompt_prefix = "› ",
          selection_caret = "▸ ",
          file_ignore_patterns = { "^%.git/", "node_modules/" },
          get_selection_window = function() return require("claude").editor_win() or 0 end,
          mappings = { i = { ["<Esc>"] = actions.close } },
        },
        pickers = { find_files = { hidden = true } },
      }
    end,
  },

  -- git changes in the sign column
  { "lewis6991/gitsigns.nvim", event = { "BufReadPost", "BufNewFile" }, opts = {} },

  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- Markdown shown rendered (headings, lists, checkboxes, tables, code blocks);
  -- the line under the cursor shows the raw text so it can be edited
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {
      render_modes = true, -- also in Insert mode (files open in Insert mode, see vim.g.modeless)
      anti_conceal = { enabled = true },
      heading = nerd and {} or { sign = false, icons = { "█ ", "▓ ", "▒ ", "░ ", "░ ", "░ " } },
      code = nerd and {} or { sign = false, language_icon = false },
      checkbox = nerd and {} or { unchecked = { icon = "☐ " }, checked = { icon = "☑ " } },
    },
  },
}
