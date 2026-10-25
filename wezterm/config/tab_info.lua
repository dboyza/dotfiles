-- Describe each tab for the floating strip and native fallback: label, git branch, path, progress, alerts.
return function(wezterm, protocol, platform)
  local info = {}
  local LABEL_COLUMNS = 12
  local BRANCH_COLUMNS = 14
  local GIT_CACHE_SECONDS = 3
  local SHELLS = { zsh = true, bash = true, fish = true, sh = true, dash = true, nu = true, pwsh = true, powershell = true }

  -- Remote, closing, or mocked panes can fail any lookup; a failed call is simply no value.
  local function try(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
  end

  -- Section: Names from the program or folder
  local function basename(path)
    return (path or ''):match('([^/\\]+)[/\\]*$') or ''
  end

  -- WezTerm reports directories as Url objects; older paths and fixtures may be plain strings.
  local function directory_of(cwd)
    if cwd and type(cwd) ~= 'string' then cwd = cwd.file_path end
    return cwd
  end

  local function clean(text, columns)
    text = (text or ''):gsub('%c', '')
    if text == '' then return nil end
    return wezterm.truncate_right(text, columns)
  end

  -- A user-set tab title always wins; otherwise name the foreground program, or the folder for a plain shell.
  local function tab_label(pane_info, custom_title)
    local custom = clean(custom_title, LABEL_COLUMNS)
    if custom then return custom end
    if type(pane_info) ~= 'table' then return nil end
    local process = basename(pane_info.foreground_process_name):gsub('%.exe$', ''):lower()
    if process ~= '' and not SHELLS[process] then return clean(process, LABEL_COLUMNS) end
    local cwd = directory_of(pane_info.current_working_dir)
    return clean((cwd and cwd == wezterm.home_dir) and '~' or basename(cwd), LABEL_COLUMNS)
  end

  -- Section: Git branch from repository files, cached briefly (no child processes)
  local function read_first_line(path)
    local file = io.open(path, 'r')
    if not file then return nil end
    local line = file:read('*l')
    file:close()
    return line
  end

  local function git_head(directory)
    for _ = 1, 16 do
      local head = read_first_line(directory .. '/.git/HEAD')
      if head then return head end
      -- Worktrees and submodules keep a `.git` file that points at the real directory.
      local pointer = (read_first_line(directory .. '/.git') or ''):match('^gitdir:%s*(.+)$')
      if pointer then
        local absolute = pointer:match('^/') and pointer or (directory .. '/' .. pointer)
        local linked = read_first_line(absolute .. '/HEAD')
        if linked then return linked end
      end
      local parent = directory:match('^(.*)/[^/]+$')
      if not parent or parent == '' then return nil end
      directory = parent
    end
  end

  local function git_branch(directory)
    local key = 'floating_git_' .. directory
    local cached = wezterm.GLOBAL[key]
    local now = os.time()
    if cached then
      local entry = wezterm.json_parse(cached)
      if now - entry.at < GIT_CACHE_SECONDS then return entry.branch end
    end
    local head = git_head(directory)
    local branch = head and (head:match('^ref: refs/heads/(.+)$') or head:sub(1, 7)) or nil
    wezterm.GLOBAL[key] = wezterm.json_encode({ at = now, branch = branch })
    return clean(branch, BRANCH_COLUMNS)
  end

  -- Display path for the tooltip, with the home directory abbreviated.
  local function display_path(directory)
    if not directory or directory == '' then return nil end
    local home = wezterm.home_dir
    if home and directory:sub(1, #home) == home then directory = '~' .. directory:sub(#home + 1) end
    if #directory > protocol.max_path_bytes then return nil end
    return directory
  end

  -- Section: Progress reported by programs (OSC 9;4)
  local function clamp(value)
    return math.max(0, math.min(100, math.floor(tonumber(value) or 0)))
  end

  local function tab_progress(pane)
    local state = try(function() return pane:get_progress() end)
    if state == 'Indeterminate' then return nil, 'indeterminate' end
    if type(state) ~= 'table' then return nil, nil end
    if state.Percentage then return clamp(state.Percentage), 'normal' end
    if state.Error then return clamp(state.Error), 'error' end
    if state.Paused then return clamp(state.Paused), 'normal' end
    return nil, nil
  end

  -- Section: Alerts on background tabs
  local function alert_key(tab_id) return 'floating_tab_alert_' .. tostring(tab_id) end

  -- Viewing a tab acknowledges its alert.
  function info.alert(tab_id, active)
    local key = alert_key(tab_id)
    if active then
      if wezterm.GLOBAL[key] then wezterm.GLOBAL[key] = nil end
      return false
    end
    return wezterm.GLOBAL[key] == true
  end

  local function mark_background_alert(pane)
    local ok, tab = pcall(function() return pane:tab() end)
    if not ok or not tab then return end
    local window = tab:window()
    local active = window and window:active_tab()
    if active and active:tab_id() ~= tab:tab_id() then wezterm.GLOBAL[alert_key(tab:tab_id())] = true end
  end

  -- A bell or a long-running command (the Zsh integration sets this user variable) flags a background tab.
  wezterm.on('bell', function(_, pane) mark_background_alert(pane) end)
  wezterm.on('user-var-changed', function(_, pane, name)
    if name == 'dotfiles_command_done' then mark_background_alert(pane) end
  end)

  -- Section: Shared hints cache
  -- Mux panes know their process, branch, and progress, while title and tab-format events often omit them.
  -- One cache keeps every publisher agreeing, so badges never flip between forms.
  local function hints_key(tab_id) return 'floating_tab_hints_' .. tostring(tab_id) end

  -- Hints for event data that lacks a mux pane: the cache first, then whatever the event itself carries.
  function info.cached(tab_id, pane_info, custom_title)
    local stored = wezterm.GLOBAL[hints_key(tab_id)]
    local hints = stored and wezterm.json_parse(stored) or {}
    -- A just-set title reaches the title event before the next mux poll.
    local custom = clean(custom_title, LABEL_COLUMNS)
    if custom then hints.label = custom elseif not hints.label then hints.label = tab_label(pane_info) end
    return hints
  end

  -- Hints for a mux tab entry without touching its panes: the input path uses this to stay within a frame.
  function info.stored(item)
    local tab_id = try(function() return item.tab:tab_id() end)
    if not tab_id then return {} end
    local stored = wezterm.GLOBAL[hints_key(tab_id)]
    local hints = stored and wezterm.json_parse(stored) or {}
    hints.alert = info.alert(tab_id, item.is_active) or nil
    return hints
  end

  -- Describe a mux tab entry; a failed lookup keeps the last known hints rather than dropping them.
  function info.describe(item)
    local tab_id = try(function() return item.tab:tab_id() end)
    local hints = {}
    local pane = try(function() return item.tab:active_pane() end)
    if pane then
      local name = try(function() return pane:get_foreground_process_name() end)
      local cwd = try(function() return pane:get_current_working_dir() end)
      local custom = try(function() return item.tab:get_title() end)
      local directory = directory_of(cwd)
      hints.label = tab_label({ foreground_process_name = name, current_working_dir = cwd }, custom)
      -- Branches are read from local disk only; remote and WSL panes report paths this host cannot see.
      local domain = try(function() return pane:get_domain_name() end)
      if directory and not platform.is_windows and domain == 'local' then hints.branch = git_branch(directory) end
      hints.path = display_path(directory)
      hints.progress, hints.progress_state = tab_progress(pane)
    end
    if tab_id then
      local encoded = wezterm.json_encode(hints)
      if next(hints) == nil then
        encoded = wezterm.GLOBAL[hints_key(tab_id)]
        hints = encoded and wezterm.json_parse(encoded) or hints
      elseif wezterm.GLOBAL[hints_key(tab_id)] ~= encoded then
        wezterm.GLOBAL[hints_key(tab_id)] = encoded
      end
      hints.alert = info.alert(tab_id, item.is_active) or nil
    end
    return hints
  end

  info.tab_label = tab_label
  return info
end
