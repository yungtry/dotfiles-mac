-- i3: the i3 window manager's default colors (client.*, i3bar and i3status) as a dark Neovim theme.
-- Gray editor like an unfocused window, blue selection and borders like the focused one,
-- a black status bar like i3bar, and i3status green / yellow / red for strings, numbers and errors.

vim.cmd.highlight("clear")
vim.g.colors_name = "i3"
vim.o.background = "dark"

local c = {
  bar = "#000000", -- i3bar background
  bg = "#222222", -- client.unfocused / inactive_workspace background
  bg2 = "#2a2a2a",
  line = "#333333", -- client.focused_inactive border
  gray = "#5f676a", -- client.focused_inactive background
  dim = "#484e50", -- client.focused_inactive indicator
  sep = "#666666", -- i3bar separator
  muted = "#888888", -- client.unfocused text
  fg = "#ffffff", -- client.* text
  border = "#4c7899", -- client.focused border
  focus = "#285577", -- client.focused background
  blue = "#2e9ef4", -- client.focused indicator
  sky = "#8cc4ef",
  steel = "#7aa6c8",
  green = "#66cc66", -- i3status color_good, softened
  yellow = "#e6e64c", -- i3status color_degraded, softened
  red = "#ff4c4c", -- i3status color_bad, softened
  urgent = "#900000", -- client.urgent background
}

local groups = {
  Normal = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.bg },
  FloatBorder = { fg = c.border, bg = c.bg },
  FloatTitle = { fg = c.fg, bg = c.bg, bold = true },
  Cursor = { fg = c.bg, bg = c.fg },
  CursorLine = { bg = c.bg2 },
  CursorColumn = { bg = c.bg2 },
  ColorColumn = { bg = c.bg2 },
  CursorLineNr = { fg = c.fg, bold = true },
  LineNr = { fg = c.gray },
  SignColumn = { bg = "NONE" },
  FoldColumn = { fg = c.gray },
  Folded = { fg = c.muted, bg = c.line },
  NonText = { fg = c.dim },
  Whitespace = { fg = c.dim },
  EndOfBuffer = { fg = c.bg },
  Conceal = { fg = c.muted },
  WinSeparator = { fg = c.line },
  VertSplit = { link = "WinSeparator" },
  Visual = { bg = c.focus },
  Search = { fg = c.fg, bg = c.gray },
  IncSearch = { fg = c.bar, bg = c.blue },
  CurSearch = { link = "IncSearch" },
  Substitute = { fg = c.fg, bg = c.urgent },
  MatchParen = { bg = c.gray, bold = true },
  Directory = { fg = c.blue },
  Title = { fg = c.fg, bold = true },

  -- i3bar and its workspace buttons
  StatusLine = { fg = c.fg, bg = c.bar },
  StatusLineNC = { fg = c.muted, bg = c.bar },
  WinBar = { fg = c.fg, bg = c.bg },
  WinBarNC = { fg = c.muted, bg = c.bg },
  TabLine = { fg = c.muted, bg = c.bg },
  TabLineFill = { fg = c.muted, bg = c.bar },
  TabLineSel = { fg = c.fg, bg = c.focus, bold = true },

  Pmenu = { fg = c.fg, bg = c.line },
  PmenuSel = { fg = c.fg, bg = c.focus },
  PmenuSbar = { bg = c.line },
  PmenuThumb = { bg = c.gray },
  PmenuKind = { fg = c.steel, bg = c.line },
  PmenuExtra = { fg = c.muted, bg = c.line },
  WildMenu = { link = "PmenuSel" },
  QuickFixLine = { bg = c.focus },

  ModeMsg = { fg = c.fg, bold = true },
  MsgArea = { fg = c.fg },
  MoreMsg = { fg = c.green },
  Question = { fg = c.green },
  ErrorMsg = { fg = c.red, bold = true },
  WarningMsg = { fg = c.yellow },

  SpellBad = { undercurl = true, sp = c.red },
  SpellCap = { undercurl = true, sp = c.yellow },
  SpellRare = { undercurl = true, sp = c.blue },
  SpellLocal = { undercurl = true, sp = c.steel },

  DiffAdd = { bg = "#1f3a1f" },
  DiffChange = { bg = "#1f3347" },
  DiffDelete = { fg = c.red, bg = "#3d1515" },
  DiffText = { bg = c.focus },
  Added = { fg = c.green },
  Changed = { fg = c.blue },
  Removed = { fg = c.red },

  -- syntax
  Comment = { fg = c.muted, italic = true },
  Constant = { fg = c.yellow },
  String = { fg = c.green },
  Character = { fg = c.green },
  Number = { fg = c.yellow },
  Boolean = { fg = c.yellow },
  Float = { fg = c.yellow },
  Identifier = { fg = c.fg },
  Function = { fg = c.sky },
  Statement = { fg = c.blue },
  Keyword = { fg = c.blue },
  Conditional = { fg = c.blue },
  Repeat = { fg = c.blue },
  Label = { fg = c.blue },
  Exception = { fg = c.blue },
  Operator = { fg = c.fg },
  PreProc = { fg = c.steel },
  Include = { fg = c.blue },
  Type = { fg = c.steel },
  StorageClass = { fg = c.blue },
  Structure = { fg = c.steel },
  Special = { fg = c.yellow },
  SpecialChar = { fg = c.yellow },
  Tag = { fg = c.blue },
  Delimiter = { fg = c.muted },
  SpecialComment = { fg = c.muted, bold = true },
  Underlined = { underline = true },
  Error = { fg = c.red },
  Todo = { fg = c.bar, bg = c.yellow, bold = true },

  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.blue },
  ["@variable.parameter"] = { fg = c.fg, italic = true },
  ["@property"] = { fg = c.fg },
  ["@constructor"] = { fg = c.steel },
  ["@punctuation"] = { fg = c.muted },
  ["@punctuation.bracket"] = { fg = c.muted },
  ["@punctuation.delimiter"] = { fg = c.muted },
  ["@tag.attribute"] = { fg = c.steel },
  ["@markup.heading"] = { fg = c.fg, bold = true },
  ["@markup.link"] = { fg = c.blue, underline = true },
  ["@markup.raw"] = { fg = c.green },
  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@lsp.type.parameter"] = { link = "@variable.parameter" },

  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.yellow },
  DiagnosticInfo = { fg = c.blue },
  DiagnosticHint = { fg = c.muted },
  DiagnosticOk = { fg = c.green },
  DiagnosticUnderlineError = { undercurl = true, sp = c.red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.blue },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.muted },

  -- gitsigns, neo-tree and telescope
  GitSignsAdd = { link = "Added" },
  GitSignsChange = { link = "Changed" },
  GitSignsDelete = { link = "Removed" },
  NeoTreeNormal = { fg = c.fg, bg = c.bg },
  NeoTreeNormalNC = { fg = c.fg, bg = c.bg },
  NeoTreeWinSeparator = { link = "WinSeparator" },
  NeoTreeRootName = { fg = c.fg, bold = true },
  NeoTreeGitModified = { fg = c.blue },
  NeoTreeGitAdded = { fg = c.green },
  NeoTreeGitUntracked = { fg = c.green },
  TelescopeBorder = { link = "FloatBorder" },
  TelescopeSelection = { link = "PmenuSel" },
  TelescopeMatching = { fg = c.blue, bold = true },
}

for name, opts in pairs(groups) do
  vim.api.nvim_set_hl(0, name, opts)
end

-- the terminal (and the Claude panel inside it) in the same colors
local term = {
  c.bar, c.urgent, "#33aa33", "#cccc33", c.focus, "#8a5fa6", c.border, "#cccccc",
  c.sep, c.red, c.green, c.yellow, c.blue, "#b48ead", c.sky, c.fg,
}
for i, color in ipairs(term) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
