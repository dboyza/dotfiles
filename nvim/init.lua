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
opt.winbar = " %f"
opt.statusline = " %f%=%y %l,%c %p%% "
opt.fillchars = { vert = "│", horiz = "─", horizup = "┴", horizdown = "┬", vertleft = "┤", vertright = "├", verthoriz = "┼" }

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
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }

local has_wsl_clipboard_helpers = vim.fn.executable("win-copy") == 1 and vim.fn.executable("win-paste") == 1

if vim.fn.has("wsl") == 1 and has_wsl_clipboard_helpers then
  vim.g.clipboard = {
    name = "Windows clipboard",
    copy = { ["+"] = "win-copy", ["*"] = "win-copy" },
    paste = { ["+"] = "win-paste", ["*"] = "win-paste" },
    cache_enabled = 0,
  }
  opt.clipboard = "unnamedplus"
elseif vim.fn.has("clipboard") == 1 then
  opt.clipboard = "unnamedplus"
end

local keymap = vim.keymap.set

keymap({ "n", "x" }, "<leader>y", [["+y]], { desc = "Copy to clipboard" })
keymap("n", "<leader>Y", [["+Y]], { desc = "Copy line to clipboard" })
keymap({ "n", "x" }, "<leader>p", [["+p]], { desc = "Paste from clipboard" })

local function move_word_back_in_line()
  vim.fn.search([[\<]], "bW", vim.fn.line("."))
end

local function move_word_forward_in_line()
  if vim.fn.search([[\<]], "W", vim.fn.line(".")) == 0 then
    local line = vim.api.nvim_get_current_line()
    vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), #line })
  end
end

keymap({ "n", "x", "i" }, "<C-Left>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x", "i" }, "<C-Right>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-Up>", "5<C-y>", { desc = "Scroll up 5 lines" })
keymap({ "n", "x" }, "<C-Down>", "5<C-e>", { desc = "Scroll down 5 lines" })
keymap("i", "<C-Up>", "<C-o>5<C-y>", { desc = "Scroll up 5 lines" })
keymap("i", "<C-Down>", "<C-o>5<C-e>", { desc = "Scroll down 5 lines" })

keymap("n", "<leader>x", "<cmd>wq<cr>", { desc = "Save and quit" })
keymap("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File explorer" })
keymap("n", "<leader>/", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
keymap("n", "<leader>[", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
keymap("n", "<leader>]", "<cmd>bnext<cr>", { desc = "Next buffer" })
keymap("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
keymap("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })
keymap("n", "<A-h>", "<C-w>h", { desc = "Move to left window" })
keymap("n", "<A-j>", "<C-w>j", { desc = "Move to lower window" })
keymap("n", "<A-k>", "<C-w>k", { desc = "Move to upper window" })
keymap("n", "<A-l>", "<C-w>l", { desc = "Move to right window" })

keymap({ "n", "x" }, "<C-h>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x" }, "<C-l>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-j>", "5j", { desc = "Move down 5 lines" })
keymap({ "n", "x" }, "<C-k>", "5k", { desc = "Move up 5 lines" })

keymap("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
keymap("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { result, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
      })
      vim.cmd.colorscheme("catppuccin")

      local set = vim.api.nvim_set_hl
      set(0, "Normal", { bg = "none" })
      set(0, "NormalNC", { bg = "none" })
      set(0, "NormalFloat", { bg = "none" })
      set(0, "SignColumn", { bg = "none" })
      set(0, "LineNr", { fg = "#6e6a86", bg = "none" })
      set(0, "CursorLine", { bg = "#312b44" })
      set(0, "CursorLineNr", { fg = "#e0def4", bg = "#3a3148", bold = true })
      set(0, "WinBar", { fg = "#908caa", bg = "#232136" })
      set(0, "WinBarNC", { fg = "#6e6a86", bg = "#232136" })
      set(0, "WinSeparator", { fg = "#f6c177", bg = "none" })
      set(0, "StatusLine", { fg = "#908caa", bg = "none" })
      set(0, "StatusLineNC", { fg = "#6e6a86", bg = "none" })
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    },
    opts = {},
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "markdown" },
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").setup({})

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
})
