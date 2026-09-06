return {
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
}
