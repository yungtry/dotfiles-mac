local api = vim.api
local group = api.nvim_create_augroup("editor", { clear = true })
local au = function(event, opts)
  opts.group = group
  api.nvim_create_autocmd(event, opts)
end

if vim.g.modeless then
  -- files go straight into typing mode, panels (tree etc.) stay in Normal mode
  au({ "BufEnter", "WinEnter" }, {
    callback = function()
      vim.schedule(function()
        local bo, mode = vim.bo, api.nvim_get_mode().mode
        if bo.buftype == "" and bo.modifiable and not bo.readonly and mode == "n" then
          vim.cmd.startinsert()
        elseif bo.buftype == "nofile" and not bo.modifiable and mode == "i" then
          vim.cmd.stopinsert()
        end
      end)
    end,
  })
end

-- Ctrl+Z undoes back to the last pause in typing, not the whole Insert session
au("CursorHoldI", {
  callback = function()
    if vim.bo.buftype == "" and vim.fn.pumvisible() == 0 then
      api.nvim_feedkeys(vim.keycode("<C-g>u"), "n", false)
    end
  end,
})

au("TextYankPost", { callback = function() vim.hl.on_yank({ timeout = 150 }) end })

-- reopen files where you left off
au("BufReadPost", {
  callback = function(ev)
    local mark = api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 1 and mark[1] <= api.nvim_buf_line_count(ev.buf) then
      pcall(api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

au("StdinReadPre", { callback = function() vim.g.started_with_stdin = true end })

-- `nvim` or `nvim some/dir` → IDE layout: files | editor | Claude
au("VimEnter", {
  nested = true,
  callback = function()
    if vim.g.started_with_stdin then return end
    local args = vim.fn.argv()
    local dir
    if #args == 0 then
      dir = vim.fn.getcwd()
    elseif #args == 1 and vim.fn.isdirectory(args[1]) == 1 then
      dir = vim.fn.fnamemodify(args[1], ":p")
    end
    if not dir then return end

    vim.cmd.cd(vim.fn.fnameescape(dir))
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if vim.fn.isdirectory(api.nvim_buf_get_name(buf)) == 1 then
        if api.nvim_get_current_buf() == buf then vim.cmd.enew() end
        pcall(api.nvim_buf_delete, buf, { force = true })
      end
    end
    -- neo-tree may already have opened itself in place of the directory
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if vim.bo[api.nvim_win_get_buf(win)].filetype ~= "neo-tree" then api.nvim_set_current_win(win) break end
    end
    vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(dir))
    -- empty [No Name] tabs left over from the directory buffer (neo-tree creates them asynchronously)
    vim.defer_fn(function()
      for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if info.name == "" and #info.windows == 0 and info.changed == 0 then
          pcall(api.nvim_buf_delete, info.bufnr, {})
        end
      end
    end, 300)
    local welcome = require("config.welcome")
    welcome.remember(vim.fn.getcwd())
    welcome.show()
    local claude = require("claude")
    if claude.config.auto_open then claude.open(false) end
  end,
})

api.nvim_create_user_command("Shortcuts", function()
  vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath("config") .. "/README.md"))
end, { desc = "Keyboard shortcut cheat sheet" })
