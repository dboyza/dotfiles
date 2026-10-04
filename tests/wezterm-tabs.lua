-- Run with WezTerm itself to validate formatting and display-cell widths.
local wezterm = require 'wezterm'
local callbacks = {}
local original_on, original_home = wezterm.on, wezterm.home_dir
-- This suite exercises the native fallback, independent of installed companions.
wezterm.home_dir = nil
wezterm.on = function(name, callback) callbacks[name] = callback end
local source = (os.getenv('DOTFILES_TEST_REPO') or (wezterm.config_dir .. '/..')) .. '/wezterm/.wezterm.lua'
local config = assert(loadfile(source))(source)
wezterm.on, wezterm.home_dir = original_on, original_home

-- Section: Display-cell normalization and tab labels
local function plain(text)
  -- format() emits both SGR styling and an ASCII charset selector.
  return text:gsub('\27%[[%d;:]*m', ''):gsub('\27%(B', '')
end
local format_title = assert(callbacks['format-tab-title'])
for _, index in ipairs({ 0, 8, 9, 99 }) do
  for _, width in ipairs({ 1, 2, 4, 8 }) do
    for _, state in ipairs({ { active = true }, { active = false }, { hover = true } }) do
      local result = format_title({ tab_index = index, is_active = state.active,
        tab_title = 'ignored name', active_pane = {} }, {}, {}, config, state.hover, width)
      local text = type(result) == 'string' and result or plain(wezterm.format(result))
      assert(wezterm.column_width(text) <= width, 'numbered tabs must fit even in crowded windows')
      if width >= #tostring(index + 1) + 2 then
        assert(text == '' .. tostring(index + 1) .. '', 'tabs must contain only their number')
      end
    end
  end
end

assert(not config.tab_bar_at_bottom and not config.hide_tab_bar_if_only_one_tab)
for _, style in ipairs({ 'active_tab', 'inactive_tab', 'inactive_tab_hover' }) do
  assert(config.colors.tab_bar[style].bg_color == config.colors.tab_bar.background)
end
-- Section: Focus borders and clock placement
local original_strftime = wezterm.strftime
wezterm.strftime = function(format)
  assert(format == '%I:%M %p', 'the clock should display 12-hour time with AM/PM')
  return '05:07 PM'
end
local focused, overrides, writes = true, { font_size = 17, window_frame = { font_size = 14 } }, 0
local border_window = {
  is_focused = function() return focused end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, value) overrides = value; writes = writes + 1 end,
}
local is_windows = wezterm.target_triple:find('windows') ~= nil
assert(config.window_frame.border_left_width == (is_windows and '0px' or '1px'),
  'Windows must retain its native rounded frame without a rectangular inner border')
for _, focus in ipairs({ true, false, true }) do
  focused = focus
  callbacks['window-focus-changed'](border_window)
  if is_windows then
    assert(writes == 0, 'the native companion must control the Windows frame')
  else
    assert(overrides.window_frame.border_left_color == (focus and '#908caa' or '#393552'))
    assert(overrides.window_frame.border_left_width == config.window_frame.border_left_width,
      'focus changes must retain the base frame configuration')
  end
  assert(overrides.font_size == 17 and overrides.window_frame.font_size == 14,
    'focus changes must preserve unrelated overrides')
  local previous = writes
  callbacks['window-focus-changed'](border_window)
  assert(writes == previous, 'unchanged focus must not trigger configuration reloads')
end
for _, cols in ipairs({ 12, 20, 40, 79, 80, 100, 139, 160 }) do
  for _, count in ipairs({ 1, 3, 10, 30 }) do
    local tabs, tabs_width = {}, 0
    for index = 0, count - 1 do
      tabs[#tabs + 1] = { index = index }
      tabs_width = tabs_width + #tostring(index + 1) + 2
    end
    local left, right
    callbacks['update-status']({
      is_focused = border_window.is_focused,
      get_config_overrides = border_window.get_config_overrides,
      set_config_overrides = border_window.set_config_overrides,
      active_tab = function() return { get_size = function() return { cols = math.max(1, cols - 3), pixel_width = math.max(1, cols - 3) * 18 } end } end,
      get_dimensions = function() return { pixel_width = cols * 18 } end,
      mux_window = function() return { tabs_with_info = function() return tabs end } end,
      set_left_status = function(_, text) left = text end,
      set_right_status = function(_, text) right = plain(text) end,
    })
    assert(left == '', 'tabs must start at the left edge')
    local clock_start = math.floor((cols - 11) / 2)
    if clock_start < tabs_width + 1 then
      assert(right == '', 'crowded tabs must hide the clock')
    else
      assert(right:find(' 5:07 PM ', 1, true) == 1)
      assert(cols - wezterm.column_width(right) == clock_start, 'clock must be centered')
    end
  end
end
wezterm.strftime = original_strftime
return config
