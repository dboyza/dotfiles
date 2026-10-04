-- Declare indentation, shortcut discovery, text objects, and editing helpers.
return {
  -- Section: Indent detection
  {
    "NMAC427/guess-indent.nvim",
    opts = {},
  },
  -- Section: Shortcut discovery
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
        { "<leader>g", group = "git" },
        { "<leader>h", group = "git hunk" },
        { "<leader>r", group = "rename" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "toggle" },
      },
    },
  },
  -- Section: Annotations and text-object helpers
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
      require("mini.pairs").setup()
      require("mini.surround").setup()
    end,
  },
}
