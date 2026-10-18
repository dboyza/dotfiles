-- Load the shared Rosé Pine Moon palette from theme/palette.json (also read by Neovim).
return function(wezterm, directory)
  local path = directory .. '/../theme/palette.json'
  if wezterm.add_to_config_reload_watch_list then wezterm.add_to_config_reload_watch_list(path) end
  local file = assert(io.open(path, 'r'), 'missing palette file: ' .. path)
  local text = file:read('*a')
  file:close()
  return wezterm.json_parse(text)
end
