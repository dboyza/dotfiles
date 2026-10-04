return function(wezterm, config, platform)
  local is_windows, is_macos = platform.is_windows, platform.is_macos
  local wsl_tab_action, powershell_tab_action = platform.new_tab, platform.powershell_tab
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
  wezterm.on('new-tab-button-click', function(window, pane, button)
    if button == 'Left' then
      window:perform_action(wsl_tab_action(), pane)
      return false
    end
  end)
end
