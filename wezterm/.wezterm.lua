local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local mux = wezterm.mux

local target_triple = wezterm.target_triple:lower()
local is_windows = target_triple:find('windows') ~= nil
local is_macos = target_triple:find('darwin') ~= nil
local launch_max_width = is_macos and 2100 or 1800
local launch_max_height = is_macos and 1400 or 1200
local launch_width_ratio = is_macos and 0.92 or 0.88
local launch_height_ratio = is_macos and 0.88 or 0.84

local function launch_size(screen)
  return math.min(launch_max_width, math.max(1, math.floor(screen.width * launch_width_ratio))),
    math.min(launch_max_height, math.max(1, math.floor(screen.height * launch_height_ratio)))
end

local function platform_font(weight)
  local fonts = {
    { family = 'Hack Nerd Font', weight = weight },
  }

  if is_windows then
    table.insert(fonts, { family = 'Cascadia Mono', weight = weight })
    table.insert(fonts, { family = 'Consolas', weight = weight })
  elseif is_macos then
    table.insert(fonts, { family = 'Menlo', weight = weight })
  else
    table.insert(fonts, { family = 'DejaVu Sans Mono', weight = weight })
  end

  return wezterm.font_with_fallback(fonts)
end

local function command_exists(program)
  local probe
  if is_windows then
    probe = { 'where.exe', program }
  else
    probe = { '/bin/sh', '-c', 'command -v "$1" >/dev/null 2>&1', 'sh', program }
  end

  local called, found = pcall(function()
    local success = wezterm.run_child_process(probe)
    return success
  end)
  return called and found
end

-- ui
config.color_scheme = 'rose-pine-moon'
config.max_fps = 120
config.font = platform_font('Regular')
config.font_size = 12
config.adjust_window_size_when_changing_font_size = false
config.initial_cols = 140
config.initial_rows = 36
config.default_cursor_style = 'SteadyBar'
config.audible_bell = 'Disabled'
config.notification_handling = 'SuppressFromFocusedWindow'
config.scrollback_lines = 20000
config.hide_mouse_cursor_when_typing = true
config.switch_to_last_active_tab_when_closing_tab = true

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = 'RESIZE'
config.window_frame = {
  font = platform_font('Bold'),
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
  config.window_background_opacity = 0.8
  config.window_frame.font_size = 10.0
end

if is_macos then
  config.window_background_opacity = 0.8
  config.macos_window_background_blur = 50
  config.font_size = 15.0
  config.window_frame.font_size = 13.0
end

-- shell
local function resolve_wsl_home(distribution)
  if not distribution then
    return nil
  end

  local called, success, stdout = pcall(function()
    return wezterm.run_child_process({
      'wsl.exe',
      '--distribution',
      distribution,
      '--exec',
      'printenv',
      'HOME',
    })
  end)
  if not called or not success then
    return nil
  end

  local home = stdout:match('^%s*(.-)%s*$')
  if home == '' or home:sub(1, 1) ~= '/' then
    return nil
  end

  return home
end

local function preferred_wsl_domain()
  if not is_windows then
    return nil, nil
  end

  local ok, domains = pcall(wezterm.default_wsl_domains)
  if not ok then
    return nil, nil
  end

  local selected = domains[1]
  for _, domain in ipairs(domains) do
    if domain.name == 'WSL:Ubuntu-24.04' then
      selected = domain
      break
    end
  end

  if not selected then
    return nil, nil
  end

  local home = resolve_wsl_home(selected.distribution)
  if home then
    selected.default_cwd = home
    config.wsl_domains = domains
  end

  return selected.name, home
end

local wsl_domain, wsl_home = preferred_wsl_domain()
local powershell_prog
if is_windows then
  if command_exists('pwsh.exe') then
    powershell_prog = { 'pwsh.exe', '-NoLogo' }
  else
    powershell_prog = { 'powershell.exe', '-NoLogo' }
  end
elseif command_exists('pwsh') then
  powershell_prog = { 'pwsh', '-NoLogo' }
end

if wsl_domain then
  config.default_domain = wsl_domain
elseif is_windows then
  config.default_prog = powershell_prog
end

local function wsl_spawn_command()
  if not wsl_domain then
    return nil
  end

  local spawn = { domain = { DomainName = wsl_domain } }
  if wsl_home then
    spawn.cwd = wsl_home
  end
  return spawn
end

local function wsl_tab_action()
  local spawn = wsl_spawn_command()
  if spawn then
    return wezterm.action.SpawnCommandInNewTab(spawn)
  end

  return wezterm.action.SpawnTab('DefaultDomain')
end

local function powershell_tab_action()
  if powershell_prog then
    local spawn = {
      domain = { DomainName = 'local' },
      args = powershell_prog,
    }
    local home = is_windows and os.getenv('USERPROFILE') or os.getenv('HOME')
    if home then
      spawn.cwd = home
    end
    return wezterm.action.SpawnCommandInNewTab(spawn)
  end

  return wezterm.action.SpawnTab('DefaultDomain')
end

-- keys

local function copy_or_send_to_shell()
  return wezterm.action_callback(function(window, pane)
    local selection = window:get_selection_text_for_pane(pane)

    if selection and selection ~= '' then
      window:perform_action(wezterm.action.CopyTo('Clipboard'), pane)
      return
    end

    local ok, domain_name = pcall(function()
      return pane:get_domain_name()
    end)

    if not is_windows or (ok and type(domain_name) == 'string' and domain_name:match('^WSL:')) then
      window:perform_action(wezterm.action.SendString('\x1b[99;6u'), pane)
      return
    end

    window:perform_action(wezterm.action.SendKey({ key = 'c', mods = 'CTRL|SHIFT' }), pane)
  end)
end

local function foreground_process_basename(pane)
  local name = pane:get_foreground_process_name() or ''
  return name:match('([^/\\]+)$') or name
end

local function should_send_scroll_key(pane)
  local ok, in_alt_screen = pcall(function()
    return pane:is_alt_screen_active()
  end)
  local title = pane:get_title() or ''
  return (ok and in_alt_screen) or title:match('^tmux:') ~= nil or foreground_process_basename(pane):match('^tmux') ~= nil
end

local function scroll_or_send_key(key, mods, scroll_action)
  return wezterm.action_callback(function(window, pane)
    if should_send_scroll_key(pane) then
      window:perform_action(wezterm.action.SendKey({ key = key, mods = mods }), pane)
    else
      window:perform_action(scroll_action, pane)
    end
  end)
end

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
    action = wezterm.action.SendString('\x1b[13;3u'),
  },
  {
    key = 'F11',
    mods = 'NONE',
    action = wezterm.action.ToggleFullScreen,
  },
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = wsl_tab_action(),
  },
  {
    key = 'p',
    mods = 'CTRL|SHIFT',
    action = powershell_tab_action(),
  },
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab({ confirm = true }),
  },
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = copy_or_send_to_shell(),
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
    action = wezterm.action.SendKey({ key = 'UpArrow', mods = 'CTRL' }),
  },
  {
    key = 'DownArrow',
    mods = 'CTRL',
    action = wezterm.action.SendKey({ key = 'DownArrow', mods = 'CTRL' }),
  },
  {
    key = 'LeftArrow',
    mods = 'CTRL',
    action = wezterm.action.SendKey({ key = 'LeftArrow', mods = 'CTRL' }),
  },
  {
    key = 'RightArrow',
    mods = 'CTRL',
    action = wezterm.action.SendKey({ key = 'RightArrow', mods = 'CTRL' }),
  },
  {
    key = 'LeftArrow',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SendKey({ key = 'LeftArrow', mods = 'CTRL|SHIFT' }),
  },
  {
    key = 'RightArrow',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SendKey({ key = 'RightArrow', mods = 'CTRL|SHIFT' }),
  },
  {
    key = 'LeftArrow',
    mods = 'SHIFT',
    action = wezterm.action.SendKey({ key = 'LeftArrow', mods = 'SHIFT' }),
  },
  {
    key = 'RightArrow',
    mods = 'SHIFT',
    action = wezterm.action.SendKey({ key = 'RightArrow', mods = 'SHIFT' }),
  },
  {
    key = 'c',
    mods = 'LEADER',
    action = wsl_tab_action(),
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = powershell_tab_action(),
  },
  {
    key = 'PageUp',
    mods = 'NONE',
    action = scroll_or_send_key('PageUp', 'NONE', wezterm.action.ScrollByPage(-1)),
  },
  {
    key = 'PageDown',
    mods = 'NONE',
    action = scroll_or_send_key('PageDown', 'NONE', wezterm.action.ScrollByPage(1)),
  },
  {
    key = 'PageUp',
    mods = 'CTRL',
    action = scroll_or_send_key('PageUp', 'CTRL', wezterm.action.ScrollByLine(-1)),
  },
  {
    key = 'PageDown',
    mods = 'CTRL',
    action = scroll_or_send_key('PageDown', 'CTRL', wezterm.action.ScrollByLine(1)),
  },
}

if is_macos then
  local mac_key_bindings = {
    {
      key = 'c',
      mods = 'CMD',
      action = wezterm.action.CopyTo('Clipboard'),
    },
    {
      key = 'v',
      mods = 'CMD',
      action = wezterm.action.PasteFrom('Clipboard'),
    },
    {
      key = 'UpArrow',
      mods = 'CMD|SHIFT',
      action = scroll_or_send_key('PageUp', 'NONE', wezterm.action.ScrollByPage(-1)),
    },
    {
      key = 'DownArrow',
      mods = 'CMD|SHIFT',
      action = scroll_or_send_key('PageDown', 'NONE', wezterm.action.ScrollByPage(1)),
    },
    {
      key = 'UpArrow',
      mods = 'CMD|ALT',
      action = scroll_or_send_key('PageUp', 'CTRL', wezterm.action.ScrollByLine(-1)),
    },
    {
      key = 'DownArrow',
      mods = 'CMD|ALT',
      action = scroll_or_send_key('PageDown', 'CTRL', wezterm.action.ScrollByLine(1)),
    },
  }

  for _, binding in ipairs(mac_key_bindings) do
    table.insert(config.keys, binding)
  end
end

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

wezterm.on('new-tab-button-click', function(window, pane, button)
  if button == 'Left' then
    window:perform_action(wsl_tab_action(), pane)
    return false
  end
end)
wezterm.on('gui-startup', function(cmd)
  local spawn_cmd = cmd
  if not spawn_cmd then
    spawn_cmd = wsl_spawn_command()
  end

  local _tab, _pane, window = mux.spawn_window(spawn_cmd or {})
  local gui_window = window:gui_window()
  local screens = wezterm.gui.screens()
  local screen = screens.active or screens.main

  if not gui_window or not screen then
    return
  end

  local width, height = launch_size(screen)

  gui_window:set_inner_size(width, height)
  gui_window:set_position(
    screen.x + math.max(0, math.floor((screen.width - width) / 2)),
    screen.y + math.max(0, math.floor((screen.height - height) / 2))
  )
end)
return config
