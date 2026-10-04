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
local expected_border = wezterm.target_triple:lower():find('windows') and '0px' or '1px'
for _, field in ipairs({ 'border_left_width', 'border_right_width', 'border_top_height', 'border_bottom_height' }) do
  assert(config.window_frame[field] == expected_border, 'Windows must not draw a square border inside its native rounded frame')
end
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
assert(config.status_update_interval <= 20, 'helper input must be checked within a display frame')
local original_now = wezterm.time.now
local now = 100
wezterm.time.now = function() return { format = function() return tostring(now) end } end
local focused, overrides, activated = true, { font_size = 17 }, nil
local status_writes = 0
local status_rearms = 0
local selected = 0
local window_id = 42
local function tab(id, index)
  return {
    tab_id = function() return id end,
    activate = function()
      selected = index
      activated = wezterm.json_encode(wezterm.action.ActivateTab(index))
    end,
  }
end
local window = {
  is_focused = function() return focused end,
  mux_window = function() return {
    window_id = function() return window_id end,
    tabs_with_info = function() return {
      { index = 0, is_active = selected == 0, tab = tab(11, 0) },
      { index = 1, is_active = selected == 1, tab = tab(12, 1) },
    } end,
  } end,
  active_tab = function() return { get_size = function() return { cols = 100, pixel_width = 1800 } end } end,
  get_dimensions = function() return { pixel_width = 1850 } end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, value) overrides = value end,
  set_left_status = function() status_rearms = status_rearms + 1 end,
  set_right_status = function() status_writes = status_writes + 1 end,
  active_pane = function() return {} end,
  perform_action = function(_, action)
    activated = wezterm.json_encode(action)
    selected = wezterm.json_parse(activated).ActivateTab or selected
  end,
}
local tick = assert(callbacks['update-status'])
local function update(target)
  now = now + 1
  tick(target)
end
update(window)
local key = wezterm.GLOBAL.floating_tabs_token .. '-42'
local snapshot = read('window-' .. key .. '.json')
assert(#snapshot.tabs == 2 and snapshot.tabs[2].id == 12)
assert(overrides.enable_tab_bar == true and overrides.font_size == 17, 'missing helper must keep native tabs')
write('ready-' .. key .. '.json', { title = snapshot.title, updated = os.time() })
update(window)
assert(overrides.enable_tab_bar == false, 'only an acknowledged window can hide native tabs')
write('activate-' .. key .. '.json', { title = snapshot.title, updated = os.time(), tab_id = 12 })
local previous_writes, previous_rearms = status_writes, status_rearms
now = now + 0.016
tick(window)
assert(activated == '{"ActivateTab":1}', 'click must activate the requested tab index')
assert(read('window-' .. key .. '.json').tabs[2].active, 'click must publish the new selection in the same update')
assert(status_writes == previous_writes, 'input must not wait for or rebuild the clock/status')
assert(status_rearms == previous_rearms + 1, 'input-only ticks must rearm the idle-window status timer')
activated = nil
for _ = 1, 5 do
  now = now + 0.016
  tick(window)
end
assert(activated == nil and status_writes == previous_writes, 'idle input ticks must stay lightweight and never replay clicks')
now = now - 10
tick(window)
assert(status_writes == previous_writes + 1, 'a wall-clock correction must not stall helper maintenance')
for _, request in ipairs({
  { title = snapshot.title, updated = os.time() - 10, tab_id = 12 },
  { title = snapshot.title, updated = os.time(), tab_id = 999 },
  { title = 'another process', updated = os.time(), tab_id = 12 },
}) do
  write('activate-' .. key .. '.json', request)
  update(window)
  assert(activated == nil, 'stale, foreign, and removed tabs must never activate')
end
for _, reply in ipairs({ 'broken json', { title = snapshot.title, updated = os.time() - 10 },
  { title = 'another window', updated = os.time() } }) do
  write('ready-' .. key .. '.json', reply)
  update(window)
  assert(overrides.enable_tab_bar == true, 'invalid or stale acknowledgments must restore native tabs')
end
write('ready-' .. key .. '.json', { title = snapshot.title, updated = os.time() })
focused = false
update(window)
assert(overrides.enable_tab_bar == false, 'acknowledged inactive windows retain floating tabs')
assert(spawned == 1, 'helper must launch only once per GUI process')
-- Keyboard switching must publish from the title event without a status tick.
focused = true
update(window)
local original_get_tab = wezterm.mux.get_tab
window_id = 42
wezterm.mux.get_tab = function() return { window = function() return {
  window_id = function() return window_id end,
} end } end
local titles = {
  { tab_id = 11, tab_index = 0, is_active = true },
  { tab_id = 12, tab_index = 1, is_active = false },
}
callbacks['format-window-title'](titles[1], nil, titles)
assert(read('window-' .. key .. '.json').tabs[1].active, 'title event must publish selection without waiting for polling')
window_id = 99
callbacks['format-window-title'](titles[1], nil, titles)
assert(read('window-' .. key .. '.json').title == snapshot.title, 'background windows must not replace another snapshot')
local second = read('window-' .. wezterm.GLOBAL.floating_tabs_token .. '-99.json')
assert(second.title ~= snapshot.title and second.tabs[1].active, 'background windows must publish independently')
-- Acknowledgment and clicks must be routed independently while both are live.
local second_key = wezterm.GLOBAL.floating_tabs_token .. '-99'
write('ready-' .. second_key .. '.json', { title = second.title, updated = os.time() })
write('ready-' .. key .. '.json', { title = snapshot.title, updated = os.time() - 10 })
write('activate-' .. second_key .. '.json', { title = second.title, updated = os.time(), tab_id = 12 })
window_id = 42
activated = nil
update(window)
assert(activated == nil and overrides.enable_tab_bar == true, 'other windows cannot consume a click or acknowledgment')
window_id = 99
update(window)
assert(activated == '{"ActivateTab":1}' and overrides.enable_tab_bar == false, 'background click must target its own window')
assert(read('window-' .. second_key .. '.json').tabs[2].active)
-- The plus button shares the portable shortcut's domain and working directory.
local new_tab_action
for _, binding in ipairs(config.keys) do
  if binding.key == 't' and binding.mods == 'CTRL|SHIFT' then new_tab_action = wezterm.json_encode(binding.action) end
end
assert(new_tab_action)
write('activate-' .. second_key .. '.json', { title = second.title, updated = os.time(), action = 'new_tab' })
window_id = 42
activated = nil
update(window)
assert(activated == nil, 'new tabs must be routed to their own window')
window_id = 99
now = now + 0.016
tick(window)
assert(activated == new_tab_action, 'plus must create the same tab as Control+Shift+T')
activated = nil
update(window)
assert(activated == nil, 'a consumed new-tab click must never replay')
for _, request in ipairs({
  { title = second.title, updated = os.time() - 10, action = 'new_tab' },
  { title = 'another window', updated = os.time(), action = 'new_tab' },
  { title = second.title, updated = os.time(), action = 'unknown', tab_id = 12 },
}) do
  write('activate-' .. second_key .. '.json', request)
  update(window)
  assert(activated == nil, 'invalid new-tab commands must not execute')
end
wezterm.mux.get_tab = original_get_tab
wezterm.time.now = original_now
wezterm.home_dir, wezterm.background_child_process = original_home, original_spawn
return config
