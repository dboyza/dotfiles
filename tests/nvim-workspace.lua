-- Check opt-in explorer behavior and preservation of unsaved edits during external refresh.
local workspace = require("config.workspace")
local calls = {}
package.loaded["neo-tree.command"] = { execute = function(options) calls[#calls + 1] = options end }
local navigation = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/nvim/lua/plugins/navigation.lua"
local function explorer()
  for _, spec in ipairs(dofile(navigation)) do
    if spec[1] == "nvim-neo-tree/neo-tree.nvim" then return spec end
  end
  error("Missing explorer")
end
local function opened(spec)
  for _, event in ipairs(spec.opts.event_handlers) do
    if event.event == "file_opened" then event.handler() end
  end
end

-- Section: Ordinary sessions retain their explorer lifecycle
assert(not workspace.enabled() and workspace.position() == "left")
opened(explorer())
assert(calls[1].action == "close")

-- Section: Dedicated sessions keep the right-hand explorer
vim.g.dotfiles_workspace = 1
local spec = explorer()
assert(spec.opts.window.position == "right")
assert(spec.opts.close_if_last_window, "quitting the final editor must still exit")
opened(spec)
assert(#calls == 1, "opening a file must leave the workspace tree open")
spec.keys[1][2]()
assert(calls[2].position == "right" and calls[2].action == "focus")

-- Section: External writes refresh only unmodified buffers
local path = vim.fn.tempname()
vim.fn.writefile({ "original" }, path)
vim.cmd.edit(vim.fn.fnameescape(path))
vim.opt.autoread = true
vim.fn.writefile({ "agent changed this file" }, path)
workspace.refresh()
assert(vim.api.nvim_get_current_line() == "agent changed this file")
vim.api.nvim_set_current_line("unsaved user change")
vim.fn.writefile({ "another agent change on disk" }, path)
workspace.refresh()
assert(vim.api.nvim_get_current_line() == "unsaved user change" and vim.bo.modified)
vim.bo.modified = false
vim.fn.delete(path)
print("Workspace explorer and safe external refresh passed")
