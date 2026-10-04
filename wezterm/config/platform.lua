-- Select the host shell and WSL home directory; expose shared tab-creation actions.
return function(wezterm, config)
  local target_triple = wezterm.target_triple:lower()
  local is_windows = target_triple:find('windows') ~= nil
  local is_macos = target_triple:find('darwin') ~= nil
  -- Section: Executable discovery
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
  -- shell
  -- Section: WSL domain and working-directory selection
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

  -- Section: Host shell fallback
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

  -- Section: Shared new-tab actions
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

  return {
    is_windows = is_windows, is_macos = is_macos,
    new_tab = wsl_tab_action, powershell_tab = powershell_tab_action,
    spawn_command = wsl_spawn_command,
  }
end
