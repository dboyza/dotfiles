-- Exercise entry-point resolution without depending on the actual user's home.
local wezterm = require 'wezterm'
local root = assert(os.getenv('DOTFILES_LOADER_FIXTURE'))
local source = root .. '/checkout with spaces/.wezterm.lua'
local original_file, original_triple = wezterm.config_file, wezterm.target_triple
local watches = {}
local original_watch = wezterm.add_to_config_reload_watch_list
wezterm.add_to_config_reload_watch_list = function(path) watches[path] = true end

-- An installed Unix symlink chain must find the adjacent modules.
wezterm.config_file = root .. '/home/.wezterm.lua'
assert(dofile(wezterm.config_file).font_size > 0)
for _, name in ipairs({ 'appearance', 'geometry', 'keys', 'platform', 'protocol', 'tabs' }) do
  local watched = false
  local suffix = '/checkout with spaces/config/' .. name .. '.lua'
  for path in pairs(watches) do
    if path:sub(-#suffix) == suffix then watched = true end
  end
  assert(watched, 'module not watched: ' .. name)
end

-- Windows loaders created before modularization must keep working too.
wezterm.target_triple = 'x86_64-pc-windows-msvc'
wezterm.default_wsl_domains = function() return {} end
for _, legacy in ipairs({ true, false }) do
  local loader_path = root .. '/windows.lua'
  local loader = assert(io.open(loader_path, 'w'))
  loader:write('local source = ', wezterm.json_encode(source), '\n')
  loader:write(legacy and 'return dofile(source)\n' or 'return assert(loadfile(source))(source)\n')
  loader:close()
  wezterm.config_file = loader_path
  local program = dofile(loader_path).default_prog[1]
  assert(program:find('powershell') or program:find('pwsh'))
end
wezterm.config_file, wezterm.target_triple = original_file, original_triple
wezterm.add_to_config_reload_watch_list = original_watch
return {}
