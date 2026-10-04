-- Locate the checkout and load each responsibility from config/, watching it for edits.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Section: Checkout discovery

-- Loaders and tests pass the checkout file explicitly. Unix home-file symlinks
-- resolve here so modules stay beside their source, including paths with spaces.
local source = ... or wezterm.config_file
assert(source, 'expected the WezTerm configuration path')
local directory = source:match('^(.*)[/\\]') or '.'
local probe = io.open(directory .. '/config/platform.lua', 'r')
if probe then
  probe:close()
elseif not wezterm.target_triple:find('windows') then
  local ok, resolved = wezterm.run_child_process({ '/bin/sh', '-c', [[
    source=$1
    while [ -L "$source" ]; do
      directory=$(cd -P "$(dirname "$source")" && pwd) || exit 1
      source=$(readlink "$source") || exit 1
      case "$source" in /*) ;; *) source="$directory/$source" ;; esac
    done
    cd -P "$(dirname "$source")" && pwd
  ]], 'sh', source })
  assert(ok, 'could not resolve the WezTerm configuration directory')
  directory = resolved:gsub('\r?\n$', '')
else
  -- Older managed Windows loaders call dofile without forwarding their path.
  local loader = assert(io.open(wezterm.config_file, 'r'))
  local quoted_source = loader:read('*a'):match('local source = ("[^\r\n]+")')
  loader:close()
  assert(quoted_source, 'Rerun scripts/install-windows-wezterm.ps1 to update the Windows loader')
  source = wezterm.json_parse(quoted_source)
  directory = assert(source:match('^(.*)[/\\]'))
end

-- Section: Watched module composition
local function load(name)
  local path = directory .. '/config/' .. name .. '.lua'
  if wezterm.add_to_config_reload_watch_list then wezterm.add_to_config_reload_watch_list(path) end
  return dofile(path)
end

local platform = load('platform')(wezterm, config)
load('appearance')(wezterm, config, platform)
load('keys')(wezterm, config, platform)
load('geometry')(wezterm, platform)
load('tabs')(wezterm, config, platform, load('protocol'))
return config
