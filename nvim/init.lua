pcall(function()
  vim.loader.enable()
end)

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

local function executable(command)
  return vim.fn.executable(command) == 1
end

local function use_clipboard(name, copy, paste)
  vim.g.clipboard = {
    name = name,
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
    cache_enabled = 0,
  }
  opt.clipboard = "unnamedplus"
end

if vim.fn.has("wsl") == 1 and executable("win-copy") and executable("win-paste") then
  use_clipboard("Windows clipboard", "win-copy", "win-paste")
elseif vim.fn.has("wsl") == 1 and executable("win32yank.exe") then
  use_clipboard("Windows clipboard", "win32yank.exe -i --crlf", "win32yank.exe -o --lf")
elseif vim.fn.has("mac") == 1 and executable("pbcopy") and executable("pbpaste") then
  use_clipboard("macOS clipboard", "pbcopy", "pbpaste")
elseif executable("wl-copy") and executable("wl-paste") then
  use_clipboard("Wayland clipboard", "wl-copy", "wl-paste --no-newline")
elseif executable("xclip") then
  use_clipboard("X11 clipboard", "xclip -selection clipboard", "xclip -selection clipboard -out")
elseif executable("xsel") then
  use_clipboard("X11 clipboard", "xsel --clipboard --input", "xsel --clipboard --output")
elseif vim.fn.has("clipboard") == 1 or vim.fn.has("win32") == 1 then
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

local function move_window_or_tmux(direction)
  local tmux_direction = ({ h = "L", j = "D", k = "U", l = "R" })[direction]
  local current_window = vim.api.nvim_get_current_win()

  vim.cmd.wincmd(direction)

  if vim.api.nvim_get_current_win() ~= current_window then
    return
  end

  if vim.env.TMUX and tmux_direction and vim.fn.executable("tmux") == 1 then
    vim.fn.system({ "tmux", "select-pane", "-" .. tmux_direction })
  end
end

keymap({ "n", "x", "i" }, "<C-Left>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x", "i" }, "<C-Right>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-Up>", "5<C-y>", { desc = "Scroll up 5 lines" })
keymap({ "n", "x" }, "<C-Down>", "5<C-e>", { desc = "Scroll down 5 lines" })
keymap("i", "<C-Up>", "<C-o>5<C-y>", { desc = "Scroll up 5 lines" })
keymap("i", "<C-Down>", "<C-o>5<C-e>", { desc = "Scroll down 5 lines" })

keymap("n", "<leader>x", "<cmd>wq<cr>", { desc = "Save and quit" })
keymap("n", "<leader>e", function()
  local path = vim.api.nvim_buf_get_name(0)
  require("mini.files").open(path ~= "" and path or vim.fn.getcwd(), false)
end, { desc = "File explorer" })
keymap("n", "<leader>[", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
keymap("n", "<leader>]", "<cmd>bnext<cr>", { desc = "Next buffer" })
keymap("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
keymap("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
keymap("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })
keymap("n", "<A-h>", function()
  move_window_or_tmux("h")
end, { desc = "Move to left window or tmux pane" })
keymap("n", "<A-j>", function()
  move_window_or_tmux("j")
end, { desc = "Move to lower window or tmux pane" })
keymap("n", "<A-k>", function()
  move_window_or_tmux("k")
end, { desc = "Move to upper window or tmux pane" })
keymap("n", "<A-l>", function()
  move_window_or_tmux("l")
end, { desc = "Move to right window or tmux pane" })

keymap({ "n", "x" }, "<C-h>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x" }, "<C-l>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-j>", "5j", { desc = "Move down 5 lines" })
keymap({ "n", "x" }, "<C-k>", "5k", { desc = "Move up 5 lines" })
keymap("x", "J", ":move '>+1<cr>gv=gv", { desc = "Move selection down" })
keymap("x", "K", ":move '<-2<cr>gv=gv", { desc = "Move selection up" })

keymap("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
keymap("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
keymap("n", "<A-Up>", "<cmd>resize +2<cr>", { desc = "Make window taller" })
keymap("n", "<A-Down>", "<cmd>resize -2<cr>", { desc = "Make window shorter" })
keymap("n", "<A-Left>", "<cmd>vertical resize -4<cr>", { desc = "Make window narrower" })
keymap("n", "<A-Right>", "<cmd>vertical resize +4<cr>", { desc = "Make window wider" })
keymap("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
keymap("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
keymap("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
keymap("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Line diagnostic" })
keymap("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostic list" })
keymap("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
keymap("n", "[q", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })

local group = vim.api.nvim_create_augroup("user_config", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)

    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(event)
    local dir = vim.fn.fnamemodify(event.match, ":p:h")

    if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  command = "wincmd =",
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(event)
    local map = function(keys, rhs, desc, mode)
      vim.keymap.set(mode or "n", keys, rhs, { buffer = event.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "References")
    map("gI", vim.lsp.buf.implementation, "Go to implementation")
    map("<leader>D", vim.lsp.buf.type_definition, "Type definition")
    map("<leader>rn", vim.lsp.buf.rename, "Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "x" })
    map("K", vim.lsp.buf.hover, "Hover")

    local client = vim.lsp.get_client_by_id(event.data.client_id)

    if client and client:supports_method("textDocument/documentHighlight", event.buf) then
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = group,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = group,
        callback = vim.lsp.buf.clear_references,
      })
    end

    if client and client:supports_method("textDocument/inlayHint", event.buf) and vim.lsp.inlay_hint then
      map("<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }), { bufnr = event.buf })
      end, "Toggle inlay hints")
    end
  end,
})

local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not uv.fs_stat(lazypath) then
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
    "NMAC427/guess-indent.nvim",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gitsigns = require("gitsigns")
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("n", "]h", function()
          gitsigns.nav_hunk("next")
        end, "Next git hunk")
        map("n", "[h", function()
          gitsigns.nav_hunk("prev")
        end, "Previous git hunk")
        map("n", "<leader>hp", gitsigns.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", function()
          gitsigns.blame_line({ full = true })
        end, "Blame line")
        map("n", "<leader>hr", gitsigns.reset_hunk, "Reset hunk")
        map("n", "<leader>hs", gitsigns.stage_hunk, "Stage hunk")
        map({ "o", "x" }, "ih", gitsigns.select_hunk, "Git hunk")
      end,
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 0,
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "diagnostic" },
        { "<leader>f", group = "find" },
        { "<leader>h", group = "git hunk" },
        { "<leader>t", group = "toggle" },
      },
    },
  },
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = { signs = false },
  },
  {
    "nvim-mini/mini.nvim",
    version = false,
    config = function()
      require("mini.ai").setup({
        mappings = { around_next = "aa", inside_next = "ii" },
        n_lines = 500,
      })
      require("mini.comment").setup()
      require("mini.files").setup()
      require("mini.pairs").setup()
      require("mini.surround").setup()
    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { { "L3MON4D3/LuaSnip", version = "v2.*" } },
    opts = {
      keymap = { preset = "super-tab" },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },
      fuzzy = { implementation = "lua" },
      signature = { enabled = true },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "saghen/blink.cmp",
      { "j-hui/fidget.nvim", opts = {} },
    },
    config = function()
      local mason_path = vim.fn.stdpath("data") .. "/mason"
      local servers = {
        bashls = {
          cmd = { "node", mason_path .. "/packages/bash-language-server/node_modules/bash-language-server/out/cli.js", "start" },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = "Replace" },
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
            },
          },
        },
        pyright = {
          cmd = { "node", mason_path .. "/packages/pyright/node_modules/pyright/langserver.index.js", "--stdio" },
          root_dir = function(bufnr, on_dir)
            local path = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(path, {
              "pyrightconfig.json",
              "pyproject.toml",
              "setup.py",
              "setup.cfg",
              "requirements.txt",
              "Pipfile",
              ".git",
            })

            on_dir(root or vim.fs.dirname(path))
          end,
        },
        ts_ls = {
          cmd = { "node", mason_path .. "/packages/typescript-language-server/node_modules/typescript-language-server/lib/cli.mjs", "--stdio" },
        },
      }
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local ensure_installed = {
        "bash-language-server",
        "lua-language-server",
        "pyright",
        "stylua",
        "typescript-language-server",
        "prettierd",
        "shfmt",
      }

      for server, config in pairs(servers) do
        config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
        vim.lsp.config(server, config)
      end

      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_enable = true,
      })
      require("mason-tool-installer").setup({
        ensure_installed = ensure_installed,
        start_delay = 3000,
        debounce_hours = 24,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "x" },
        desc = "Format buffer",
      },
    },
    opts = {
      default_format_opts = { lsp_format = "fallback" },
      formatters_by_ft = {
        javascript = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        lua = { "stylua" },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        python = { "ruff_format", "black", stop_after_first = true },
        sh = { "shfmt" },
        typescript = { "prettierd", "prettier", stop_after_first = true },
      },
      notify_on_error = false,
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return executable("make") and executable("cc")
        end,
      },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fc", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>fn", function()
        require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config"), follow = true })
      end, desc = "Neovim files" },
      { "<leader>/", function()
        require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
          previewer = false,
          winblend = 10,
        }))
      end, desc = "Find in buffer" },
    },
    config = function()
      local actions = require("telescope.actions")

      require("telescope").setup({
        defaults = {
          layout_config = {
            height = 0.85,
            horizontal = { preview_width = 0.55 },
            width = 0.9,
          },
          mappings = {
            i = { ["<esc>"] = actions.close },
          },
          prompt_prefix = "> ",
          selection_caret = "> ",
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
        },
      })

      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "ui-select")
    end,
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
          if vim.treesitter and vim.treesitter.start then
            pcall(vim.treesitter.start)
          end
        end,
      })
    end,
  },
})
