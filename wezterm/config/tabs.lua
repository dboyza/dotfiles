-- Exchange per-window companion state and render native tabs, borders, and the clock.
return function(wezterm, config, platform, protocol)
  local is_windows, is_macos = platform.is_windows, platform.is_macos
  local wsl_tab_action = platform.new_tab
  -- Native companions exchange tab IDs only, never terminal text or commands.
  -- Section: Companion discovery and polling cadence
  local overlay_root = (is_macos or is_windows) and wezterm.home_dir
    and (wezterm.home_dir .. '/.local/state/dotfiles/wezterm-floating-tabs/') or nil
  local overlay_app = is_macos and wezterm.home_dir
    and (wezterm.home_dir .. '/Applications/WezTerm Floating Tabs.app') or nil
  local overlay_executable = is_windows and wezterm.home_dir
    and (wezterm.home_dir .. '/.local/share/dotfiles/wezterm-floating-tabs/wezterm-floating-tabs.exe')
    or (overlay_app and (overlay_app .. '/Contents/MacOS/wezterm-floating-tabs'))
  local overlay_available = false
  if overlay_executable then
    local file = io.open(overlay_executable, 'rb')
    if file then file:close(); overlay_available = true end
  end
  -- Clicks need a frame-sized interval. Keep the slower status/heartbeat work on
  -- its original cadence rather than rebuilding it for every input check.
  local overlay_status_interval = config.status_update_interval / 1000
  if overlay_available then config.status_update_interval = protocol.input_interval_ms end
  local overlay_status_updated = {}

  -- Section: Per-process window identity and bounded reads
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
    local text = file:read(protocol.max_bytes + 1)
    file:close()
    if text and #text > protocol.max_bytes then return nil end
    local ok, result = pcall(wezterm.json_parse, text or '')
    return ok and type(result) == 'table' and result or nil
  end

  local function overlay_fresh(reply, title)
    return protocol.fresh(reply, title, os.time())
  end

  -- Section: Atomic snapshots and request consumption
  local function publish_floating_tabs(window_id, tabs)
    local title = overlay_title(window_id)
    local now = os.time()
    local key = overlay_key(window_id)
    local signature = title .. wezterm.json_encode(tabs)
    -- Title formatting also runs for unrelated terminal output. Publish only tab
    -- changes, with a one-second heartbeat so an idle window remains live.
    if wezterm.GLOBAL['floating_tabs_signature_' .. key] == signature
      and wezterm.GLOBAL['floating_tabs_published_' .. key] == now then return end
    local snapshot = { key = key, title = title, updated = now, tabs = tabs }
    -- Closing or opening a window can briefly leave it without an active tab.
    if not protocol.valid_snapshot(snapshot, 'window-' .. key .. '.json', now) then return end
    local temporary = overlay_root .. 'window-' .. key .. '.tmp'
    local file = io.open(temporary, 'w')
    if not file then return end
    file:write(wezterm.json_encode(snapshot))
    file:close()
    local destination = overlay_root .. 'window-' .. key .. '.json'
    local renamed = os.rename(temporary, destination)
    -- Windows CRT rename cannot replace an existing file. Readers tolerate the
    -- short missing-file interval; publish the complete temporary file afterwards.
    if not renamed and is_windows then
      os.remove(destination)
      renamed = os.rename(temporary, destination)
    end
    if renamed then
      wezterm.GLOBAL['floating_tabs_signature_' .. key] = signature
      wezterm.GLOBAL['floating_tabs_published_' .. key] = now
    end
  end

  local function consume_floating_tab_request(window)
    local key = overlay_key(window:mux_window():window_id())
    local title = overlay_title(window:mux_window():window_id())
    local request = overlay_read('activate-' .. key .. '.json')
    -- Consume even malformed or foreign requests before considering an action.
    local consumed = os.remove(overlay_root .. 'activate-' .. key .. '.json')
    if not consumed or not protocol.valid_request(request, title, os.time()) then return false end
    if request.action == 'new_tab' then
      window:perform_action(wsl_tab_action(), window:active_pane())
      return true
    end
    for _, tab in ipairs(window:mux_window():tabs_with_info()) do
      if tab.tab:tab_id() == request.tab_id then
        tab.tab:activate()
        return true
      end
    end
    return false
  end

  local function publish_window_floating_tabs(window)
    -- Snapshot after handling a click, not before activating its destination.
    local tabs = {}
    for _, tab in ipairs(window:mux_window():tabs_with_info()) do
      table.insert(tabs, { id = tab.tab:tab_id(), index = tab.index, active = tab.is_active })
    end
    publish_floating_tabs(window:mux_window():window_id(), tabs)
  end

  -- Section: Acknowledgments and native fallback
  local function update_floating_tabs(window)
    if not overlay_available then return end
    local key = overlay_key(window:mux_window():window_id())
    local title = overlay_title(window:mux_window():window_id())
    if not wezterm.GLOBAL.floating_tabs_started then
      wezterm.GLOBAL.floating_tabs_started = true
      if is_windows then
        wezterm.background_child_process({ overlay_executable })
      else
        wezterm.background_child_process({ '/usr/bin/open', '-g', overlay_app })
      end
    end
    publish_window_floating_tabs(window)
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
  -- Section: Native tab rendering and focus border
  local bar_background = config.colors.tab_bar.background
  local function capsule(text, foreground, background, active)
    return {
      { Attribute = { Intensity = active and 'Bold' or 'Normal' } },
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
    return capsule(label, tab.is_active and '#191724' or (hover and '#e0def4' or '#908caa'),
      tab.is_active and '#c4a7e7' or (hover and '#393552' or '#232136'), tab.is_active)
  end)

  local function update_window_border(window)
    -- The Windows companion styles the actual rounded DWM frame.
    if is_windows then return end
    local color = window:is_focused() and '#908caa' or '#393552'
    local overrides = window:get_config_overrides() or {}
    local frame = overrides.window_frame or {}
    local sides = { 'border_left_color', 'border_right_color', 'border_top_color', 'border_bottom_color' }
    local changed = false
    for _, side in ipairs(sides) do
      if frame[side] ~= color then changed = true end
    end
    if not changed then return end
    -- Nested overrides replace the whole frame; retain platform fonts and any
    -- unrelated per-window customization when changing the outline.
    local merged = {}
    for key, value in pairs(config.window_frame) do merged[key] = value end
    for key, value in pairs(frame) do merged[key] = value end
    for _, side in ipairs(sides) do merged[side] = color end
    overrides.window_frame = merged
    window:set_config_overrides(overrides)
  end

  wezterm.on('window-focus-changed', update_window_border)

  -- Section: Fast input ticks and slower clock maintenance
  wezterm.on('update-status', function(window)
    if overlay_available and consume_floating_tab_request(window) then
      publish_window_floating_tabs(window)
    end
    -- WezTerm 20240203 rearms its status timer when a status setter updates the
    -- title. Do this even on input-only ticks or polling can stop on idle tabs.
    window:set_left_status('')
    if overlay_available then
      local id = window:mux_window():window_id()
      local now = tonumber(wezterm.time.now():format('%s%.3f'))
      local previous = overlay_status_updated[id]
      if previous and now >= previous and now - previous < overlay_status_interval then return end
      overlay_status_updated[id] = now
    end
    update_window_border(window)
    update_floating_tabs(window)
    local size = window:active_tab():get_size()
    -- The tab bar spans the full window, including terminal padding.
    local cell_width = size.pixel_width / math.max(1, size.cols)
    local cols = cell_width > 0 and math.floor(window:get_dimensions().pixel_width / cell_width) or size.cols
    local tabs_width = 0
    for _, tab in ipairs(window:mux_window():tabs_with_info()) do
      tabs_width = tabs_width + #tostring(tab.index + 1) + 2
    end
    local clock = ' ' .. wezterm.strftime('%I:%M %p'):gsub('^0', '') .. ' '
    local clock_width = wezterm.column_width(clock) + 2
    local clock_start = math.floor((cols - clock_width) / 2)
    -- Hide the clock when tabs reach the center, rather than clipping its digits.
    if clock_start < tabs_width + 1 then
      window:set_right_status('')
      return
    end
    local items = capsule(clock, '#908caa', '#232136')
    table.insert(items, { Text = string.rep(' ', cols - clock_start - clock_width) })
    window:set_right_status(wezterm.format(items))
  end)
end
