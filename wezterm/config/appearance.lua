-- Set fonts, colors, transparency, padding, and the native tab bar and window frame.
return function(wezterm, config, platform, palette)
  local is_windows, is_macos = platform.is_windows, platform.is_macos

  -- Section: Fonts
  -- Hack Nerd Font leads; each platform falls back to a monospace font it ships.
  local fonts = { 'Hack Nerd Font' }
  local fallbacks = is_windows and { 'Cascadia Mono', 'Consolas' }
    or is_macos and { 'Menlo' }
    or { 'DejaVu Sans Mono' }
  for _, family in ipairs(fallbacks) do table.insert(fonts, family) end
  config.font = wezterm.font_with_fallback(fonts)
  config.font_size = 12

  -- Section: Terminal behavior
  config.max_fps = 120
  config.initial_cols = 140
  config.initial_rows = 36
  config.scrollback_lines = 20000
  config.adjust_window_size_when_changing_font_size = false
  config.switch_to_last_active_tab_when_closing_tab = true
  config.audible_bell = 'Disabled'
  config.notification_handling = 'SuppressFromFocusedWindow'
  config.default_cursor_style = 'SteadyBlock'

  -- Section: Colors
  -- The scheme supplies the ANSI palette; the overrides deepen the background and brighten text.
  config.color_scheme = 'rose-pine-moon'
  config.colors = {
    background = palette.background,
    foreground = palette.foreground,
    cursor_bg = palette.cursor,
    cursor_fg = palette.base,
    cursor_border = palette.cursor,
    selection_fg = palette.base,
    selection_bg = palette.selection,
    tab_bar = {
      background = palette.base,
      active_tab = { bg_color = palette.base, fg_color = palette.text, intensity = 'Normal' },
      inactive_tab = { bg_color = palette.base, fg_color = palette.muted },
      inactive_tab_hover = { bg_color = palette.base, fg_color = palette.text },
    },
  }
  config.inactive_pane_hsb = { saturation = 0.0, brightness = 0.5 }

  -- Section: Window frame and padding
  config.window_decorations = 'RESIZE'
  config.window_padding = { left = 36, right = 36, top = 32, bottom = 28 }
  -- Windows' DWM draws its own rounded border; a client-side rectangle would square off the corners.
  local border_width = is_windows and '0px' or '1px'
  config.window_frame = {
    border_left_width = border_width,
    border_right_width = border_width,
    border_top_height = border_width,
    border_bottom_height = border_width,
    border_left_color = palette.muted,
    border_right_color = palette.muted,
    border_top_color = palette.muted,
    border_bottom_color = palette.muted,
  }

  -- Section: Native tab bar
  -- Tabs stay at the top, even with one tab; the companion hides this bar only when it is running.
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = false
  config.show_new_tab_button_in_tab_bar = false
  config.tab_max_width = 8
  config.status_update_interval = is_macos and 250 or 1000

  -- Section: Host transparency and font sizing
  if is_windows then
    config.win32_system_backdrop = 'Acrylic'
    config.window_background_opacity = 0.7
  elseif is_macos then
    config.window_background_opacity = 0.7
    config.macos_window_background_blur = 50
    config.font_size = 15.0
  end
end
