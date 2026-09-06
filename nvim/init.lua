pcall(function()
  vim.loader.enable()
end)

-- Support both the managed configuration and an explicit nvim -u checkout/init.lua.
local config_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.rtp:prepend(config_dir)

require("config.options")
require("config.clipboard")
require("config.keymaps")
require("config.autocmds")

if vim.env.DOTFILES_NVIM_CORE_ONLY ~= "1" then
  require("config.lazy")
end
