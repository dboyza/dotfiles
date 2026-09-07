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
for _, title in ipairs({ 'shell', 'a very long project name with spaces', '日本語のプロジェクト', '🌲 café', '' }) do
  for width = 0, 24 do
    local result = format_title({ tab_index = 0, tab_title = title, active_pane = { title = 'fallback' } }, {}, {}, config, false, width)
    assert(wezterm.column_width(result[1].Text) == width, 'tab label must fill its allocated cells')
  end
end
local custom = format_title({ tab_index = 0, tab_title = 'custom', active_pane = { title = 'fallback' } }, {}, {}, config, false, 24)
assert(custom[1].Text:find('custom', 1, true), 'explicit tab title must win')

for _, cols in ipairs({ 1, 20, 80, 140, 240 }) do
  for count = 1, 12 do
    local padding
    local tabs = {}
    for index = 1, count do
      tabs[index] = {}
    end
    local window = {
      active_tab = function()
        return { get_size = function() return { cols = cols, pixel_width = cols * 10 } end }
      end,
      get_dimensions = function() return { pixel_width = cols * 10 } end,
      mux_window = function() return { tabs = function() return tabs end } end,
      set_left_status = function(_, text) padding = #text end,
    }
    callbacks['update-status'](window)
    local rendered_width = math.min(24, math.floor(math.max(0, cols - count + 1) / count))
    local right = cols - padding - count * rendered_width
    assert(math.abs(padding - right) <= 1, 'tab row must have balanced margins')
  end
end

return config
