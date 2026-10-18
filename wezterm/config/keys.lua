-- Route keyboard and mouse input: portable shortcuts, prefix commands, and macOS aliases.
return function(wezterm, config, platform)
  local is_windows, is_macos = platform.is_windows, platform.is_macos
  local act = wezterm.action
  local new_tab, powershell_tab = platform.new_tab, platform.powershell_tab

  local function send(key, mods)
    return act.SendKey({ key = key, mods = mods })
  end

  -- Section: Clipboard routing
  -- Image-only pastes go to the application as Control+V; text and file paths paste normally.
  local function macos_paste_clipboard()
    return wezterm.action_callback(function(window, pane)
      -- Inspect formats only; the application reads the image itself on Control+V.
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
        window:perform_action(send('v', 'CTRL'), pane)
      else
        window:perform_action(act.PasteFrom('Clipboard'), pane)
      end
    end)
  end

  -- Without a selection, Control+Shift+C goes to the shell as CSI-u (native Windows sends the chord).
  local function copy_or_send_to_shell()
    return wezterm.action_callback(function(window, pane)
      local selection = window:get_selection_text_for_pane(pane)
      if selection and selection ~= '' then
        window:perform_action(act.CopyTo('Clipboard'), pane)
        return
      end

      local ok, domain_name = pcall(function() return pane:get_domain_name() end)
      local in_wsl = ok and type(domain_name) == 'string' and domain_name:match('^WSL:')
      if not is_windows or in_wsl then
        window:perform_action(act.SendString('\x1b[99;6u'), pane)
      else
        window:perform_action(send('c', 'CTRL|SHIFT'), pane)
      end
    end)
  end

  -- Section: Application pages versus shell scrollback
  -- Page keys go to fullscreen applications and tmux; a plain shell scrolls WezTerm history.
  local function should_send_scroll_key(pane)
    local ok, in_alt_screen = pcall(function() return pane:is_alt_screen_active() end)
    local title = pane:get_title() or ''
    local process = pane:get_foreground_process_name() or ''
    local process_name = process:match('([^/\\]+)$') or process
    return (ok and in_alt_screen) or title:match('^tmux:') ~= nil or process_name:match('^tmux') ~= nil
  end

  local function scroll_or_send_key(key, mods, scroll_action)
    return wezterm.action_callback(function(window, pane)
      window:perform_action(should_send_scroll_key(pane) and send(key, mods) or scroll_action, pane)
    end)
  end

  -- Section: Prefix (leader)
  -- Control+Space stays free for completion, so the prefix is Control+Shift+Space.
  config.leader = { key = 'Space', mods = 'CTRL|SHIFT', timeout_milliseconds = 1500 }
  if is_macos then
    config.send_composed_key_when_left_alt_is_pressed = false
    config.send_composed_key_when_right_alt_is_pressed = true
  end

  config.keys = {
    -- WezTerm binds this chord to Quick Select by default; free it for the prefix.
    { key = 'phys:Space', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },
  }
  local function bind(key, mods, action)
    table.insert(config.keys, { key = key, mods = mods, action = action })
  end

  -- Section: Portable shortcuts
  bind('Enter', 'ALT', act.SendString('\x1b[13;3u'))
  bind('F11', 'NONE', act.ToggleFullScreen)
  bind('t', 'CTRL|SHIFT', new_tab())
  bind('w', 'CTRL|SHIFT', act.CloseCurrentTab({ confirm = true }))
  bind('c', 'CTRL|SHIFT', copy_or_send_to_shell())
  bind('v', 'CTRL|SHIFT', act.PasteFrom('Clipboard'))
  bind('PageUp', 'NONE', scroll_or_send_key('PageUp', 'NONE', act.ScrollByPage(-1)))
  bind('PageDown', 'NONE', scroll_or_send_key('PageDown', 'NONE', act.ScrollByPage(1)))
  bind('PageUp', 'CTRL', scroll_or_send_key('PageUp', 'CTRL', act.ScrollByLine(-1)))
  bind('PageDown', 'CTRL', scroll_or_send_key('PageDown', 'CTRL', act.ScrollByLine(1)))

  -- Section: Chords passed through to applications
  -- Neovim and Pi use these; WezTerm's defaults would otherwise consume several of them.
  for _, direction in ipairs({ 'UpArrow', 'DownArrow', 'LeftArrow', 'RightArrow' }) do
    bind(direction, 'CTRL', send(direction, 'CTRL'))
    bind(direction, 'CTRL|SHIFT', send(direction, 'CTRL|SHIFT'))
  end
  bind('p', 'CTRL|SHIFT', send('p', 'CTRL|SHIFT'))
  bind('f', 'CTRL|SHIFT', send('f', 'CTRL|SHIFT'))
  for _, key in ipairs({ '-', '_' }) do
    bind(key, 'CTRL', send(key, 'CTRL'))
    bind(key, 'CTRL|SHIFT', send('_', 'CTRL'))
  end

  -- Section: Prefix commands
  -- Panes follow the shared vocabulary: h/j/k/l focus, H/J/K/L resize, backslash/minus split.
  for key, direction in pairs({ h = 'Left', j = 'Down', k = 'Up', l = 'Right' }) do
    bind(key, 'LEADER', act.ActivatePaneDirection(direction))
    bind(key, 'LEADER|SHIFT', act.AdjustPaneSize({ direction, 5 }))
  end

  local leader_bindings = {
    { 'c', new_tab() },
    { 'n', act.ActivateTabRelative(1) },
    { 'p', act.ActivateTabRelative(-1) },
    { 'p', powershell_tab(), 'LEADER|SHIFT' },
    { '\\', act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
    { '-', act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
    { 'x', act.CloseCurrentPane({ confirm = true }) },
    { 'z', act.TogglePaneZoomState },
    { 'y', act.ActivateCopyMode },
    { 'f', act.Search({ CaseSensitiveString = '' }) },
    { 'q', act.QuickSelect },
    -- Jump between shell prompts marked by the Zsh integration.
    { '[', act.ScrollToPrompt(-1) },
    { ']', act.ScrollToPrompt(1) },
    { 'm', act.EmitEvent('toggle-window-size') },
    { 'Space', act.ActivateCommandPalette },
    { 'Enter', act.ToggleFullScreen },
    { '=', act.IncreaseFontSize },
    { '_', act.DecreaseFontSize },
    { '0', act.ResetFontSize },
  }
  for _, entry in ipairs(leader_bindings) do
    bind(entry[1], entry[3] or 'LEADER', entry[2])
  end

  -- Section: MacBook Command and Option aliases
  if is_macos then
    -- Command+Left/Right and Command+H/L are Home/End; Option+Left/Right is word movement.
    bind('LeftArrow', 'CMD', send('Home', 'NONE'))
    bind('RightArrow', 'CMD', send('End', 'NONE'))
    bind('h', 'CMD', send('Home', 'NONE'))
    bind('l', 'CMD', send('End', 'NONE'))
    bind('UpArrow', 'CMD', send('Home', 'CTRL'))
    bind('DownArrow', 'CMD', send('End', 'CTRL'))
    bind('LeftArrow', 'ALT', send('LeftArrow', 'CTRL'))
    bind('RightArrow', 'ALT', send('RightArrow', 'CTRL'))

    bind('[', 'CMD', act.ActivateTabRelative(-1))
    bind(']', 'CMD', act.ActivateTabRelative(1))
    bind('w', 'CMD', act.CloseCurrentTab({ confirm = true }))
    bind('m', 'CMD|SHIFT', act.EmitEvent('toggle-window-size'))
    bind('v', 'CMD', macos_paste_clipboard())

    bind('UpArrow', 'CMD|SHIFT', scroll_or_send_key('PageUp', 'NONE', act.ScrollByPage(-1)))
    bind('DownArrow', 'CMD|SHIFT', scroll_or_send_key('PageDown', 'NONE', act.ScrollByPage(1)))
    bind('UpArrow', 'CMD|ALT', scroll_or_send_key('PageUp', 'CTRL', act.ScrollByLine(-1)))
    bind('DownArrow', 'CMD|ALT', scroll_or_send_key('PageDown', 'CTRL', act.ScrollByLine(1)))
  end

  -- Section: Mouse
  -- Right click pastes, replacing any selection.
  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = act.Multiple({ act.ClearSelection, act.PasteFrom('Clipboard') }),
    },
  }

  -- Section: Quick Select patterns and clickable links
  -- Defaults already cover URLs, paths, Git hashes, and IPs; add compiler-style locations and issue refs.
  local file_location = [[\b[\w./-]+\.[A-Za-z]\w*:\d+(?::\d+)?\b]]
  local issue_reference = [[\b[\w.-]+/[\w.-]+#\d+\b]]
  config.quick_select_patterns = { file_location, issue_reference }
  config.hyperlink_rules = wezterm.default_hyperlink_rules()
  table.insert(config.hyperlink_rules, { regex = file_location, format = 'dotfiles-edit:$0' })
  table.insert(config.hyperlink_rules, {
    regex = [[\b([\w.-]+)/([\w.-]+)#(\d+)\b]],
    format = 'https://github.com/$1/$2/issues/$3',
  })

  -- Open a clicked file:line in Neovim in a new tab of the same domain and directory.
  -- Typing into the new shell keeps its login PATH, which GUI-spawned commands lack on macOS.
  wezterm.on('open-uri', function(window, pane, uri)
    local path, line = uri:match('^dotfiles%-edit:(.-):(%d+)')
    if not path then return end
    -- Native Windows panes run PowerShell without the managed Neovim.
    if is_windows and pane:get_domain_name() == 'local' then return false end
    local cwd = pane:get_current_working_dir()
    local _, editor = window:mux_window():spawn_tab({
      cwd = cwd and cwd.file_path,
      domain = { DomainName = pane:get_domain_name() },
    })
    local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
    editor:send_text('nvim +' .. line .. ' -- ' .. quoted .. '\n')
    return false
  end)
end
