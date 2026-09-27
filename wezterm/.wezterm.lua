local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local mux = wezterm.mux

local target_triple = wezterm.target_triple:lower()
local is_windows = target_triple:find('windows') ~= nil
local is_macos = target_triple:find('darwin') ~= nil
-- Leave desktop margins on macOS; retain bounded geometry elsewhere.
local function launch_size(screen)
  if is_macos then
    return math.max(1, math.floor(screen.width * 0.94)), math.max(1, math.floor(screen.height * 0.88))
  end
  return math.min(1800, math.max(1, math.floor(screen.width * 0.88))),
    math.min(1200, math.max(1, math.floor(screen.height * 0.84)))
end

local function center_window(window, screen, width, height)
  window:set_inner_size(width, height)
  window:set_position(
    screen.x + math.max(0, math.floor((screen.width - width) / 2)),
    screen.y + math.max(0, math.floor((screen.height - height) / 2))
  )
end

wezterm.on('toggle-window-size', function(window)
  local dimensions = window:get_dimensions()
  -- Native fullscreen owns geometry until the user leaves it.
  if dimensions.is_full_screen then return end
  local screens = wezterm.gui.screens()
  local screen = screens.active or screens.main
  if not screen then return end
  local large_width, large_height = launch_size(screen)
  local small_width = math.max(1, math.floor(math.min(screen.width * 0.55, large_width * 0.70)))
  local small_height = math.max(1, math.floor(math.min(screen.height * 0.55, large_height * 0.70)))
  -- Derive the state from geometry so manual resizing and reloads stay sensible.
  local is_small = dimensions.pixel_width <= (small_width + large_width) / 2
    and dimensions.pixel_height <= (small_height + large_height) / 2
  window:restore()
  if is_small then
    center_window(window, screen, large_width, large_height)
  else
    center_window(window, screen, small_width, small_height)
  end
end)

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
config.cursor_thickness = '150%'
config.audible_bell = 'Disabled'
config.notification_handling = 'SuppressFromFocusedWindow'
config.scrollback_lines = 20000
config.hide_mouse_cursor_when_typing = true
config.switch_to_last_active_tab_when_closing_tab = true

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
-- Cell-based tabs keep the rounded labels aligned with the terminal font.
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_style = { new_tab = '', new_tab_hover = '' }
config.tab_max_width = 8
config.status_update_interval = is_macos and 250 or 1000
config.window_padding = { left = 28, right = 28, top = 24, bottom = 20 }
config.window_decorations = 'RESIZE'
config.window_frame = {
  border_left_width = '2px',
  border_right_width = '2px',
  border_top_height = '2px',
  border_bottom_height = '2px',
  border_left_color = '#c4a7e7',
  border_right_color = '#c4a7e7',
  border_top_color = '#c4a7e7',
  border_bottom_color = '#c4a7e7',
  font = platform_font('Bold'),
  active_titlebar_bg = 'rgba(35, 33, 54, 0.70)',
  inactive_titlebar_bg = 'rgba(35, 33, 54, 0.70)',
  active_titlebar_fg = '#e0def4',
  inactive_titlebar_fg = '#908caa',
  button_fg = '#e0def4',
  button_bg = 'rgba(35, 33, 54, 0.00)',
  button_hover_fg = '#191724',
  button_hover_bg = 'rgba(196, 167, 231, .85)',
}

config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}

config.colors = {
  background = '#191724',
  foreground = '#eeecff',
  cursor_bg = '#c4a7e7',
  cursor_fg = '#191724',
  selection_fg = '#191724',
  selection_bg = '#eb6f92',
  tab_bar = {
    background = '#191724',
    active_tab = { bg_color = '#191724', fg_color = '#e0def4', intensity = 'Normal' },
    inactive_tab = { bg_color = '#191724', fg_color = '#908caa' },
    inactive_tab_hover = { bg_color = '#191724', fg_color = '#e0def4' },
    new_tab = { bg_color = 'rgba(35, 33, 54, 0.45)', fg_color = '#908caa' },
    new_tab_hover = { bg_color = 'rgba(57, 53, 82, 0.70)', fg_color = '#e0def4' },
    inactive_tab_edge = '#191724',
  },
}

if is_windows then
  config.win32_system_backdrop = 'Acrylic'
  config.window_background_opacity = 0.7
  config.window_frame.font_size = 10.0
end

if is_macos then
  config.window_background_opacity = 0.7
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

local function macos_paste_clipboard()
  return wezterm.action_callback(function(window, pane)
    -- Inspect formats only. Codex reads the image itself when it receives Ctrl+V.
    -- Prefer text when an app also offers an image preview or a copied file URL.
    local called, success, kind = pcall(wezterm.run_child_process, {
      '/usr/bin/osascript', '-l', 'JavaScript', '-e', [[
        ObjC.import('AppKit');
        const types = ObjC.deepUnwrap($.NSPasteboard.generalPasteboard.types) || [];
        const images = ['public.png', 'public.tiff', 'public.jpeg'];
        const text = [
          'public.utf8-plain-text', 'public.utf16-plain-text',
          'public.utf16-external-plain-text', 'public.file-url'
        ];
        types.some(t => images.includes(t)) && !types.some(t => text.includes(t))
          ? 'image' : 'text';
      ]],
    })
    if called and success and kind:match('^image%s*$') then
      window:perform_action(wezterm.action.SendKey({ key = 'v', mods = 'CTRL' }), pane)
    else
      window:perform_action(wezterm.action.PasteFrom('Clipboard'), pane)
    end
  end)
end

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

-- Keep Control+Space available for completion and application shortcuts.
config.leader = { key = 'Space', mods = 'CTRL|SHIFT', timeout_milliseconds = 1500 }
if is_macos then
  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = true
end
config.keys = {
  { key = 'phys:Space', mods = 'CTRL|SHIFT', action = wezterm.action.DisableDefaultAssignment },
  {
    key = 'r',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ReloadConfiguration,
  },
  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SendKey({ key = 'f', mods = 'CTRL|SHIFT' }),
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
    action = wezterm.action.SendKey({ key = 'p', mods = 'CTRL|SHIFT' }),
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
    action = wezterm.action.ActivateTabRelative(-1),
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

-- Shared pane vocabulary: h/j/k/l focus, H/J/K/L resize, backslash/minus split.
for key, direction in pairs({ h = 'Left', j = 'Down', k = 'Up', l = 'Right' }) do
  table.insert(config.keys, { key = key, mods = 'LEADER', action = wezterm.action.ActivatePaneDirection(direction) })
  table.insert(config.keys, { key = key, mods = 'LEADER|SHIFT', action = wezterm.action.AdjustPaneSize({ direction, 5 }) })
end
local leader_bindings = {
  { key = 'm', action = wezterm.action.EmitEvent('toggle-window-size') },
  { key = 'n', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER|SHIFT', action = powershell_tab_action() },
  { key = '\\', action = wezterm.action.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
  { key = '-', action = wezterm.action.SplitVertical({ domain = 'CurrentPaneDomain' }) },
  { key = 'x', action = wezterm.action.CloseCurrentPane({ confirm = true }) },
  { key = 'z', action = wezterm.action.TogglePaneZoomState },
  { key = 'y', action = wezterm.action.ActivateCopyMode },
  { key = 'f', action = wezterm.action.Search({ CaseSensitiveString = '' }) },
  { key = 'q', action = wezterm.action.QuickSelect },
  { key = 'Space', action = wezterm.action.ActivateCommandPalette },
  { key = 'Enter', action = wezterm.action.ToggleFullScreen },
  { key = '=', action = wezterm.action.IncreaseFontSize },
  { key = '_', action = wezterm.action.DecreaseFontSize },
  { key = '0', action = wezterm.action.ResetFontSize },
}
for _, binding in ipairs(leader_bindings) do
  binding.mods = binding.mods or 'LEADER'
  table.insert(config.keys, binding)
end
-- Avoid host defaults stealing Pi navigation/undo or Neovim's terminal toggle.
for _, key in ipairs({ 'UpArrow', 'DownArrow' }) do
  table.insert(config.keys, {
    key = key,
    mods = 'CTRL|SHIFT',
    action = wezterm.action.SendKey({ key = key, mods = 'CTRL|SHIFT' }),
  })
end
for _, key in ipairs({ '-', '_' }) do
  table.insert(config.keys, { key = key, mods = 'CTRL', action = wezterm.action.SendKey({ key = key, mods = 'CTRL' }) })
  table.insert(config.keys, { key = key, mods = 'CTRL|SHIFT', action = wezterm.action.SendKey({ key = '_', mods = 'CTRL' }) })
end

if is_macos then
  local mac_key_bindings = {
    { key = '[', mods = 'CMD', action = wezterm.action.ActivateTabRelative(-1) },
    { key = 'm', mods = 'CMD|SHIFT', action = wezterm.action.EmitEvent('toggle-window-size') },
    { key = ']', mods = 'CMD', action = wezterm.action.ActivateTabRelative(1) },
    { key = 'w', mods = 'CMD', action = wezterm.action.CloseCurrentTab({ confirm = true }) },
    { key = 'UpArrow', mods = 'CMD', action = wezterm.action.SendKey({ key = 'Home', mods = 'CTRL' }) },
    { key = 'DownArrow', mods = 'CMD', action = wezterm.action.SendKey({ key = 'End', mods = 'CTRL' }) },
    {
      key = 'h',
      mods = 'CMD',
      action = wezterm.action.SendKey({ key = 'Home', mods = 'NONE' }),
    },
    {
      key = 'l',
      mods = 'CMD',
      action = wezterm.action.SendKey({ key = 'End', mods = 'NONE' }),
    },
    {
      key = 'c',
      mods = 'CMD',
      action = wezterm.action.CopyTo('Clipboard'),
    },
    {
      key = 'v',
      mods = 'CMD',
      action = macos_paste_clipboard(),
    },
    {
      key = 'LeftArrow',
      mods = 'ALT',
      action = wezterm.action.SendKey({ key = 'LeftArrow', mods = 'CTRL' }),
    },
    {
      key = 'RightArrow',
      mods = 'ALT',
      action = wezterm.action.SendKey({ key = 'RightArrow', mods = 'CTRL' }),
    },
    {
      key = 'LeftArrow',
      mods = 'CMD',
      action = wezterm.action.SendKey({ key = 'Home', mods = 'NONE' }),
    },
    {
      key = 'RightArrow',
      mods = 'CMD',
      action = wezterm.action.SendKey({ key = 'End', mods = 'NONE' }),
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

-- The macOS companion exchanges tab IDs only, never terminal text or commands.
local overlay_root = is_macos and wezterm.home_dir
  and (wezterm.home_dir .. '/.local/state/dotfiles/wezterm-floating-tabs/') or nil
local overlay_app = is_macos and wezterm.home_dir
  and (wezterm.home_dir .. '/Applications/WezTerm Floating Tabs.app') or nil
local overlay_available = false
if overlay_app then
  local file = io.open(overlay_app .. '/Contents/MacOS/wezterm-floating-tabs', 'rb')
  if file then file:close(); overlay_available = true end
end

local function overlay_title(window_id)
  if not wezterm.GLOBAL.floating_tabs_token then
    wezterm.GLOBAL.floating_tabs_token = tostring(os.time()) .. tostring({}):gsub('%W', '')
  end
  return 'WezTerm [' .. wezterm.GLOBAL.floating_tabs_token .. ':' .. tostring(window_id) .. ']'
end

local function overlay_key(window_id)
  overlay_title(window_id)
  return wezterm.GLOBAL.floating_tabs_token .. '-' .. tostring(window_id)
end

local function overlay_read(name)
  local file = io.open(overlay_root .. name, 'r')
  if not file then return nil end
  local text = file:read(65536)
  file:close()
  local ok, result = pcall(wezterm.json_parse, text or '')
  return ok and type(result) == 'table' and result or nil
end

local function overlay_fresh(reply, title)
  return reply and reply.title == title and type(reply.updated) == 'number'
    and math.abs(os.time() - reply.updated) < 3
end

local function publish_floating_tabs(window_id, tabs)
  local title = overlay_title(window_id)
  local now = os.time()
  local key = overlay_key(window_id)
  local signature = title .. wezterm.json_encode(tabs)
  -- Title formatting also runs for unrelated terminal output. Publish only tab
  -- changes, with a one-second heartbeat so an idle window remains live.
  if wezterm.GLOBAL['floating_tabs_signature_' .. key] == signature
    and wezterm.GLOBAL['floating_tabs_published_' .. key] == now then return end
  local temporary = overlay_root .. 'window-' .. key .. '.tmp'
  local file = io.open(temporary, 'w')
  if not file then return end
  file:write(wezterm.json_encode({ key = key, title = title, updated = now, tabs = tabs }))
  file:close()
  if os.rename(temporary, overlay_root .. 'window-' .. key .. '.json') then
    wezterm.GLOBAL['floating_tabs_signature_' .. key] = signature
    wezterm.GLOBAL['floating_tabs_published_' .. key] = now
  end
end

local function update_floating_tabs(window)
  if not overlay_available then return end
  local key = overlay_key(window:mux_window():window_id())
  local title = overlay_title(window:mux_window():window_id())
  if not wezterm.GLOBAL.floating_tabs_started then
    wezterm.GLOBAL.floating_tabs_started = true
    wezterm.background_child_process({ '/usr/bin/open', '-g', overlay_app })
  end
  local request = overlay_read('activate-' .. key .. '.json')
  if request and request.title == title then
    os.remove(overlay_root .. 'activate-' .. key .. '.json')
    if overlay_fresh(request, title) then
      for _, tab in ipairs(window:mux_window():tabs_with_info()) do
        if tab.tab:tab_id() == request.tab_id then
          window:perform_action(wezterm.action.ActivateTab(tab.index), window:active_pane())
          break
        end
      end
    end
  end
  -- Snapshot after handling a click, not before activating its destination.
  local tabs = {}
  for _, tab in ipairs(window:mux_window():tabs_with_info()) do
    table.insert(tabs, { id = tab.tab:tab_id(), index = tab.index, active = tab.is_active })
  end
  publish_floating_tabs(window:mux_window():window_id(), tabs)
  local ready = overlay_fresh(overlay_read('ready-' .. key .. '.json'), title)
  local overrides = window:get_config_overrides() or {}
  local show_native = not ready
  if overrides.enable_tab_bar ~= show_native then
    overrides.enable_tab_bar = show_native
    window:set_config_overrides(overrides)
  end
end

wezterm.on('format-window-title', function(tab, _, tabs)
  if overlay_available and tab then
    local mux_tab = wezterm.mux.get_tab(tab.tab_id)
    local window = mux_tab and mux_tab:window()
    if window then
      local snapshot = {}
      for _, item in ipairs(tabs) do
        table.insert(snapshot, { id = item.tab_id, index = item.tab_index, active = item.is_active })
      end
      publish_floating_tabs(window:window_id(), snapshot)
      return overlay_title(window:window_id())
    end
  end
  return ' '
end)

-- Native numbered tabs keep the top-left corner compact without a plugin.
local bar_background = config.colors.tab_bar.background
local function capsule(text, foreground, background)
  return {
    { Attribute = { Intensity = 'Bold' } },
    { Background = { Color = bar_background } },
    { Foreground = { Color = background } },
    { Text = '' },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = text },
    { Background = { Color = bar_background } },
    { Foreground = { Color = background } },
    { Text = '' },
    { Attribute = { Intensity = 'Normal' } },
  }
end

wezterm.on('format-tab-title', function(tab, _, _, _, hover, max_width)
  local label = tostring(tab.tab_index + 1)
  if max_width < #label + 2 then
    return wezterm.truncate_right(label, math.max(0, max_width))
  end
  return capsule(label, tab.is_active and '#191724' or '#e0def4',
    tab.is_active and '#c4a7e7' or (hover and '#6e6a86' or '#393552'))
end)

wezterm.on('update-status', function(window)
  update_floating_tabs(window)
  window:set_left_status('')
  local size = window:active_tab():get_size()
  -- The tab bar spans the full window, including terminal padding.
  local cell_width = size.pixel_width / math.max(1, size.cols)
  local cols = cell_width > 0 and math.floor(window:get_dimensions().pixel_width / cell_width) or size.cols
  local tabs_width = 0
  for _, tab in ipairs(window:mux_window():tabs_with_info()) do
    tabs_width = tabs_width + #tostring(tab.index + 1) + 2
  end
  local clock = ' ' .. wezterm.strftime('%H:%M:%S') .. ' '
  local clock_width = wezterm.column_width(clock) + 2
  local clock_start = math.floor((cols - clock_width) / 2)
  -- Hide the clock when tabs reach the center, rather than clipping its digits.
  if clock_start < tabs_width + 1 then
    window:set_right_status('')
    return
  end
  local items = capsule(clock, '#191724', '#c4a7e7')
  table.insert(items, { Text = string.rep(' ', cols - clock_start - clock_width) })
  window:set_right_status(wezterm.format(items))
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
  if not gui_window then
    return
  end

  local screens = wezterm.gui.screens()
  local screen = screens.active or screens.main

  if not screen then
    return
  end

  local width, height = launch_size(screen)

  center_window(gui_window, screen, width, height)
end)
return config
