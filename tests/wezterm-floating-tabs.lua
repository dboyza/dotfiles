-- Run with the real WezTerm Lua API and an isolated fixture home.
local wezterm = require 'wezterm'
local home = assert(os.getenv('DOTFILES_FLOATING_TEST_HOME'))
local original_home, original_on, original_spawn = wezterm.home_dir, wezterm.on, wezterm.background_child_process
local callbacks, spawned = {}, 0
wezterm.home_dir = home
wezterm.on = function(name, callback) callbacks[name] = callback end
wezterm.background_child_process = function() spawned = spawned + 1 end
local config = dofile(wezterm.config_dir .. '/../wezterm/.wezterm.lua')
wezterm.on = original_on
local root = home .. '/.local/state/dotfiles/wezterm-floating-tabs/'
local function read(name)
  local file = assert(io.open(root .. name, 'r'))
  local data = wezterm.json_parse(file:read('*a'))
  file:close()
  return data
end
local function write(name, data)
  local file = assert(io.open(root .. name, 'w'))
  file:write(type(data) == 'string' and data or wezterm.json_encode(data))
  file:close()
end
local focused, overrides, activated = true, { font_size = 17 }, nil
local selected = 0
local window = {
  is_focused = function() return focused end,
  mux_window = function() return {
    window_id = function() return 42 end,
    tabs_with_info = function() return {
      { index = 0, is_active = selected == 0, tab = { tab_id = function() return 11 end } },
      { index = 1, is_active = selected == 1, tab = { tab_id = function() return 12 end } },
    } end,
  } end,
  active_tab = function() return { get_size = function() return { cols = 100, pixel_width = 1800 } end } end,
  get_dimensions = function() return { pixel_width = 1850 } end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, value) overrides = value end,
  set_left_status = function() end,
  set_right_status = function() end,
  active_pane = function() return {} end,
  perform_action = function(_, action)
    activated = wezterm.json_encode(action)
    selected = wezterm.json_parse(activated).ActivateTab
  end,
}
local update = assert(callbacks['update-status'])
update(window)
local snapshot = read('current.json')
assert(#snapshot.tabs == 2 and snapshot.tabs[2].id == 12)
assert(overrides.enable_tab_bar == true and overrides.font_size == 17, 'missing helper must keep native tabs')
write('ready.json', { title = snapshot.title, updated = os.time() })
update(window)
assert(overrides.enable_tab_bar == false, 'only an acknowledged window can hide native tabs')
write('activate.json', { title = snapshot.title, updated = os.time(), tab_id = 12 })
update(window)
assert(activated == '{"ActivateTab":1}', 'click must activate the requested tab index')
assert(read('current.json').tabs[2].active, 'click must publish the new selection in the same update')
activated = nil
for _, request in ipairs({
  { title = snapshot.title, updated = os.time() - 10, tab_id = 12 },
  { title = snapshot.title, updated = os.time(), tab_id = 999 },
  { title = 'another process', updated = os.time(), tab_id = 12 },
}) do
  write('activate.json', request)
  update(window)
  assert(activated == nil, 'stale, foreign, and removed tabs must never activate')
end
for _, reply in ipairs({ 'broken json', { title = snapshot.title, updated = os.time() - 10 },
  { title = 'another window', updated = os.time() } }) do
  write('ready.json', reply)
  update(window)
  assert(overrides.enable_tab_bar == true, 'invalid or stale acknowledgments must restore native tabs')
end
write('ready.json', { title = snapshot.title, updated = os.time() })
focused = false
update(window)
assert(overrides.enable_tab_bar == true, 'inactive windows keep native tabs')
assert(spawned == 1, 'helper must launch only once per GUI process')
-- Keyboard switching must publish from the title event without a status tick.
focused = true
update(window)
local original_get_tab = wezterm.mux.get_tab
local window_id = 42
wezterm.mux.get_tab = function() return { window = function() return {
  window_id = function() return window_id end,
} end } end
local titles = {
  { tab_id = 11, tab_index = 0, is_active = true },
  { tab_id = 12, tab_index = 1, is_active = false },
}
callbacks['format-window-title'](titles[1], nil, titles)
assert(read('current.json').tabs[1].active, 'title event must publish selection without waiting for polling')
window_id = 99
callbacks['format-window-title'](titles[1], nil, titles)
assert(read('current.json').title == snapshot.title, 'background windows must not replace the focused snapshot')
wezterm.mux.get_tab = original_get_tab
wezterm.home_dir, wezterm.background_child_process = original_home, original_spawn
return config
