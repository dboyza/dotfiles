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

for _, title in ipairs({ 'shell', 'a very long project name with spaces', '日本語のプロジェクト', '🌲 café', '' }) do
  for width = 0, config.tab_max_width do
    for _, state in ipairs({ { active = true }, { active = false }, { active = false, hover = true } }) do
      local result = format_title({ tab_index = 0, tab_title = title, is_active = state.active, active_pane = { title = 'fallback' } }, {}, {}, config, state.hover, width)
      assert(wezterm.column_width(label_text(result)) == width, 'rounded tab must fill its allocated cells')
      wezterm.format(result) -- Validate the formatting against WezTerm's real API.
    end
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
    tab_title = fixture.title,
    active_pane = { title = fixture.pane_title or 'fallback', current_working_dir = fixture.cwd },
  }, {}, {}, config, false, config.tab_max_width)
  assert(label_text(result):find(fixture.expected, 1, true), 'tab must display ' .. fixture.expected)
end

local url = wezterm.url.parse('file:///work/project%20name')
local result = format_title({ tab_index = 11, active_pane = { current_working_dir = url } }, {}, {}, config, false, config.tab_max_width)
assert(label_text(result):find('12  project name', 1, true), 'URL objects must produce readable numbered names')

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
    local rendered_width = math.min(config.tab_max_width, math.floor(math.max(0, cols - count + 1) / count))
    local right = cols - padding - count * rendered_width
    assert(math.abs(padding - right) <= 1, 'tab row must have balanced margins')
  end
end

return config
