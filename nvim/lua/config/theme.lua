-- i3 colors in dark mode, Xcode colors in light mode, following the macOS appearance
-- (or a fixed light/dark choice from View > Theme, remembered across restarts).
local M = {}

M.dark = "i3"
M.light = "xcodelight"

local mode_file = vim.fn.stdpath("state") .. "/theme-mode"
local mode = "system"

local function apply(dark)
  if mode ~= "system" then dark = mode == "dark" end
  local name = dark and M.dark or M.light
  if vim.g.colors_name == name then return end
  vim.o.background = dark and "dark" or "light"
  vim.cmd.colorscheme(name)
end

-- `defaults read -g AppleInterfaceStyle` prints "Dark" in dark mode and fails in light mode
local function is_dark(res)
  return res.code == 0 and res.stdout:find("Dark") ~= nil
end

local function check()
  if vim.fn.has("mac") == 0 then return apply(vim.o.background == "dark") end
  vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(res)
    vim.schedule(function() apply(is_dark(res)) end)
  end)
end

-- "system", "light" or "dark"
function M.set_mode(m)
  mode = m
  local f = io.open(mode_file, "w")
  if f then
    f:write(m)
    f:close()
  end
  check()
end

function M.setup()
  local f = io.open(mode_file, "r")
  if f then
    mode = f:read("*l") or "system"
    f:close()
  end
  if vim.fn.has("mac") == 0 then
    -- elsewhere Neovim detects the terminal background itself
    apply(vim.o.background == "dark")
    vim.api.nvim_create_autocmd("OptionSet", {
      pattern = "background",
      callback = function() apply(vim.o.background == "dark") end,
    })
    return
  end
  apply(is_dark(vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }):wait()))
  vim.uv.new_timer():start(3000, 3000, check)
  vim.api.nvim_create_autocmd("FocusGained", { callback = check })
end

return M
