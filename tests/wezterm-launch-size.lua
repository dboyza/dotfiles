local config_path = assert(arg[1], 'expected the WezTerm config path')

local function verify_launch_geometry(
  target_triple,
  screen,
  expected_width,
  expected_height,
  expected_x,
  expected_y
)
  local callbacks = {}
  local maximized = false
  local actual_width
  local actual_height
  local actual_x
  local actual_y

  local gui_window = {}
  function gui_window:get_dimensions()
    return { pixel_width = actual_width, pixel_height = actual_height, is_full_screen = self.fullscreen }
  end
  function gui_window:restore() end
  function gui_window:maximize()
    maximized = true
  end
  function gui_window:set_inner_size(width, height)
    actual_width = width
    actual_height = height
  end
  function gui_window:set_position(x, y)
    actual_x = x
    actual_y = y
  end

  local mux_window = {}
  function mux_window:gui_window()
    return gui_window
  end

  local action = setmetatable({}, {
    __index = function()
      return function(value)
        return value
      end
    end,
  })

  local wezterm = {
    action = action,
    action_callback = function(callback)
      return callback
    end,
    plugin = { require = function() return { setup = function() end } end },
    config_builder = function()
      return {}
    end,
    default_wsl_domains = function()
      return {}
    end,
    font_with_fallback = function(fonts)
      return fonts
    end,
    gui = {
      screens = function()
        return { active = screen, main = screen }
      end,
    },
    mux = {
      spawn_window = function()
        return {}, {}, mux_window
      end,
    },
    on = function(name, callback)
      callbacks[name] = callback
    end,
    run_child_process = function()
      return false, '', ''
    end,
    target_triple = target_triple,
  }

  package.loaded.wezterm = nil
  package.preload.wezterm = function()
    return wezterm
  end

  assert(loadfile(config_path))()
  assert(callbacks['gui-startup'], 'WezTerm config did not register gui-startup')
  callbacks['gui-startup']()

  local toggle = assert(callbacks['toggle-window-size'])
  assert(not maximized, 'launch must not maximize the window')
  if not screen then
    assert(actual_width == nil and actual_height == nil and actual_x == nil and actual_y == nil,
      'missing screens must preserve the default window geometry')
    toggle(gui_window)
    return
  end

  assert(
    actual_width == expected_width and actual_height == expected_height,
    string.format(
      '%s launch size was %sx%s, expected %sx%s',
      target_triple,
      tostring(actual_width),
      tostring(actual_height),
      expected_width,
      expected_height
    )
  )
  assert(
    actual_x == expected_x and actual_y == expected_y,
    string.format(
      '%s launch position was %s,%s, expected %s,%s',
      target_triple,
      tostring(actual_x),
      tostring(actual_y),
      expected_x,
      expected_y
    )
  )
  toggle(gui_window)
  local small_width = math.max(1, math.floor(math.min(screen.width * 0.55, expected_width * 0.70)))
  local small_height = math.max(1, math.floor(math.min(screen.height * 0.55, expected_height * 0.70)))
  assert(actual_width == small_width and actual_height == small_height, 'first toggle must shrink')
  assert(actual_x == screen.x + math.floor((screen.width - small_width) / 2))
  assert(actual_y == screen.y + math.floor((screen.height - small_height) / 2))
  toggle(gui_window)
  assert(actual_width == expected_width and actual_height == expected_height, 'second toggle must restore large size')
  gui_window.fullscreen = true
  toggle(gui_window)
  assert(actual_width == expected_width and actual_height == expected_height, 'fullscreen geometry must be untouched')

end

local large_screen = { x = 0, y = 0, width = 4000, height = 2500 }
verify_launch_geometry('aarch64-apple-darwin', large_screen, 3760, 2200, 120, 150)
verify_launch_geometry('x86_64-apple-darwin', { x = -1512, y = 0, width = 1512, height = 982 }, 1421, 864, -1467, 59)
verify_launch_geometry('aarch64-apple-darwin', nil)
verify_launch_geometry('x86_64-pc-windows-msvc', large_screen, 1800, 1200, 1100, 650)
verify_launch_geometry('x86_64-unknown-linux-gnu', large_screen, 1800, 1200, 1100, 650)

verify_launch_geometry('x86_64-pc-windows-msvc', { x = 0, y = 0, width = 1000, height = 1000 }, 880, 840, 60, 80)
print('WezTerm launch geometry passed')
