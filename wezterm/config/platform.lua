-- Select the host shell and WSL home directory; expose shared tab-creation actions.
return function(wezterm, config)
  local target_triple = wezterm.target_triple:lower()
  local is_windows = target_triple:find('windows') ~= nil
  local is_macos = target_triple:find('darwin') ~= nil

  -- Section: Executable discovery
  -- WezTerm re-evaluates the config for every window override, so child-process probes run once per
  -- GUI process. A nil result (such as WSL not answering yet) is retried on the next evaluation.
  local function remembered(key, probe)
    local value = wezterm.GLOBAL[key]
    if value == nil then
      value = probe()
      wezterm.GLOBAL[key] = value
    end
    return value
  end

  local function command_exists(program)
    return remembered('dotfiles_command_exists:' .. program, function()
      local probe = is_windows and { 'where.exe', program }
        or { '/bin/sh', '-c', 'command -v "$1" >/dev/null 2>&1', 'sh', program }
      local called, found = pcall(wezterm.run_child_process, probe)
      return called and found
    end)
  end

  -- Section: WSL domain and working-directory selection
  -- The first installed distribution is used when the preferred one is missing.
  local PREFERRED_WSL_DOMAIN = 'WSL:Ubuntu-24.04'

  local function resolve_wsl_home(distribution)
    return remembered('dotfiles_wsl_home:' .. distribution, function()
      local called, success, stdout = pcall(wezterm.run_child_process, {
        'wsl.exe', '--distribution', distribution, '--exec', 'printenv', 'HOME',
      })
      if not called or not success then return nil end
      local home = stdout:match('^%s*(.-)%s*$')
      return home:sub(1, 1) == '/' and home or nil
    end)
  end

  -- Returns the WSL domain name and its home directory, or nil when WSL is unavailable.
  local function preferred_wsl_domain()
    if not is_windows then return nil, nil end
    local ok, domains = pcall(wezterm.default_wsl_domains)
    if not ok then return nil, nil end

    local selected = domains[1]
    for _, domain in ipairs(domains) do
      if domain.name == PREFERRED_WSL_DOMAIN then
        selected = domain
        break
      end
    end
    if not selected then return nil, nil end

    -- New tabs would otherwise inherit a Windows working directory.
    local home = resolve_wsl_home(selected.distribution)
    if home then
      selected.default_cwd = home
      config.wsl_domains = domains
    end
    return selected.name, home
  end

  -- Section: Default shell
  local wsl_domain, wsl_home = preferred_wsl_domain()
  local powershell_prog
  if is_windows then
    powershell_prog = command_exists('pwsh.exe') and { 'pwsh.exe', '-NoLogo' } or { 'powershell.exe', '-NoLogo' }
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
    if not wsl_domain then return nil end
    return { domain = { DomainName = wsl_domain }, cwd = wsl_home }
  end

  local function wsl_tab_action()
    local spawn = wsl_spawn_command()
    if spawn then return wezterm.action.SpawnCommandInNewTab(spawn) end
    return wezterm.action.SpawnTab('DefaultDomain')
  end

  local function powershell_tab_action()
    if not powershell_prog then return wezterm.action.SpawnTab('DefaultDomain') end
    return wezterm.action.SpawnCommandInNewTab({
      domain = { DomainName = 'local' },
      args = powershell_prog,
      cwd = is_windows and os.getenv('USERPROFILE') or os.getenv('HOME'),
    })
  end

  return {
    is_windows = is_windows,
    is_macos = is_macos,
    new_tab = wsl_tab_action,
    powershell_tab = powershell_tab_action,
    spawn_command = wsl_spawn_command,
  }
end
