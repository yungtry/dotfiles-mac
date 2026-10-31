-- Terminal panel below the editor (Ctrl+`, View > Terminal), like VS Code's.
-- Hiding it keeps the shell running; `exit` in the shell closes it.
local M = {}
local api = vim.api

M.height = 0.3 -- default height as a fraction of the screen (dragging the border is remembered)

local term = {} -- { buf, job, height }

local function win()
  if not (term.buf and api.nvim_buf_is_valid(term.buf)) then return end
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_buf(w) == term.buf then return w end
  end
end

local function start(buf)
  term.job = vim.fn.jobstart({ vim.o.shell }, {
    term = true,
    cwd = vim.fn.getcwd(),
    on_exit = function()
      term.job = nil
      vim.schedule(function()
        local w = win()
        if w and #api.nvim_tabpage_list_wins(0) > 1 then api.nvim_win_close(w, true) end
        if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete, buf, { force = true }) end
      end)
    end,
  })
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "terminal"
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { buffer = buf, command = "startinsert" })
  -- after scrolling with the wheel: click to type again
  vim.keymap.set("n", "<LeftRelease>", "<Cmd>startinsert<CR>", { buffer = buf })
end

function M.open()
  local w = win()
  if not w then
    -- split the editor, not the whole screen, so the file tree and Claude keep their full height
    local ed = require("claude").editor_win()
    if ed then api.nvim_set_current_win(ed) end
    vim.cmd("belowright split")
    w = api.nvim_get_current_win()
    api.nvim_win_set_height(w, term.height or math.floor(vim.o.lines * M.height))
    local fresh = not (term.buf and api.nvim_buf_is_valid(term.buf))
    if fresh then term.buf = api.nvim_create_buf(false, false) end
    api.nvim_win_set_buf(w, term.buf)
    if fresh then start(term.buf) end
    local wo = vim.wo[w][0]
    wo.number, wo.relativenumber, wo.signcolumn = false, false, "no"
    wo.cursorline, wo.scrolloff, wo.sidescrolloff = false, 0, 0
    wo.winfixheight, wo.winfixbuf = true, true
  end
  api.nvim_set_current_win(w)
  vim.cmd.startinsert()
end

function M.hide()
  local w = win()
  if not w or #api.nvim_tabpage_list_wins(0) == 1 then return end
  local focused = api.nvim_get_current_win() == w
  if focused then vim.cmd.stopinsert() end
  term.height = api.nvim_win_get_height(w)
  api.nvim_win_hide(w)
  local ed = focused and require("claude").editor_win()
  if ed then api.nvim_set_current_win(ed) end
end

-- Ctrl+` : hidden → show it, shown → focus it, focused → hide it
function M.toggle()
  local w = win()
  if w and api.nvim_get_current_win() == w then M.hide() else M.open() end
end

return M
