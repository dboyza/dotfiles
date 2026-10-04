-- Route editing, clipboard, and pane navigation across terminal layers.
local keymap = vim.keymap.set

-- Section: Direct macOS Command events

-- Enhanced terminal input can deliver Command directly instead of WezTerm's
-- translated Home/End events. Give both paths the same native Vim behavior.
if vim.fn.has("macunix") == 1 then
  local modes = { "n", "x", "s", "o", "i", "c", "t" }
  keymap(modes, "<D-Left>", "<Home>", { desc = "Move to beginning of line" })
  keymap(modes, "<D-Right>", "<End>", { desc = "Move to end of line" })
  keymap(modes, "<D-h>", "<Home>", { desc = "Move to beginning of line" })
  keymap(modes, "<D-l>", "<End>", { desc = "Move to end of line" })
  local file_modes = { "n", "x", "s", "o", "i" }
  keymap(file_modes, "<D-Up>", "<C-Home>", { desc = "Move to beginning of file" })
  keymap(file_modes, "<D-Down>", "<C-End>", { desc = "Move to end of file" })
end

-- Section: Clipboard aliases
keymap({ "n", "x" }, "<leader>y", [["+y]], { desc = "Copy to clipboard" })
keymap("n", "<leader>Y", [["+Y]], { desc = "Copy line to clipboard" })
keymap({ "n", "x" }, "<leader>p", [["+p]], { desc = "Paste from clipboard" })

-- Section: Word motion and nested-pane decisions
local function move_word_back_in_line()
  vim.fn.search([[\<]], "bW", vim.fn.line("."))
end

local function move_word_forward_in_line()
  if vim.fn.search([[\<]], "W", vim.fn.line(".")) == 0 then
    local line = vim.api.nvim_get_current_line()
    vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), #line })
  end
end

local function move_window_or_pane(direction)
  local tmux_direction = ({ h = "L", j = "D", k = "U", l = "R" })[direction]
  local current_window = vim.api.nvim_get_current_win()

  vim.cmd.wincmd(direction)

  if vim.api.nvim_get_current_win() ~= current_window then
    return
  end

  -- Herdr can be nested inside tmux. Focus the nearest enclosing pane first.
  if vim.env.HERDR_ENV == "1" and vim.env.HERDR_PANE_ID and vim.fn.executable("herdr") == 1 then
    local herdr_direction = ({ h = "left", j = "down", k = "up", l = "right" })[direction]
    vim.fn.system({ "herdr", "pane", "focus", "--direction", herdr_direction, "--pane", vim.env.HERDR_PANE_ID })
    return
  end

  if vim.env.TMUX and tmux_direction and vim.fn.executable("tmux") == 1 then
    vim.fn.system({ "tmux", "select-pane", "-" .. tmux_direction })
  end
end

-- Section: Portable motion and scrolling
keymap({ "n", "x", "i" }, "<C-Left>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x", "i" }, "<C-Right>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-Up>", "5<C-y>", { desc = "Scroll up 5 lines" })
keymap({ "n", "x" }, "<C-Down>", "5<C-e>", { desc = "Scroll down 5 lines" })
keymap("i", "<C-Up>", "<C-o>5<C-y>", { desc = "Scroll up 5 lines" })
keymap("i", "<C-Down>", "<C-o>5<C-e>", { desc = "Scroll down 5 lines" })

-- Section: Buffer and pane navigation
keymap("n", "<leader>x", "<cmd>wq<cr>", { desc = "Save and quit" })
keymap("n", "<leader>[", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
keymap("n", "<leader>]", "<cmd>bnext<cr>", { desc = "Next buffer" })
keymap("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
keymap("n", "<leader>\\", "<cmd>vsplit<cr>", { desc = "Vertical split" })
keymap("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Vertical split" })
keymap("n", "<leader>-", "<cmd>split<cr>", { desc = "Horizontal split" })
keymap("n", "<A-h>", function()
  move_window_or_pane("h")
end, { desc = "Move to left window or enclosing pane" })
keymap("n", "<A-j>", function()
  move_window_or_pane("j")
end, { desc = "Move to lower window or enclosing pane" })
keymap("n", "<A-k>", function()
  move_window_or_pane("k")
end, { desc = "Move to upper window or enclosing pane" })
keymap("n", "<A-l>", function()
  move_window_or_pane("l")
end, { desc = "Move to right window or enclosing pane" })

keymap({ "n", "x" }, "<C-h>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x" }, "<C-l>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap({ "n", "x" }, "<C-j>", "5<C-e>", { desc = "Scroll down 5 lines" })
keymap({ "n", "x" }, "<C-k>", "5<C-y>", { desc = "Scroll up 5 lines" })
keymap("x", "J", ":move '>+1<cr>gv=gv", { desc = "Move selection down" })
keymap("x", "K", ":move '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Section: Saving, terminal mode, and diagnostics
keymap("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
keymap("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
keymap({ "n", "x", "i" }, "<A-Left>", move_word_back_in_line, { desc = "Move back one word on current line" })
keymap({ "n", "x", "i" }, "<A-Right>", move_word_forward_in_line, { desc = "Move forward one word on current line" })
keymap("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
keymap("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
keymap("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
keymap("n", "<leader>dd", vim.diagnostic.open_float, { desc = "Line diagnostic" })
keymap("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostic list" })
keymap("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
keymap("n", "[q", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })
