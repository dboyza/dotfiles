-- Native Windows uses Neovim's provider; Unix consumers share one dispatcher.
if vim.fn.has("win32") == 1 then
  vim.opt.clipboard = "unnamedplus"
elseif vim.fn.executable("dotfiles-clipboard") == 1 then
  vim.fn.system({ "dotfiles-clipboard", "--check" })
  if vim.v.shell_error == 0 then
    vim.g.clipboard = {
      name = "Dotfiles clipboard",
      copy = { ["+"] = { "dotfiles-clipboard", "copy" }, ["*"] = { "dotfiles-clipboard", "copy" } },
      paste = { ["+"] = { "dotfiles-clipboard", "paste" }, ["*"] = { "dotfiles-clipboard", "paste" } },
      cache_enabled = 0,
    }
    vim.opt.clipboard = "unnamedplus"
  end
end
