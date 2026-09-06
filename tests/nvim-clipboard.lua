local module = arg[1]
dofile(module)
assert(vim.g.clipboard.name == "Dotfiles clipboard", "Shared provider was not installed")
vim.fn.setreg("+", { "héllo 🌙", "second line" }, "V")
assert(vim.deep_equal(vim.fn.getreg("+", 1, true), { "héllo 🌙", "second line" }), "Clipboard text changed")
assert(vim.fn.getregtype("+") == "V", "Linewise clipboard register type changed")

-- Native Windows leaves provider selection to Neovim.
local original_has = vim.fn.has
vim.fn.has = function(feature)
  return feature == "win32" and 1 or original_has(feature)
end
vim.g.clipboard = nil
dofile(module)
assert(vim.g.clipboard == nil, "Native Windows provider was overridden")
assert(vim.opt.clipboard:get()[1] == "unnamedplus")
vim.fn.has = original_has
