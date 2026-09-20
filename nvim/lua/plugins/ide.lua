return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>dp", "<cmd>Trouble diagnostics toggle<cr>", desc = "Project problems" },
      { "<leader>db", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer problems" },
      { "<leader>cs", "<cmd>Trouble symbols toggle win.position=right<cr>", desc = "Code outline" },
      { "<leader>cl", "<cmd>Trouble lsp toggle<cr>", desc = "Definitions and references" },
      { "<leader>dq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix panel" },
    },
  },
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { headerMaxWidth = 80 },
    keys = {
      {
        "<leader>sr",
        function()
          local root = require("config.project").root():gsub(" ", "\\ ")
          require("grug-far").open({ prefills = { paths = root } })
        end,
        desc = "Search and replace in project",
      },
    },
  },
}
