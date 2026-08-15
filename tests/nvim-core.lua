local required_mappings = {
  { mode = "n", key = "<C-Left>" },
  { mode = "n", key = "<C-Right>" },
  { mode = "n", key = "<C-Up>" },
  { mode = "n", key = "<C-Down>" },
  { mode = "i", key = "<C-Left>" },
  { mode = "i", key = "<C-Right>" },
  { mode = "i", key = "<C-Up>" },
  { mode = "i", key = "<C-Down>" },
  { mode = "x", key = "<C-Left>" },
  { mode = "x", key = "<C-Right>" },
  { mode = "x", key = "<C-Up>" },
  { mode = "x", key = "<C-Down>" },
}

for _, mapping in ipairs(required_mappings) do
  local result = vim.fn.maparg(mapping.key, mapping.mode, false, true)
  assert(next(result) ~= nil, string.format("missing %s-mode mapping for %s", mapping.mode, mapping.key))
end

print("Neovim core Control+Arrow mappings passed")
