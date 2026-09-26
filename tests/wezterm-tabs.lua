-- Run with WezTerm itself to validate formatting and display-cell widths.
local wezterm = require 'wezterm'
local callbacks = {}
local original_on = wezterm.on
wezterm.on = function(name, callback) callbacks[name] = callback end
local config = dofile(wezterm.config_dir .. '/../wezterm/.wezterm.lua')
wezterm.on = original_on

local function plain(text)
  return text:gsub('\27%[[%d;:]*m', '')
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
local original_strftime = wezterm.strftime
wezterm.strftime = function() return '17:07:02' end
for _, cols in ipairs({ 12, 20, 40, 79, 80, 100, 139, 160 }) do
  for _, count in ipairs({ 1, 3, 10, 30 }) do
    local tabs, tabs_width = {}, 0
    for index = 0, count - 1 do
      tabs[#tabs + 1] = { index = index }
      tabs_width = tabs_width + #tostring(index + 1) + 2
    end
    local left, right
    callbacks['update-status']({
      active_tab = function() return { get_size = function() return { cols = math.max(1, cols - 3), pixel_width = math.max(1, cols - 3) * 18 } end } end,
      get_dimensions = function() return { pixel_width = cols * 18 } end,
      mux_window = function() return { tabs_with_info = function() return tabs end } end,
      set_left_status = function(_, text) left = text end,
      set_right_status = function(_, text) right = plain(text) end,
    })
    assert(left == '', 'tabs must start at the left edge')
    local clock_start = math.floor((cols - 12) / 2)
    if clock_start < tabs_width + 1 then
      assert(right == '', 'crowded tabs must hide the clock')
    else
      assert(right:find(' 17:07:02 ', 1, true) == 1)
      assert(cols - wezterm.column_width(right) == clock_start, 'clock must be centered')
    end
  end
end
wezterm.strftime = original_strftime
return config
