-- Load the shared Rosé Pine Moon palette (theme/palette.json) that WezTerm, tmux, and Starship also use.
local path = vim.fn.resolve(vim.fn.stdpath("config")) .. "/../theme/palette.json"
local file = assert(io.open(path, "r"), "missing palette file: " .. path)
local palette = vim.json.decode(file:read("*a"))
file:close()
return palette
