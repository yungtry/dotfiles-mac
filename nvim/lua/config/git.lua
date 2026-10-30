-- Git panel: lazygit in a floating window over the editor (F9, Git menu).
-- Quit it with q; files it changes (checkout, discard ...) reload in the editor.
local M = {}
local api = vim.api

function M.open()
  if M.win and api.nvim_win_is_valid(M.win) then -- already open: just focus it
    api.nvim_set_current_win(M.win)
    return vim.cmd.startinsert()
  end
  if vim.fn.executable("lazygit") == 0 then
    return vim.notify("The git panel needs lazygit: brew install lazygit", vim.log.levels.WARN)
  end
  local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " Git — " .. vim.fn.fnamemodify(root, ":t") .. " ",
    title_pos = "center",
  })
  M.win = win
  vim.fn.jobstart({ "lazygit" }, {
    term = true,
    cwd = root,
    on_exit = function()
      vim.schedule(function()
        if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
        if api.nvim_buf_is_valid(buf) then api.nvim_buf_delete(buf, { force = true }) end
        vim.cmd("silent! checktime")
      end)
    end,
  })
  vim.cmd.startinsert()
end

return M
