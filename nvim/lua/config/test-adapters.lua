local M = {}

-- Invoke JavaScript entry points directly: .bin shims differ on Windows, and
-- upstream command-string splitting breaks executable paths containing spaces.
function M.node(adapter, entry, debug_args)
  local function package_root(path)
    local stat = vim.uv.fs_stat(path)
    local dir = stat and stat.type == "directory" and path or vim.fs.dirname(path)
    while dir do
      if vim.uv.fs_stat(dir .. "/node_modules/" .. entry) then
        return dir
      end
      local parent = vim.fs.dirname(dir)
      if parent == dir then
        break
      end
      dir = parent
    end
  end
  local adapter_root = adapter.root
  adapter.root = function(path)
    if package_root(path) then
      return adapter_root(path)
    end
  end
  local is_test_file = adapter.is_test_file
  adapter.is_test_file = function(path)
    -- Avoid probing unrelated runners (including their cwd-based fallbacks).
    return path ~= nil and package_root(path) ~= nil and is_test_file(path)
  end
  local build_spec = adapter.build_spec
  adapter.build_spec = function(args)
    local path = args.tree:data().path
    local root = package_root(path)
    assert(root, "Install this project's test dependencies before running tests")
    local script = root .. "/node_modules/" .. entry
    local spec = build_spec(args)
    if not spec then
      return
    end
    table.insert(spec.command, 2, script)
    if args.strategy == "dap" then
      table.insert(spec.strategy.args, 1, script)
      vim.list_extend(spec.strategy.args, debug_args or {})
      spec.strategy.console = "internalConsole"
    end
    return spec
  end
  return adapter
end

function M.cwd(path)
  return vim.fs.root(path, "package.json") or vim.uv.cwd()
end

return M
