return {
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
        "tree-sitter-cli",
        "typescript-language-server",
        "prettierd",
        "shfmt",
        "uv",
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
        python = { "ruff_format" },
        sh = { "shfmt" },
        typescript = { "prettierd", "prettier", stop_after_first = true },
      },
      formatters = {
        ruff_format = {
          command = "uvx",
          prepend_args = { "ruff" },
        },
      },
      notify_on_error = false,
    },
  },
}
