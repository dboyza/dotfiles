-- WezTerm can return success after a config error and fall back to defaults.
-- Validate options before publishing an explicit completion verdict.
local wezterm = require 'wezterm'
local source = assert(os.getenv('DOTFILES_WEZTERM_CHECK_SOURCE'))
local builder = wezterm.config_builder
wezterm.config_builder = function()
  local config = builder()
  config:set_strict_mode(true)
  return config
end
local ok, config = pcall(function()
  local loaded = assert(loadfile(source))(source)
  local validated = wezterm.config_builder()
  for key, value in pairs(loaded) do validated[key] = value end
  return validated
end)
wezterm.config_builder = builder
local verdict = assert(io.open(assert(os.getenv('DOTFILES_WEZTERM_CHECK_RESULT')), 'w'))
verdict:write(ok and 'passed\n' or tostring(config))
verdict:close()
return ok and config or {}
