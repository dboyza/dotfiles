-- Coordinate terminal tools, colors, buffer tabs, and the status line.
local P = require("config.palette")

return {
  -- Section: Terminal tools and indent guides
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    keys = {
      {
        "<C-/>",
        function()
          Snacks.terminal.toggle(nil, { cwd = require("config.project").root() })
        end,
        mode = { "n", "t" },
        desc = "Toggle project terminal",
      },
      {
        "<C-_>",
        function()
          Snacks.terminal.toggle(nil, { cwd = require("config.project").root() })
        end,
        mode = { "n", "t" },
        desc = "Toggle project terminal (legacy encoding)",
      },
      {
        "<leader>ft",
        function()
          Snacks.terminal.toggle(nil, { cwd = require("config.project").root() })
        end,
        desc = "Toggle project terminal",
      },
      {
        "<leader>cR",
        function()
          if vim.bo.modified then
            vim.cmd.write()
          end
          Snacks.rename.rename_file()
        end,
        desc = "Rename file and update imports",
      },
    },
    opts = {
      input = { enabled = true },
      terminal = { win = { position = "bottom", height = 0.3, border = "rounded" } },
      indent = {
        enabled = true,
        animate = { enabled = false },
        indent = { char = "│" },
        scope = { char = "│" },
      },
    },
  },
  -- Section: Theme and highlight overrides
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
        integrations = {
          grug_far = true,
          lsp_trouble = true,
          neogit = true,
          snacks = { enabled = true },
        },
      })
      vim.cmd.colorscheme("catppuccin")

      local set = vim.api.nvim_set_hl
      set(0, "SnacksIndent", { fg = P.highlight })
      set(0, "SnacksIndentScope", { fg = P.iris })
      set(0, "Normal", { bg = "none" })
      set(0, "NormalNC", { bg = "none" })
      set(0, "NormalFloat", { bg = "none" })
      set(0, "SignColumn", { bg = "none" })
      set(0, "LineNr", { fg = P.muted, bg = "none" })
      set(0, "CursorLine", { bg = P.cursorline })
      set(0, "CursorLineNr", { fg = P.text, bg = P.cursorline_nr, bold = true })
      set(0, "WinBar", { fg = P.subtle, bg = P.base })
      set(0, "WinBarNC", { fg = P.muted, bg = P.base })
      set(0, "WinSeparator", { fg = P.gold, bg = "none" })
      set(0, "StatusLine", { fg = P.subtle, bg = "none" })
      set(0, "StatusLineNC", { fg = P.muted, bg = "none" })
    end,
  },
  -- Section: Icons and buffer tabs
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
        background = { fg = P.muted, bg = P.base },
        buffer_selected = { fg = P.text, bg = P.overlay, bold = true, italic = false },
        close_button = { fg = P.muted, bg = P.base },
        close_button_selected = { fg = P.love, bg = P.overlay },
        fill = { bg = P.deep },
        indicator_selected = { fg = P.iris, bg = P.overlay },
        modified = { fg = P.gold, bg = P.base },
        modified_selected = { fg = P.gold, bg = P.overlay },
        separator = { fg = P.deep, bg = P.base },
        separator_selected = { fg = P.deep, bg = P.overlay },
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
  -- Section: Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      local rose_pine = {
        normal = {
          a = { fg = P.deep, bg = P.foam, gui = "bold" },
          b = { fg = P.text, bg = P.overlay },
          c = { fg = P.subtle, bg = "none" },
        },
        insert = { a = { fg = P.deep, bg = P.iris, gui = "bold" } },
        visual = { a = { fg = P.deep, bg = P.gold, gui = "bold" } },
        replace = { a = { fg = P.deep, bg = P.love, gui = "bold" } },
        command = { a = { fg = P.deep, bg = P.blush, gui = "bold" } },
        inactive = {
          a = { fg = P.muted, bg = "none" },
          b = { fg = P.muted, bg = "none" },
          c = { fg = P.muted, bg = "none" },
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
