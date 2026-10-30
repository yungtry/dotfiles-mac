local M = {}
local api = vim.api

-- Close a tab (buffer) without closing the window it was shown in.
function M.close_buffer(buf)
  buf = (buf == nil or buf == 0) and api.nvim_get_current_buf() or buf
  if vim.bo[buf].buftype ~= "" then return end
  if vim.bo[buf].modified then
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
    local choice = vim.fn.confirm(("Save changes to %s?"):format(name ~= "" and name or "[No Name]"), "&Yes\n&No\n&Cancel", 1)
    if choice == 1 then
      if not pcall(api.nvim_buf_call, buf, function() vim.cmd.write() end) then return end
    elseif choice ~= 2 then
      return
    end
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    api.nvim_win_call(win, function()
      local alt = vim.fn.bufnr("#")
      if alt > 0 and alt ~= buf and vim.bo[alt].buflisted then
        vim.cmd.buffer(alt)
      else
        pcall(vim.cmd.bprevious)
        if api.nvim_get_current_buf() == buf then require("config.welcome").show() end
      end
    end)
  end
  if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete, buf, { force = true }) end
end

function M.save()
  if vim.bo.buftype ~= "" then return end
  if api.nvim_buf_get_name(0) == "" then
    local name = vim.fn.input({ prompt = "Save as: ", default = vim.fn.getcwd() .. "/", completion = "file" })
    if name == "" or name:sub(-1) == "/" then return end
    vim.cmd("saveas " .. vim.fn.fnameescape(name))
    return
  end
  local ok, err = pcall(vim.cmd, "silent update")
  if not ok then vim.notify(err, vim.log.levels.ERROR) end
end

function M.find_replace()
  local word = vim.fn.expand("<cword>")
  local find = vim.fn.input({ prompt = "Find: ", default = word })
  if find == "" then return end
  local repl = vim.fn.input({ prompt = ("Replace %q with: "):format(find) })
  local ok, err = pcall(vim.cmd, ("%%s/\\V%s/%s/gc"):format(vim.fn.escape(find, "/\\"), vim.fn.escape(repl, "/\\&~")))
  if not ok then vim.notify(err, vim.log.levels.WARN) end
end

-- Context menu. Terminal.app keeps right click for its own menu, so this is also
-- bound to Option+click and Shift+F10.
function M.context_menu(at_mouse)
  local pos = at_mouse and vim.fn.getmousepos()
  if pos and pos.winid ~= 0 and api.nvim_get_mode().mode:find("^[nit]") then
    api.nvim_set_current_win(pos.winid)
    if pos.line > 0 then pcall(api.nvim_win_set_cursor, pos.winid, { pos.line, math.max(pos.column - 1, 0) }) end
  end
  if vim.bo.buftype ~= "" then
    local win = require("claude").editor_win()
    if not win then return end
    api.nvim_set_current_win(win)
  end
  vim.cmd("popup PopUp")
end

return M
