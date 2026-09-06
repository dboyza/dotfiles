return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Neotree",
    keys = {
      {
        "<leader>e",
        "<cmd>Neotree toggle reveal filesystem left<cr>",
        desc = "File explorer",
      },
    },
    opts = {
      close_if_last_window = true,
      enable_diagnostics = true,
      enable_git_status = true,
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "open_current",
      },
      window = {
        position = "left",
        width = 34,
      },
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
          return vim.fn.executable("make") == 1 and vim.fn.executable("cc") == 1
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
}
