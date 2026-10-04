-- Verify next-tab selection, window preservation, unsaved edits, and final-tab exit.
local close = require("config.buffers").close
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fn.fnamemodify(script, ":h:h")

if arg[1] == "--final" then
  vim.cmd.vsplit()
  local sidebar = vim.api.nvim_create_buf(false, true)
  vim.bo[sidebar].filetype = "neo-tree"
  vim.api.nvim_win_set_buf(0, sidebar)
  local final = vim.fn.getbufinfo({ buflisted = 1 })[1].bufnr
  close(final)
  error("closing the final file tab must exit Neovim")
end

local first = vim.api.nvim_get_current_buf()
local second = vim.api.nvim_create_buf(true, false)
local third = vim.api.nvim_create_buf(true, false)
local order = { first, third, second }
package.loaded.bufferline = {
  get_elements = function()
    local elements = {}
    for _, buf in ipairs(order) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
        elements[#elements + 1] = { id = buf }
      end
    end
    return { elements = elements }
  end,
}

-- Section: Preserve splits and the sidebar while following a manually moved tab
local editor = vim.api.nvim_get_current_win()
vim.cmd.vsplit()
local other_editor = vim.api.nvim_get_current_win()
vim.cmd.vsplit()
local sidebar_win = vim.api.nvim_get_current_win()
local sidebar = vim.api.nvim_create_buf(false, true)
vim.bo[sidebar].filetype = "neo-tree"
vim.api.nvim_win_set_buf(sidebar_win, sidebar)
vim.api.nvim_set_current_win(editor)
close(first)
assert(vim.api.nvim_get_current_buf() == third, "close must follow display order")
assert(vim.api.nvim_win_get_buf(other_editor) == third, "all windows showing the closed file must switch")
assert(#vim.api.nvim_list_wins() == 3, "closing a buffer must preserve editor windows")
assert(vim.api.nvim_win_get_buf(sidebar_win) == sidebar, "sidebar must remain open")
assert(not vim.api.nvim_buf_is_valid(first) or not vim.bo[first].buflisted)

-- Section: Protect unsaved edits and preserve focus when closing an inactive tab
local confirm = vim.fn.confirm
vim.api.nvim_buf_set_lines(second, 0, -1, false, { "unsaved edit" })
for _, answer in ipairs({ 0, 3 }) do
  vim.fn.confirm = function() return answer end
  close(second)
  assert(vim.bo[second].buflisted and vim.bo[second].modified, "cancel must retain unsaved changes")
end
vim.fn.confirm = function() return 1 end
local ok = pcall(close, second)
assert(not ok and vim.bo[second].buflisted, "a failed save must prevent deletion")
local saved = vim.fn.tempname()
vim.api.nvim_buf_set_name(second, saved)
close(second)
assert(vim.fn.readfile(saved)[1] == "unsaved edit", "save choice must write before deletion")
assert(vim.api.nvim_get_current_buf() == third, "closing an inactive tab must preserve focus")
vim.fn.delete(saved)

-- Section: Discard by explicit choice and wrap to the first tab
local last = vim.api.nvim_create_buf(true, false)
order = { third, last }
vim.api.nvim_win_set_buf(editor, last)
vim.api.nvim_buf_set_lines(last, 0, -1, false, { "discard me" })
vim.fn.confirm = function() return 2 end
close(last)
assert(vim.api.nvim_get_current_buf() == third, "closing the rightmost tab must wrap to the first")
assert(not vim.api.nvim_buf_is_valid(last) or not vim.bo[last].buflisted)
vim.fn.confirm = confirm

-- Section: Exercise final-tab exit in a separate real Neovim process
local output = vim.fn.system({
  vim.v.progpath, "--headless", "-u", root .. "/nvim/init.lua", "-i", "NONE",
  "-l", root .. "/tests/run-lua.lua", script, "--final",
})
assert(vim.v.shell_error == 0, "final-tab exit failed: " .. output)
print("Neovim next-tab closing, unsaved edits, preserved windows, and final-tab exit passed")
