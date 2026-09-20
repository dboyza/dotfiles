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

if vim.fn.has("macunix") == 1 then
  local function keys(sequence)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
  end
  local function reset()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta gamma" })
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
  end
  for _, pair in ipairs({ { "<D-Left>", "<D-Right>" }, { "<D-h>", "<D-l>" } }) do
    local home, finish = pair[1], pair[2]
    reset()
    keys(home)
    assert(vim.api.nvim_win_get_cursor(0)[2] == 0, home .. " must reach the first column")
    keys(finish)
    assert(vim.api.nvim_win_get_cursor(0)[2] == 15, finish .. " must reach the last character")
    reset()
    keys("i" .. home .. "X<Esc>")
    assert(vim.api.nvim_get_current_line() == "Xalpha beta gamma", "insert-mode Home must insert at line start")
    reset()
    keys("i" .. finish .. "X<Esc>")
    assert(vim.api.nvim_get_current_line() == "alpha beta gammaX", "insert-mode End must insert at line end")
    reset()
    keys("v" .. home .. "y")
    assert(vim.fn.getreg('"') == "alpha be", "visual-mode Home must extend selection to line start")
    reset()
    keys("v" .. finish .. "y")
    assert(vim.fn.getreg('"') == "eta gamma", "visual-mode End must extend selection to line end")
    reset()
    keys("d" .. home)
    assert(vim.api.nvim_get_current_line() == "eta gamma", "operator-pending Home must preserve native motion semantics")
  end
  local function reset_file()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "middle", "last" })
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
  end
  reset_file()
  keys("<D-Up>")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "Command+Up must reach the first line")
  keys("<D-Down>")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "Command+Down must reach the last line")
  reset_file()
  keys("i<D-Up>X<Esc>")
  assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "Xfirst", "insert-mode Command+Up must reach file start")
  reset_file()
  keys("i<D-Down>X<Esc>")
  assert(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == "lastX", "insert-mode Command+Down must reach file end")
  reset_file()
  keys("V<D-Up>y")
  assert(vim.fn.getreg('"') == "first\nmiddle\n", "visual-mode Command+Up must extend selection to file start")
  reset_file()
  keys("V<D-Down>y")
  assert(vim.fn.getreg('"') == "middle\nlast\n", "visual-mode Command+Down must extend selection to file end")
  print("Neovim macOS Command+Arrow navigation passed")
end
