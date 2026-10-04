-- Set fonts, colors, transparency, padding, and base frame styling.
return function(wezterm, config, platform)
  local is_windows, is_macos = platform.is_windows, platform.is_macos
  -- Section: Platform font fallback
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
  -- ui
  -- Section: Shared appearance
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

  -- Section: Native tab bar and window frame
  config.enable_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = false
  -- Cell-based tabs keep the rounded labels aligned with the terminal font.
  config.use_fancy_tab_bar = false
  config.show_new_tab_button_in_tab_bar = false
  config.tab_bar_style = { new_tab = '', new_tab_hover = '' }
  config.tab_max_width = 8
  config.status_update_interval = is_macos and 250 or 1000
  config.window_padding = { left = 36, right = 36, top = 32, bottom = 28 }
  config.window_decorations = 'RESIZE'
  -- Windows' DWM border follows its rounded corners. A client-side rectangle
  -- would sit inside that frame with square corners, even when DWM rounds it.
  local frame_border = is_windows and '0px' or '1px'
  config.window_frame = {
    border_left_width = frame_border,
    border_right_width = frame_border,
    border_top_height = frame_border,
    border_bottom_height = frame_border,
    border_left_color = '#908caa',
    border_right_color = '#908caa',
    border_top_color = '#908caa',
    border_bottom_color = '#908caa',
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

  -- Section: Terminal palette
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

  -- Section: Host transparency and font sizing
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
end
