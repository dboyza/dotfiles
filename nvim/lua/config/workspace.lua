-- Scope the persistent explorer and external-file refresh to dedicated agent workspaces.
local M = {}

-- Section: Explorer profile
function M.enabled()
  return vim.g.dotfiles_workspace == 1
end

function M.position()
  return M.enabled() and "right" or "left"
end

-- Section: Safe refresh of agent-written files
function M.refresh()
  if vim.api.nvim_get_mode().mode ~= "n" or vim.fn.getcmdtype() ~= "" then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
      vim.cmd("silent! checktime " .. buf)
    end
  end
end

function M.setup()
  if not M.enabled() then
    return
  end
  vim.opt.autoread = true
  local group = vim.api.nvim_create_augroup("dotfiles_workspace", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function() vim.cmd("Neotree show right") end,
  })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { group = group, callback = M.refresh })
  local timer = assert(vim.uv.new_timer())
  local refresh_interval_ms = 1500
  timer:start(refresh_interval_ms, refresh_interval_ms, vim.schedule_wrap(M.refresh))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function() timer:stop(); timer:close() end,
  })
end

return M
