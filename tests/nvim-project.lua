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

-- Validate argv boundaries independently of OS executable shim conventions.
local adapters = require("config.test-adapters")
vim.fn.mkdir(first .. "/node_modules/vitest", "p")
vim.fn.writefile({ "" }, first .. "/node_modules/vitest/vitest.mjs")
local adapter = adapters.node({
  root = function()
    return first
  end,
  is_test_file = function()
    return true
  end,
  build_spec = function()
    return {
      command = { "node", "--watch=false", first .. "/a.test.js" },
      strategy = { args = { "--watch=false", first .. "/a.test.js" } },
    }
  end,
}, "vitest/vitest.mjs")
local path = first .. "/src/a.test.js"
local spec = adapter.build_spec({ tree = {
  data = function()
    return { path = path }
  end,
}, strategy = "dap" })
assert(spec.command[2] == first .. "/node_modules/vitest/vitest.mjs", "Node entry path must stay one argument")
assert(spec.command[3] == "--watch=false", "runner flags must be preserved")
assert(spec.strategy.args[1] == spec.command[2], "debugging must use the same Node entry point")
assert(
  not adapter.root(second) and not adapter.is_test_file(second .. "/a.test.js"),
  "runner must ignore unrelated projects"
)

vim.fn.delete(temp, "rf")
print("Neovim project roots, format toggles, and portable test commands passed")
