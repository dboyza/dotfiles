-- Run with the real WezTerm Lua API and an isolated fixture home.
local wezterm = require 'wezterm'
local home = assert(os.getenv('DOTFILES_FLOATING_TEST_HOME'))
local original_home, original_on, original_spawn = wezterm.home_dir, wezterm.on, wezterm.background_child_process
local callbacks, spawned = {}, 0
wezterm.home_dir = home
wezterm.on = function(name, callback) callbacks[name] = callback end
wezterm.background_child_process = function() spawned = spawned + 1 end
local source = (os.getenv('DOTFILES_TEST_REPO') or (wezterm.config_dir .. '/..')) .. '/wezterm/.wezterm.lua'
-- Section: Shared protocol fixtures
local protocol = dofile(source:match('^(.*)/') .. '/config/protocol.lua')
local fixture_file = assert(io.open(source:match('^(.*)/') .. '/../tests/fixtures/floating-tabs.json'))
local fixtures = wezterm.json_parse(fixture_file:read('*a'))
fixture_file:close()
for _, case in ipairs(fixtures.snapshots) do
  local ok, value = pcall(wezterm.json_parse, case.payload)
  local valid = ok and protocol.valid_snapshot(value, case.file, case.now) or false
  assert(valid == case.valid, 'snapshot contract: ' .. case.name)
end
for _, case in ipairs(fixtures.requests) do
  assert(protocol.valid_request(case.reply, 'WezTerm [abc:42]', 1000) == case.valid, 'request contract: ' .. case.name)
end
local config = assert(loadfile(source))(source)
wezterm.on = original_on
local expected_border = wezterm.target_triple:lower():find('windows') and '0px' or '1px'
for _, field in ipairs({ 'border_left_width', 'border_right_width', 'border_top_height', 'border_bottom_height' }) do
  assert(config.window_frame[field] == expected_border, 'Windows must not draw a square border inside its native rounded frame')
end
-- Section: Per-window bridge and GUI stand-ins
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
-- Section: Input and maintenance cadence
assert(config.status_update_interval <= 20, 'helper input must be checked within a display frame')
local original_now = wezterm.time.now
local now = 100
wezterm.time.now = function() return { format = function() return tostring(now) end } end
local focused, overrides, activated = true, { font_size = 17 }, nil
local status_writes = 0
local status_rearms = 0
local selected = 0
local window_id = 42
-- Tab 11 runs Neovim; tab 12 is a plain shell in /work/repo.
local programs = { [11] = '/usr/bin/nvim', [12] = '/bin/zsh' }
-- A fixture repository on a feature branch, with a subfolder to exercise the upward search.
local repository = home .. '/work/repo'
os.execute('mkdir -p "' .. repository .. '/.git" "' .. repository .. '/src"')
do
  local head = assert(io.open(repository .. '/.git/HEAD', 'w'))
  head:write('ref: refs/heads/feature/strip\n')
  head:close()
end
local directories = { [11] = '/work/elsewhere', [12] = repository }
local titles, detached = {}, nil
local progress = { [11] = { Percentage = 70 }, [12] = 'Indeterminate' }
local function tab(id, index)
  return {
    tab_id = function() return id end,
    get_title = function() return titles[id] or '' end,
    active_pane = function() return {
      get_foreground_process_name = function() return programs[id] end,
      get_current_working_dir = function() return { file_path = directories[id] } end,
      get_domain_name = function() return 'local' end,
      get_progress = function() return progress[id] or 'None' end,
      move_to_new_window = function() detached = id end,
    } end,
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
    -- Prompt actions carry a callback that cannot be serialized.
    local ok, encoded = pcall(wezterm.json_encode, action)
    activated = ok and encoded or 'PromptInputLine'
    selected = ok and type(wezterm.json_parse(encoded)) == 'table' and wezterm.json_parse(encoded).ActivateTab or selected
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
assert(snapshot.tabs[1].label == 'nvim' and snapshot.tabs[2].label == 'repo', 'tabs must name their program or folder')
assert(snapshot.tabs[1].alert == nil and snapshot.tabs[2].alert == nil)
-- Richer hints: progress from the terminal, and the git branch read from the fixture repository.
assert(snapshot.tabs[1].progress == 70 and snapshot.tabs[1].progress_state == 'normal', 'percent progress must publish')
assert(snapshot.tabs[2].progress == nil and snapshot.tabs[2].progress_state == 'indeterminate', 'indeterminate progress has no percent')
assert(snapshot.tabs[1].path == '/work/elsewhere' and snapshot.tabs[1].branch == nil, 'non-repositories have a path but no branch')
if not wezterm.target_triple:find('windows') then
  assert(snapshot.tabs[2].branch == 'feature/strip', 'repositories report their branch')
  assert(snapshot.tabs[2].path:find('/work/repo', 1, true), 'tabs must publish their directory for tooltips')
  directories[12] = repository .. '/src'
  update(window)
  assert(read('window-' .. key .. '.json').tabs[2].branch == 'feature/strip', 'subfolders of a repository report its branch')
  directories[12] = repository
end
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
-- Section: A user-set tab name wins over the program, and clears back when emptied
titles[11] = 'my name'
update(window)
assert(read('window-' .. key .. '.json').tabs[1].label == 'my name', 'renamed tabs must keep their chosen name')
titles[11] = nil
update(window)
assert(read('window-' .. key .. '.json').tabs[1].label == 'nvim', 'an emptied name must fall back to the program')
-- Section: Activity alerts on background tabs
local function pane_in(tab_id, active_id)
  return { tab = function() return {
    tab_id = function() return tab_id end,
    window = function() return { active_tab = function() return { tab_id = function() return active_id end } end } end,
  } end }
end
callbacks['bell'](window, pane_in(11, 12))
update(window)
assert(read('window-' .. key .. '.json').tabs[1].alert == true, 'a bell in a background tab must flag it')
callbacks['bell'](window, pane_in(12, 12))
callbacks['user-var-changed'](window, pane_in(12, 12), 'dotfiles_command_done')
callbacks['user-var-changed'](window, pane_in(12, 12), 'unrelated')
update(window)
assert(read('window-' .. key .. '.json').tabs[2].alert == nil, 'the visible tab never raises an alert')
selected = 0
update(window)
assert(read('window-' .. key .. '.json').tabs[1].alert == nil, 'viewing a tab must clear its alert')
callbacks['user-var-changed'](window, pane_in(11, 12), 'dotfiles_command_done')
selected = 1
update(window)
assert(read('window-' .. key .. '.json').tabs[1].alert == true, 'a finished long command must flag a background tab')
selected = 0
update(window)
selected = 1
update(window)
-- Section: Rejected requests and acknowledgment fallback
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
-- Section: Title events and multiple windows
-- Keyboard switching must publish from the title event without a status tick.
focused = true
update(window)
local original_get_tab = wezterm.mux.get_tab
window_id = 42
wezterm.mux.get_tab = function() return { window = function() return {
  window_id = function() return window_id end,
} end } end
local titles = {
  { tab_id = 11, tab_index = 0, is_active = true, active_pane = { title = 'no process data here' } },
  { tab_id = 12, tab_index = 1, is_active = false, active_pane = {} },
}
callbacks['format-window-title'](titles[1], nil, titles)
assert(read('window-' .. key .. '.json').tabs[1].active, 'title event must publish selection without waiting for polling')
-- Title events often lack process data; they must reuse the labels the mux path found, never drop them.
assert(read('window-' .. key .. '.json').tabs[1].label == 'nvim', 'title events must not flip labels off')
assert(read('window-' .. key .. '.json').tabs[2].label == 'repo', 'title events must not flip labels off')
local fresh_titles = { { tab_id = 77, tab_index = 0, is_active = true,
  active_pane = { foreground_process_name = '/opt/bin/claude', current_working_dir = '/work/repo' } } }
callbacks['format-window-title'](fresh_titles[1], nil, fresh_titles)
assert(read('window-' .. key .. '.json').tabs[1].label == 'claude', 'new tabs fall back to the pane information')
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
-- Section: New-tab action routing and replay prevention
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
-- Section: Close requests use the confirmed close action
write('activate-' .. second_key .. '.json', { title = second.title, updated = os.time(), action = 'close_tab', tab_id = 12 })
window_id = 42
update(window)
assert(activated == nil, 'close requests must be routed to their own window')
window_id = 99
now = now + 0.016
tick(window)
assert(activated and activated:find('CloseCurrentTab', 1, true) and activated:find('"confirm":true', 1, true),
  'close must use the confirmed tab-close action')
activated = nil
write('activate-' .. second_key .. '.json', { title = second.title, updated = os.time(), action = 'close_tab', tab_id = 999 })
update(window)
assert(activated == nil, 'closing a tab the window does not own must do nothing')
-- Section: Reorder, duplicate, detach, and rename requests
local function request(fields)
  fields.title, fields.updated = second.title, os.time()
  write('activate-' .. second_key .. '.json', fields)
  now = now + 0.016
  activated = nil
  tick(window)
end
request({ action = 'move_tab', tab_id = 12, index = 0 })
assert(activated == '{"MoveTab":0}', 'move_tab must reorder through the native action: ' .. tostring(activated))
request({ action = 'duplicate_tab', tab_id = 12 })
assert(activated and activated:find('SpawnTab', 1, true) and activated:find('CurrentPaneDomain', 1, true), 'duplicate must open a sibling tab')
request({ action = 'detach_tab', tab_id = 12 })
assert(detached == 12, 'detach must move the tab to a new window')
request({ action = 'rename_tab', tab_id = 12 })
assert(activated and activated:find('PromptInputLine', 1, true), 'rename must prompt for a name')
request({ action = 'move_tab', tab_id = 12 })
assert(activated == nil, 'move without a target index must do nothing')
for _, request in ipairs({
  { title = second.title, updated = os.time() - 10, action = 'new_tab' },
  { title = 'another window', updated = os.time(), action = 'new_tab' },
  { title = second.title, updated = os.time(), action = 'unknown', tab_id = 12 },
  { title = second.title, updated = os.time(), action = 'close_tab' },
}) do
  write('activate-' .. second_key .. '.json', request)
  update(window)
  assert(activated == nil, 'invalid new-tab commands must not execute')
end
wezterm.mux.get_tab = original_get_tab
wezterm.time.now = original_now
wezterm.home_dir, wezterm.background_child_process = original_home, original_spawn
return config
