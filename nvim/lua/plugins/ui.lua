return {
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
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    keys = {
      { "<leader><", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer left" },
      { "<leader>>", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer right" },
      { "<leader>bp", "<cmd>BufferLinePick<cr>", desc = "Pick buffer" },
    },
    opts = {
      highlights = {
        background = { fg = "#6e6a86", bg = "#232136" },
        buffer_selected = { fg = "#e0def4", bg = "#393552", bold = true, italic = false },
        close_button = { fg = "#6e6a86", bg = "#232136" },
        close_button_selected = { fg = "#eb6f92", bg = "#393552" },
        fill = { bg = "#191724" },
        indicator_selected = { fg = "#c4a7e7", bg = "#393552" },
        modified = { fg = "#f6c177", bg = "#232136" },
        modified_selected = { fg = "#f6c177", bg = "#393552" },
        separator = { fg = "#191724", bg = "#232136" },
        separator_selected = { fg = "#191724", bg = "#393552" },
      },
      options = {
        always_show_bufferline = true,
        diagnostics = "nvim_lsp",
        indicator = { icon = "▎", style = "icon" },
        offsets = {
          {
            filetype = "neo-tree",
            text = function()
              return " " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
            end,
            text_align = "left",
            separator = true,
          },
        },
        separator_style = "thin",
        show_buffer_close_icons = true,
        show_close_icon = false,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      local rose_pine = {
        normal = {
          a = { fg = "#191724", bg = "#9ccfd8", gui = "bold" },
          b = { fg = "#e0def4", bg = "#393552" },
          c = { fg = "#908caa", bg = "none" },
        },
        insert = { a = { fg = "#191724", bg = "#c4a7e7", gui = "bold" } },
        visual = { a = { fg = "#191724", bg = "#f6c177", gui = "bold" } },
        replace = { a = { fg = "#191724", bg = "#eb6f92", gui = "bold" } },
        command = { a = { fg = "#191724", bg = "#ebbcba", gui = "bold" } },
        inactive = {
          a = { fg = "#6e6a86", bg = "none" },
          b = { fg = "#6e6a86", bg = "none" },
          c = { fg = "#6e6a86", bg = "none" },
        },
      }

      require("lualine").setup({
        options = {
          component_separators = "",
          globalstatus = false,
          section_separators = "",
          theme = rose_pine,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "diagnostics", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        extensions = { "lazy", "neo-tree" },
      })
    end,
  },
}
