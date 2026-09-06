return {
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
      local treesitter = require("nvim-treesitter")
      treesitter.setup({})
      local parsers = {
        "bash",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "typescript",
      }
      local function install_parsers()
        local has_compiler = vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1 or vim.fn.executable("clang") == 1
        if vim.fn.executable("tree-sitter") == 1 and has_compiler then
          treesitter.install(parsers)
        end
      end

      install_parsers()
      vim.api.nvim_create_autocmd("User", {
        pattern = "MasonToolsUpdateCompleted",
        callback = install_parsers,
      })

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          if vim.treesitter and vim.treesitter.start then
            pcall(vim.treesitter.start)
          end
        end,
      })
    end,
  },
}
