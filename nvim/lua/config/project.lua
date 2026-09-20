local M = {}
local format_disabled = {}

-- Keep project tools scoped to the file being edited, even when cwd is elsewhere.
function M.root(bufnr)
  local terminal = vim.b[bufnr or 0].snacks_terminal
  if terminal and terminal.cwd then
    return terminal.cwd
  end
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local path = name ~= "" and name or vim.fn.getcwd()
  return vim.fs.root(path, ".git")
    or vim.fs.root(path, { "pyproject.toml", "package.json", "setup.cfg", "pytest.ini" })
    or (name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd())
end

function M.format_on_save(bufnr)
  if vim.bo[bufnr].buftype ~= "" or format_disabled[M.root(bufnr)] then
    return
  end
  return { timeout_ms = 1500, lsp_format = "fallback" }
end

function M.toggle_format()
  local root = M.root()
  format_disabled[root] = not format_disabled[root]
  vim.notify((format_disabled[root] and "Disabled" or "Enabled") .. " format on save: " .. root)
end

return M
