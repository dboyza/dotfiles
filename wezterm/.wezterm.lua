local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local mux = wezterm.mux

local is_windows = os.getenv('OS') and os.getenv('OS'):lower():find('windows')
local is_macos = wezterm.target_triple:lower():find('darwin') ~= nil
local launch_width = 1800
local launch_height = 1200

-- ui
config.color_scheme = 'rose-pine-moon'
config.max_fps = 120
config.font = wezterm.font('Hack Nerd Font', { weight = 'Regular' })
config.font_size = 12
config.adjust_window_size_when_changing_font_size = false
config.initial_cols = 140
config.initial_rows = 36
config.default_cursor_style = 'SteadyBar'
config.audible_bell = 'Disabled'
config.enable_csi_u_key_encoding = true

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'RESIZE'
config.window_frame = {
  font = wezterm.font('Hack Nerd Font', { weight = 'Bold' }),
  active_titlebar_bg = 'rgba(35, 33, 54, 0.70)',
  inactive_titlebar_bg = 'rgba(35, 33, 54, 0.70)',
  active_titlebar_fg = '#e0def4',
  inactive_titlebar_fg = '#908caa',
  button_fg = '#e0def4',
  button_bg = 'rgba(35, 33, 54, 0.00)',
  button_hover_fg = '#191724',
  button_hover_bg = 'rgba(196, 167, 231, 0.85)',
}

config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}

config.colors = {
  cursor_bg = '#c4a7e7',
  cursor_fg = '#191724',
  selection_fg = '#191724',
  selection_bg = '#eb6f92',
  tab_bar = {
    background = 'rgba(35, 33, 54, 0.70)',
    active_tab = { bg_color = 'rgba(57, 53, 82, 0.70)', fg_color = '#e0def4' },
    inactive_tab = { bg_color = 'rgba(35, 33, 54, 0.45)', fg_color = '#908caa' },
    inactive_tab_hover = { bg_color = 'rgba(57, 53, 82, 0.70)', fg_color = '#e0def4' },
    new_tab = { bg_color = 'rgba(35, 33, 54, 0.45)', fg_color = '#908caa' },
    new_tab_hover = { bg_color = 'rgba(57, 53, 82, 0.70)', fg_color = '#e0def4' },
    inactive_tab_edge = 'rgba(35, 33, 54, 0.70)',
  },
}

if is_windows then
  config.win32_system_backdrop = 'Acrylic'
  config.window_background_opacity = 0.7
  config.window_frame.font_size = 10.0
end

if is_macos then
  config.window_background_opacity = 0.8
  config.macos_window_background_blur = 50
  config.font_size = 15.0
  config.window_frame.font_size = 13.0
end

-- shell
local function preferred_wsl_domain()
  if not is_windows then
    return nil
  end

  local ok, domains = pcall(wezterm.default_wsl_domains)
  if not ok then
    return nil
  end

  for _, domain in ipairs(domains) do
    if domain.name == 'WSL:Ubuntu-24.04' then
      return domain.name
    end
  end

  return domains[1] and domains[1].name or nil
end

local wsl_domain = preferred_wsl_domain()
if wsl_domain then
  config.default_domain = wsl_domain
end

-- keys

config.leader = { key = 'Space', mods = 'CTRL' }
config.keys = {
  {
    key = 'r',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ReloadConfiguration,
  },
  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Search({ CaseSensitiveString = '' }),
  },
  {
    key = 'k',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ClearScrollback('ScrollbackOnly'),
  },
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.ToggleFullScreen,
  },
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SpawnTab('CurrentPaneDomain'),
  },
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab({ confirm = true }),
  },
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CopyTo('Clipboard'),
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom('Clipboard'),
  },
  {
    key = 'Insert',
    mods = 'CTRL',
    action = wezterm.action.CopyTo('Clipboard'),
  },
  {
    key = 'Insert',
    mods = 'SHIFT',
    action = wezterm.action.PasteFrom('Clipboard'),
  },
  {
    key = 'UpArrow',
    mods = 'CTRL',
    action = wezterm.action.ScrollByLine(-5),
  },
  {
    key = 'DownArrow',
    mods = 'CTRL',
    action = wezterm.action.ScrollByLine(5),
  },
  {
    key = 'v',
    mods = 'CMD',
    action = wezterm.action({ PasteFrom = 'Clipboard' }),
  },
  {
    key = 'c',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab('CurrentPaneDomain'),
  },
  {
    key = 'PageUp',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ScrollByLine(-1),
  },
  {
    key = 'PageDown',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ScrollByLine(1),
  },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.Multiple({
      wezterm.action.ClearSelection,
      wezterm.action.PasteFrom('Clipboard'),
    }),
  },
}

wezterm.on('format-window-title', function()
  return ' '
end)
wezterm.on('gui-startup', function(cmd)
  local _tab, _pane, window = mux.spawn_window(cmd or {})
  local gui_window = window:gui_window()
  local screen = wezterm.gui.screens().active

  gui_window:set_inner_size(launch_width, launch_height)
  gui_window:set_position(
    screen.x + math.max(0, math.floor((screen.width - launch_width) / 2)),
    screen.y + math.max(0, math.floor((screen.height - launch_height) / 2))
  )
end)
return config
