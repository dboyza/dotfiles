-- Tests must not read or change the user clipboard.
vim.opt.clipboard = ""

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
    assert(
      vim.api.nvim_get_current_line() == "eta gamma",
      "operator-pending Home must preserve native motion semantics"
    )
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

-- Exercise the same word motions with portable Control and direct Option events.
local function feed(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
end

-- Native commenting must keep both line and Visual-mode workflows available.
vim.bo.commentstring = "# %s"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("gcc")
assert(vim.api.nvim_get_current_line() == "# first", "gcc must comment the current line")
feed("gcc")
assert(vim.api.nvim_get_current_line() == "first", "gcc must uncomment the current line")
feed("Vjgc")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "# first", "# second" }))
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("gcj")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "first", "second" }))
print("Neovim native line, Visual, and motion commenting passed")

for _, modifier in ipairs({ "C", "A" }) do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha beta gamma" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  feed("<" .. modifier .. "-Right>")
  assert(vim.api.nvim_win_get_cursor(0)[2] == 6, "word motion must reach beta")
  feed("<" .. modifier .. "-Left>")
  assert(vim.api.nvim_win_get_cursor(0)[2] == 0, "word motion must return to alpha")
  feed("i<" .. modifier .. "-Right>X<Esc>")
  assert(
    vim.api.nvim_get_current_line() == "alpha Xbeta gamma",
    "insert-mode word motion must not resize or insert escapes"
  )
end
assert(vim.fn.maparg("<C-j>", "n") == vim.fn.maparg("<C-Down>", "n"))
assert(vim.fn.maparg("<C-k>", "n") == vim.fn.maparg("<C-Up>", "n"))
assert(vim.fn.maparg("<C-k>", "i") == "", "insert-mode signature help must remain available")

-- Mock only the external boundary: real window focus takes precedence over the
-- nearest enclosing Herdr pane, which in turn takes precedence over outer tmux.
local original_system, original_executable = vim.fn.system, vim.fn.executable
local calls = {}
vim.fn.system = function(command)
  calls[#calls + 1] = command
  return ""
end
vim.fn.executable = function()
  return 1
end
vim.env.HERDR_ENV, vim.env.HERDR_PANE_ID, vim.env.TMUX = "1", "pane-test", "tmux-test"
vim.cmd.vsplit()
vim.cmd.wincmd("h")
local left = vim.api.nvim_get_current_win()
feed("<A-l>")
assert(
  vim.api.nvim_get_current_win() ~= left and #calls == 0,
  "focus must stay inside Neovim when a neighboring window exists"
)
feed("<A-l>")
assert(vim.deep_equal(calls[1], { "herdr", "pane", "focus", "--direction", "right", "--pane", "pane-test" }))
vim.env.HERDR_ENV, vim.env.HERDR_PANE_ID = nil, nil
feed("<A-l>")
assert(vim.deep_equal(calls[2], { "tmux", "select-pane", "-R" }))
vim.env.TMUX = nil
feed("<A-l>")
assert(#calls == 2, "standalone Neovim must not invoke a multiplexer")
vim.fn.system, vim.fn.executable = original_system, original_executable
print("Neovim word motion, scroll aliases, and nested pane routing passed")
