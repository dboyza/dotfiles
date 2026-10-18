-- Set fonts, colors, transparency, padding, and the native tab bar and window frame.
return function(wezterm, config, platform, palette)
  local is_windows, is_macos = platform.is_windows, platform.is_macos

  -- Section: Fonts
  -- JetBrains Mono Nerd Font leads; each platform falls back to a monospace font and its color emoji font.
  local families = { 'JetBrainsMono Nerd Font' }
  local fallbacks = is_windows and { 'Cascadia Mono', 'Consolas', 'Segoe UI Emoji' }
    or is_macos and { 'Menlo', 'Apple Color Emoji' }
    or { 'DejaVu Sans Mono', 'Noto Color Emoji' }
  for _, family in ipairs(fallbacks) do table.insert(families, family) end

  -- Every style resolves through the same fallback stack, so bold or italic text never loses a glyph.
  local function stack(style)
    local fonts = {}
    for _, family in ipairs(families) do
      table.insert(fonts, { family = family, weight = style.weight, italic = style.italic })
    end
    return wezterm.font_with_fallback(fonts)
  end
  config.font = stack({})
  config.font_rules = {
    { intensity = 'Bold', italic = false, font = stack({ weight = 'Bold' }) },
    { intensity = 'Bold', italic = true, font = stack({ weight = 'Bold', italic = true }) },
    { intensity = 'Normal', italic = true, font = stack({ italic = true }) },
    -- Dim text (SGR 2) is a lighter weight rather than a darker color.
    { intensity = 'Half', italic = false, font = stack({ weight = 'Light' }) },
    { intensity = 'Half', italic = true, font = stack({ weight = 'Light', italic = true }) },
  }
  config.font_size = 12
  config.line_height = 1.1
  -- Ligatures off: operators render exactly as typed in shells, diffs, and editors.
  config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

  -- Section: Rendering
  -- WebGpu draws through Metal and DirectX 12; Linux keeps OpenGL because driver support varies there.
  if is_macos or is_windows then config.front_end = 'WebGpu' end
  -- WezTerm paces frames on its own timer; a cap equal to the 120 Hz refresh misses vsync and halves to 60.
  -- A higher cap lets every refresh present (measured with the Metal HUD); the display still limits the rate.
  config.max_fps = 240
  -- Easing effects (the visual bell fade) default to 10 fps; match the display rate.
  config.animation_fps = 120

  -- Section: Terminal behavior
  config.initial_cols = 140
  config.initial_rows = 36
  config.scrollback_lines = 20000
  config.adjust_window_size_when_changing_font_size = false
  config.switch_to_last_active_tab_when_closing_tab = true
  -- A terminal bell (BEL) briefly tints the background instead of making a sound.
  config.audible_bell = 'Disabled'
  config.visual_bell = {
    target = 'BackgroundColor',
    fade_in_function = 'EaseIn',
    fade_in_duration_ms = 60,
    fade_out_function = 'EaseOut',
    fade_out_duration_ms = 180,
  }
  config.notification_handling = 'SuppressFromFocusedWindow'
  config.default_cursor_style = 'SteadyBlock'
  -- Show images from Kitty-protocol programs such as yazi and Neovim image plugins.
  config.enable_kitty_graphics = true

  -- Section: Colors
  -- The scheme supplies the ANSI palette; the overrides deepen the background and brighten text.
  config.color_scheme = 'rose-pine-moon'
  config.colors = {
    background = palette.deep,
    foreground = palette.bright,
    cursor_bg = palette.cursor,
    cursor_fg = palette.deep,
    cursor_border = palette.cursor,
    selection_fg = palette.deep,
    selection_bg = palette.love,
    -- Pane dividers and the scrollbar follow the theme instead of WezTerm's defaults.
    split = palette.overlay,
    scrollbar_thumb = palette.overlay,
    visual_bell = palette.overlay,
    tab_bar = {
      background = palette.deep,
      active_tab = { bg_color = palette.deep, fg_color = palette.text, intensity = 'Normal' },
      inactive_tab = { bg_color = palette.deep, fg_color = palette.subtle },
      inactive_tab_hover = { bg_color = palette.deep, fg_color = palette.text },
    },
  }
  config.inactive_pane_hsb = { saturation = 0.0, brightness = 0.5 }
  -- Match the command palette (prefix Space) to the theme instead of WezTerm's default grey.
  config.command_palette_bg_color = palette.base
  config.command_palette_fg_color = palette.text
  config.command_palette_font_size = is_macos and 15.0 or 12.0

  -- Section: Window frame and padding
  -- macOS nightly squares the window corners so the 1px border runs edge to edge.
  config.window_decorations = is_macos and 'RESIZE|MACOS_FORCE_SQUARE_CORNERS' or 'RESIZE'
  config.window_padding = { left = 36, right = 36, top = 32, bottom = 28 }
  config.enable_scroll_bar = true
  -- Windows' DWM draws its own rounded border; a client-side rectangle would square off the corners.
  local border_width = is_windows and '0px' or '1px'
  config.window_frame = {
    border_left_width = border_width,
    border_right_width = border_width,
    border_top_height = border_width,
    border_bottom_height = border_width,
    border_left_color = palette.subtle,
    border_right_color = palette.subtle,
    border_top_color = palette.subtle,
    border_bottom_color = palette.subtle,
  }

  -- Section: Native tab bar
  -- Tabs stay at the top, even with one tab; the companion hides this bar only when it is running.
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = false
  config.show_new_tab_button_in_tab_bar = false
  config.tab_max_width = 16
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
