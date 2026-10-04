-- Close file tabs into the rightmost remaining tab while preserving windows and unsaved edits.
local M = {}

function M.close(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
    return
  end

  local listed = vim.fn.getbufinfo({ buflisted = 1 })
  if #listed == 1 and listed[1].bufnr == buf then
    vim.cmd("confirm quitall")
    return
  end

  if vim.bo[buf].modified then
    local choice = vim.fn.confirm("Save changes to " .. vim.fn.bufname(buf) .. "?", "&Yes\n&No\n&Cancel")
    if choice == 0 or choice == 3 then
      return
    end
    if choice == 1 then
      vim.api.nvim_buf_call(buf, function() vim.cmd.write() end)
    end
  end

  -- Bufferline's public API retains the displayed order, including manual moves.
  local elements = require("bufferline").get_elements().elements
  local next_buf
  for index = #elements, 1, -1 do
    if elements[index].id ~= buf then
      next_buf = elements[index].id
      break
    end
  end
  if not next_buf then
    for _, info in ipairs(listed) do
      if info.bufnr ~= buf then
        next_buf = info.bufnr
      end
    end
  end

  -- Replace the buffer before deleting it so Neo-tree never becomes the last window.
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_set_buf(win, next_buf)
  end
  vim.api.nvim_buf_delete(buf, { force = true })
end

return M
