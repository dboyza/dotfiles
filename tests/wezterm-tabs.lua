-- Run with WezTerm itself so Unicode widths use its actual renderer helpers.
local wezterm = require 'wezterm'
local callbacks = {}
local original_on = wezterm.on
wezterm.on = function(name, callback)
  callbacks[name] = callback
end
local config = dofile(wezterm.config_dir .. '/../wezterm/.wezterm.lua')
wezterm.on = original_on

local format_title = assert(callbacks['format-tab-title'])
local function label_text(result)
  local parts = {}
  for _, item in ipairs(result) do
    if item.Text then
      table.insert(parts, item.Text)
    end
  end
  return table.concat(parts)
end

-- Tabline emits bounded labels; WezTerm clips them further when tabs are crowded.
for _, title in ipairs({ 'shell', 'a very long project name with spaces', '日本語のプロジェクト', '🌲 café', '' }) do
  for _, state in ipairs({ { active = true }, { active = false }, { active = false, hover = true } }) do
    local result = format_title({ tab_index = 0, tab_title = title, is_active = state.active, active_pane = { title = 'fallback' } }, {}, {}, config, state.hover, config.tab_max_width)
    assert(wezterm.column_width(label_text(result)) <= config.tab_max_width, 'rounded tab must fit the configured cell limit')
    wezterm.format(result) -- Validate the formatting against WezTerm's real API.
  end
end

for _, fixture in ipairs({
  { title = ' custom ', cwd = 'file:///work/project', expected = 'custom' },
  { cwd = 'file:///work/dotfiles/', expected = 'dotfiles' },
  { cwd = 'file:///C:/work/my%20project/', expected = 'my project' },
  { cwd = 'file://remote/home/user/project', expected = 'project' },
  { cwd = { file_path = 'C:\\work\\dotfiles\\' }, expected = 'dotfiles' },
  { cwd = { file_path = '/home/user/café' }, expected = 'café' },
  { title = '  ', pane_title = '  ssh\nserver  ', expected = 'ssh server' },
  { pane_title = '', expected = 'shell' },
}) do
  local result = format_title({
    tab_index = 0,
    is_active = true,
    tab_title = fixture.title,
    active_pane = { title = fixture.pane_title or 'fallback', current_working_dir = fixture.cwd },
  }, {}, {}, config, false, config.tab_max_width)
  assert(label_text(result):find(fixture.expected, 1, true), 'tab must display ' .. fixture.expected)
end

local url = wezterm.url.parse('file:///work/project%20name')
local result = format_title({ tab_index = 11, is_active = true, active_pane = { current_working_dir = url } }, {}, {}, config, false, config.tab_max_width)
assert(label_text(result):find('12 project name', 1, true), 'URL objects must produce readable numbered names')

assert(config.colors.tab_bar.background == '#191724', 'bar must have a solid dark background')
for _, style in ipairs({ 'active_tab', 'inactive_tab', 'inactive_tab_hover' }) do
  assert(config.colors.tab_bar[style].bg_color == config.colors.tab_bar.background, 'native tab backing must match rounded cap backgrounds')
end
assert(not config.tab_bar_at_bottom and not config.hide_tab_bar_if_only_one_tab)
assert(callbacks['window-resized'] == nil and callbacks['window-config-reloaded'] == nil,
  'reload and resize must not clear Tabline status')

for _, fixture in ipairs({
  { process = '/opt/homebrew/bin/nvim', expected = 'nvim' },
  { process = 'C:\\Program Files\\PowerShell\\pwsh.exe', expected = 'pwsh' },
  { process = 'C:\\Windows\\wslhost.exe', title = 'zsh', expected = 'zsh' },
  { title = 'ssh', expected = 'ssh' },
  { process = '/bin/zsh', explicit = 'custom', expected = 'custom' },
}) do
  local result = format_title({ tab_index = 1, is_active = false, tab_title = fixture.explicit,
    active_pane = { foreground_process_name = fixture.process, title = fixture.title,
      current_working_dir = { file_path = '/work/should-not-appear' } },
  }, {}, {}, config, false, config.tab_max_width)
  assert(label_text(result):find(fixture.expected, 1, true), 'inactive tab must display ' .. fixture.expected)
  assert(not label_text(result):find('should-not-appear', 1, true))
end

local original_hostname = wezterm.hostname
wezterm.hostname = function() return 'test-host-with-long-name' end
local function plain(text)
  return text:gsub('\27%[[%d;:]*m', '')
end
local function status(cols, mode)
  local left, right
  callbacks['update-status']({
    active_key_table = function() return mode end,
    active_workspace = function() return 'workspace-with-long-name' end,
    active_tab = function() return { get_size = function() return { cols = cols } end } end,
    set_left_status = function(_, text) left = plain(text) end,
    set_right_status = function(_, text) right = plain(text) end,
  }, {})
  return left, right
end
for _, cols in ipairs({ 40, 79, 80, 99, 100, 119, 120, 139, 140, 160 }) do
  local left, right = status(cols)
  assert(left:find(cols < 80 and ' n ' or ' normal ', 1, true))
  assert((left:find('workspace', 1, true) ~= nil) == (cols >= 100))
  assert(not left:find('', 1, true), 'left strip must start flat and join sections without separate left caps')
  local _, round_ends = left:gsub('', '')
  assert(round_ends == (cols >= 100 and 2 or 1), 'mode and workspace must each end with a rounded transition')
  assert(wezterm.column_width(left .. right) < cols - 10, 'status must leave space for tabs')
  if cols >= 100 then
    assert(right:match('^ test.*  $'), 'right status must contain only the rounded hostname')
    assert(wezterm.column_width(right) <= (cols < 120 and 13 or 25))
  else
    assert(right == '', 'narrow windows must prioritize tabs')
  end
end
for _, mode in ipairs({ 'copy_mode', 'search_mode', 'custom_table' }) do
  local left = status(160, mode)
  assert(left:find(mode:gsub('_mode$', ''):sub(1, 6), 1, true), 'mode must update without clearing workspace')
end
wezterm.hostname = function() return '' end
local _, no_host = status(160)
assert(no_host == '', 'missing hostname must not leave an empty capsule')
wezterm.hostname = original_hostname

return config
