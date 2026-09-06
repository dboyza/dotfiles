vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.cursorlineopt = "number,line"
opt.wrap = false
opt.showmode = false
opt.numberwidth = 4
opt.laststatus = 2
opt.fillchars = { vert = "│", horiz = "─", horizup = "┴", horizdown = "┬", vertleft = "┤", vertright = "├", verthoriz = "┼" }
opt.mouse = "a"
opt.confirm = true
opt.pumheight = 12
opt.virtualedit = "block"
opt.inccommand = "split"
opt.breakindent = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

opt.undofile = true
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 16
opt.sidescrolloff = 8
opt.updatetime = 200
opt.timeoutlen = 300
opt.completeopt = { "menu", "menuone", "noselect" }
opt.shortmess:append("WIcC")
pcall(function()
  opt.splitkeep = "screen"
end)
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"

vim.diagnostic.config({
  float = { border = "rounded", source = "if_many" },
  severity_sort = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  virtual_text = { prefix = "●", spacing = 2 },
})
