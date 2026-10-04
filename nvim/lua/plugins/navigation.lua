-- Configure accelerated motion, the file explorer, and fuzzy finding.
return {
  -- Section: Held-key acceleration
  {
    "rhysd/accelerated-jk",
    init = function()
      vim.g.accelerated_jk_acceleration_limit = 150
      -- Stay at one line for 40 repeats, then build speed gradually.
      -- The limit above resets the streak after a pause; it is not the onset delay.
      vim.g.accelerated_jk_acceleration_table = { 40, 48, 56, 64, 72, 80, 88, 96 }
    end,
    keys = {
      { "j", "<Plug>(accelerated_jk_j)", desc = "Accelerated down", remap = true },
      { "k", "<Plug>(accelerated_jk_k)", desc = "Accelerated up", remap = true },
      { "<Down>", "<Plug>(accelerated_jk_j)", desc = "Accelerated down", remap = true },
      { "<Up>", "<Plug>(accelerated_jk_k)", desc = "Accelerated up", remap = true },
    },
  },
  -- Section: Explorer lifecycle and focus
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
        function()
          if vim.bo.filetype ~= "neo-tree" then
            vim.t.explorer_return_win = vim.api.nvim_get_current_win()
            require("neo-tree.command").execute({
              action = "focus",
              source = "filesystem",
              position = require("config.workspace").position(),
            })
            return
          end

          local function is_editor(win)
            return win and vim.api.nvim_win_is_valid(win)
              and vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()
              and vim.api.nvim_win_get_config(win).relative == ""
              and vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
          end

          local target = vim.t.explorer_return_win
          if not is_editor(target) then
            target = nil
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              if is_editor(win) then
                target = win
                break
              end
            end
          end
          if target then
            vim.api.nvim_set_current_win(target)
          end
        end,
        desc = "Switch between explorer and editor",
      },
    },
    opts = {
      close_if_last_window = true,
      event_handlers = {
        {
          event = "file_moved",
          handler = function(data) Snacks.rename.on_rename_file(data.source, data.destination) end,
        },
        {
          event = "file_renamed",
          handler = function(data) Snacks.rename.on_rename_file(data.source, data.destination) end,
        },
        {
          event = "file_opened",
          handler = function()
            if not require("config.workspace").enabled() then
              require("neo-tree.command").execute({ action = "close" })
            end
          end,
        },
      },
      enable_diagnostics = true,
      enable_git_status = true,
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "disabled",
      },
      window = {
        position = require("config.workspace").position(),
        width = 34,
      },
    },
  },
  -- Section: File and text search
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
