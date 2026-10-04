-- Neovim -l can print E5113 and still exit zero. Own the process verdict.
local source = assert(table.remove(arg, 1), 'expected a Lua test path')
local ok, error = xpcall(function() dofile(source) end, debug.traceback)
if not ok then
  io.stderr:write(tostring(error), '\n')
  vim.cmd('cquit 1')
end
io.stderr:write('\n')
vim.cmd('quitall!')
