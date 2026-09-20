return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      {
        "<leader>rc",
        function()
          require("dap").continue()
        end,
        desc = "Start or continue debugging",
      },
      {
        "<leader>rb",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle breakpoint",
      },
      {
        "<leader>rB",
        function()
          vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
            if condition and condition ~= "" then
              require("dap").set_breakpoint(condition)
            end
          end)
        end,
        desc = "Conditional breakpoint",
      },
      {
        "<leader>ro",
        function()
          require("dap").step_over()
        end,
        desc = "Step over",
      },
      {
        "<leader>ri",
        function()
          require("dap").step_into()
        end,
        desc = "Step into",
      },
      {
        "<leader>rO",
        function()
          require("dap").step_out()
        end,
        desc = "Step out",
      },
      {
        "<leader>rq",
        function()
          require("dap").terminate()
        end,
        desc = "Stop debugging",
      },
      {
        "<leader>rl",
        function()
          require("dap").run_last()
        end,
        desc = "Run last debug configuration",
      },
      {
        "<leader>ru",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle debugger panels",
      },
      {
        "<leader>re",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "x" },
        desc = "Evaluate expression",
      },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.5 },
              { id = "breakpoints", size = 0.2 },
              { id = "stacks", size = 0.2 },
              { id = "watches", size = 0.1 },
            },
            size = 0.25,
            position = "right",
          },
          { elements = { "repl", "console" }, size = 0.25, position = "bottom" },
        },
        floating = { border = "rounded" },
      })
      dap.listeners.after.event_initialized.dotfiles = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dotfiles = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dotfiles = function()
        dapui.close()
      end
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "CursorLine" })

      local mason = vim.fn.stdpath("data") .. "/mason/packages/"
      local python = mason .. "debugpy/venv/" .. (vim.fn.has("win32") == 1 and "Scripts/python.exe" or "bin/python")
      require("dap-python").setup(python)
      for _, config in ipairs(dap.configurations.python) do
        config.cwd = function()
          return require("config.project").root()
        end
      end

      dap.adapters["pwa-node"] = {
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = {
          command = "node",
          args = { mason .. "js-debug-adapter/js-debug/src/dapDebugServer.js", "${port}", "127.0.0.1" },
        },
      }
      dap.adapters.node = dap.adapters["pwa-node"]
      for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
        dap.configurations[ft] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Node: launch current file",
            program = "${file}",
            cwd = function()
              return require("config.project").root()
            end,
            sourceMaps = true,
            console = "integratedTerminal",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Node: attach to process",
            processId = require("dap.utils").pick_process,
            cwd = function()
              return require("config.project").root()
            end,
            sourceMaps = true,
          },
        }
      end
    end,
  },
}
