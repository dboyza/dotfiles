return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
      "mfussenegger/nvim-dap",
    },
    keys = {
      {
        "<leader>Tn",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>Tf",
        function()
          require("neotest").run.run(vim.fn.expand("%:p"))
        end,
        desc = "Run test file",
      },
      {
        "<leader>Ta",
        function()
          require("neotest").run.run(require("config.project").root())
        end,
        desc = "Run project tests",
      },
      {
        "<leader>Tl",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Run last test",
      },
      {
        "<leader>Td",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Debug nearest test",
      },
      {
        "<leader>Ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Toggle test summary",
      },
      {
        "<leader>To",
        function()
          require("neotest").output.open({ enter = true, auto_close = true })
        end,
        desc = "Test output",
      },
      {
        "<leader>TO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle test output panel",
      },
      {
        "<leader>Tq",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop test",
      },
    },
    opts = function()
      local adapters = require("config.test-adapters")
      return {
        adapters = {
          require("neotest-python")({ runner = "pytest" }),
          adapters.node(
            require("neotest-vitest")({ vitestCommand = "node", cwd = adapters.cwd }),
            "vitest/vitest.mjs",
            {
              "--no-file-parallelism",
              "--test-timeout=0",
            }
          ),
          adapters.node(
            require("neotest-jest")({
              jestCommand = "node",
              cwd = adapters.cwd,
              strategy_config = function(config)
                config.type = "pwa-node"
                return config
              end,
            }),
            "jest/bin/jest.js",
            { "--runInBand", "--testTimeout=2147483647" }
          ),
        },
        summary = { open = "botright vsplit | vertical resize 40" },
        output = { open_on_run = false },
        quickfix = { open = false },
      }
    end,
  },
}
