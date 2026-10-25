-- Center startup windows and toggle bounded sizes without changing native fullscreen.
return function(wezterm, platform)
  local is_macos = platform.is_macos

  -- Section: Bounded sizes and centering
  -- macOS leaves desktop margins; other platforms cap the size on very large displays.
  local function launch_size(screen)
    if is_macos then
      return math.max(1, math.floor(screen.width * 0.94)), math.max(1, math.floor(screen.height * 0.88))
    end
    return math.min(1800, math.max(1, math.floor(screen.width * 0.88))),
      math.min(1200, math.max(1, math.floor(screen.height * 0.84)))
  end

  local function active_screen()
    local screens = wezterm.gui.screens()
    return screens.active or screens.main
  end

  local function center_window(window, screen, width, height)
    window:set_inner_size(width, height)
    window:set_position(
      screen.x + math.max(0, math.floor((screen.width - width) / 2)),
      screen.y + math.max(0, math.floor((screen.height - height) / 2))
    )
  end

  -- Section: Interactive size toggle
  wezterm.on('toggle-window-size', function(window)
    local dimensions = window:get_dimensions()
    -- Native fullscreen owns geometry until the user leaves it.
    if dimensions.is_full_screen then return end
    local screen = active_screen()
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

  -- Section: Initial window placement
  wezterm.on('gui-startup', function(cmd)
    local _, _, window = wezterm.mux.spawn_window(cmd or platform.spawn_command() or {})
    local gui_window = window:gui_window()
    local screen = active_screen()
    if not gui_window or not screen then return end
    center_window(gui_window, screen, launch_size(screen))
  end)
end
