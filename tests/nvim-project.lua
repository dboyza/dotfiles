-- Check project-root selection and session-scoped formatting toggles.
local project = require("config.project")
local temp = vim.fn.tempname()
vim.fn.mkdir(temp .. "/project one/.git", "p")
vim.fn.mkdir(temp .. "/project one/src", "p")
vim.fn.mkdir(temp .. "/project two", "p")
temp = vim.uv.fs_realpath(temp)
local first = temp .. "/project one"
local second = temp .. "/project two"
vim.fn.writefile({ "{}" }, second .. "/package.json")

local function buffer(path)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, path)
  return buf
end

local a = buffer(first .. "/src/a.lua")
local b = buffer(first .. "/b.lua")
local c = buffer(second .. "/c.lua")
assert(project.root(a) == first, "nested file must use its repository root")
assert(project.root(c) == second, "non-Git project must use its package root")
assert(project.format_on_save(a), "formatting should default to enabled")
vim.api.nvim_set_current_buf(a)
project.toggle_format()
assert(not project.format_on_save(a) and not project.format_on_save(b), "toggle must apply across a project")
assert(project.format_on_save(c), "toggle must not affect a different project")
project.toggle_format()
assert(project.format_on_save(b), "toggle must reenable the project")
vim.bo[b].buftype = "nofile"
assert(not project.format_on_save(b), "special buffers must not autoformat")
vim.b[b].snacks_terminal = { cwd = first }
assert(project.root(b) == first, "terminal toggle must reuse its original project")

vim.fn.delete(temp, "rf")
print("Neovim project roots and format toggles passed")
