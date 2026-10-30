-- File tabs in a bar above each editor window (the top row of the screen is the menu bar).
-- The file tree and the Claude panel get a title in the same row instead.
local M = {}
local api = vim.api

local titles = { ["neo-tree"] = "EXPLORER", claude = "CLAUDE CODE" }
local expr = "%!v:lua.require'config.tabs'.render()"

local function listed()
  return vim.tbl_filter(function(b) return vim.bo[b].buflisted end, api.nvim_list_bufs())
end

-- file name, with the parent directory when two open files share a name
local function labels(bufs)
  local names, count = {}, {}
  for _, b in ipairs(bufs) do
    local name = api.nvim_buf_get_name(b)
    names[b] = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
    count[names[b]] = (count[names[b]] or 0) + 1
  end
  for _, b in ipairs(bufs) do
    if count[names[b]] > 1 and api.nvim_buf_get_name(b) ~= "" then
      names[b] = vim.fn.fnamemodify(api.nvim_buf_get_name(b), ":h:t") .. "/" .. names[b]
    end
  end
  return names
end

function M.render()
  local win = vim.g.statusline_winid
  local cur = api.nvim_win_get_buf(win)
  local title = titles[vim.bo[cur].filetype]
  if title then return "%#TabTitle# " .. title .. "%#TabFill#" end

  local bufs = listed()
  local names = labels(bufs)
  local items, active = {}, 1
  for i, b in ipairs(bufs) do
    if b == cur then active = i end
    local hl = b == cur and "%#TabActive#" or "%#TabInactive#"
    local mark = vim.bo[b].modified and "●" or "✕"
    local label = " " .. names[b] .. " "
    items[i] = {
      text = hl .. "%" .. b .. "@v:lua.TabClick@" .. label:gsub("%%", "%%%%") .. "%X"
        .. "%" .. b .. "@v:lua.TabClose@" .. mark .. " %X" .. "%#TabSep#│",
      width = vim.fn.strdisplaywidth(label .. mark .. " ") + 1,
    }
  end

  -- too many tabs for the window: keep the active one visible, show « » for the rest
  local width = api.nvim_win_get_width(win) - 2
  local first, last, used = active, active, items[active] and items[active].width or 0
  while true do
    local grew = false
    if last < #items and used + items[last + 1].width <= width then
      last, used, grew = last + 1, used + items[last + 1].width, true
    end
    if first > 1 and used + items[first - 1].width <= width then
      first, used, grew = first - 1, used + items[first - 1].width, true
    end
    if not grew then break end
  end
  local out = { first > 1 and "%#TabFill#«" or "" }
  for i = first, last do out[#out + 1] = items[i].text end
  out[#out + 1] = "%#TabFill#" .. (last < #items and "%=»" or "")
  return table.concat(out)
end

-- minwid = buffer number; button: "l" left, "m" middle
function _G.TabClick(buf, _, button)
  if button == "m" then return _G.TabClose(buf) end
  local win = vim.fn.getmousepos().winid
  if win == 0 or not api.nvim_buf_is_valid(buf) then return end
  api.nvim_set_current_win(win)
  api.nvim_win_set_buf(win, buf)
end

function _G.TabClose(buf)
  vim.schedule(function() require("config.util").close_buffer(buf) end)
end

-- next / previous tab in the current window
function M.cycle(dir)
  if vim.bo.buftype ~= "" then return end
  local bufs = listed()
  local idx = 1
  for i, b in ipairs(bufs) do
    if b == api.nvim_get_current_buf() then idx = i end
  end
  local target = bufs[(idx - 1 + dir) % #bufs + 1]
  if target then api.nvim_set_current_buf(target) end
end

-- the bar only goes on regular (non-floating) windows: files, the tree and the Claude panel
local function attach(win)
  if not api.nvim_win_is_valid(win) or api.nvim_win_get_config(win).relative ~= "" then return end
  local buf = api.nvim_win_get_buf(win)
  local want = (vim.bo[buf].buftype == "" or titles[vim.bo[buf].filetype]) and expr or ""
  if vim.wo[win].winbar ~= want then vim.wo[win].winbar = want end
end

local function set_hl()
  local function hl(name, opts)
    opts.default = true
    api.nvim_set_hl(0, name, opts)
  end
  hl("TabActive", { link = "Normal" })
  hl("TabInactive", { link = "TabLine" })
  hl("TabFill", { link = "TabLineFill" })
  hl("TabSep", { link = "TabLineFill" })
  hl("TabTitle", { link = "TabLineFill" })
end

function M.setup()
  set_hl()
  local group = api.nvim_create_augroup("tabs", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "FileType", "TermOpen", "WinEnter" }, {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do attach(win) end
      end)
    end,
  })
  api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufModifiedSet", "BufFilePost" }, {
    group = group,
    callback = function() vim.schedule(function() vim.cmd("redrawstatus!") end) end,
  })
end

return M
