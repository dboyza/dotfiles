return {
  {
    "NMAC427/guess-indent.nvim",
    opts = {},
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
      require("mini.pairs").setup()
      require("mini.surround").setup()
    end,
  },
}
