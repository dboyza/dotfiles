-- WezTerm can exit successfully after a Lua error by falling back to defaults.
-- Export an explicit verdict so the shell/PowerShell runners cannot pass then.
local wezterm = require 'wezterm'
local target = os.getenv('DOTFILES_FLOATING_TEST_TARGET')
if target == 'windows' or target == 'windows-wsl' then
  wezterm.target_triple = 'x86_64-pc-windows-msvc'
  wezterm.default_wsl_domains = function()
    return target == 'windows-wsl' and { { name = 'WSL:Fixture', distribution = 'Fixture' } } or {}
  end
  wezterm.run_child_process = function(command)
    if command[1] == 'wsl.exe' then return true, '/home/fixture\n', '' end
    return false, '', ''
  end
end
local ok, result = pcall(function()
  return dofile(wezterm.config_dir .. '/wezterm-floating-tabs.lua')
end)
local verdict = assert(io.open(assert(os.getenv('DOTFILES_FLOATING_TEST_HOME')) .. '/bridge-result.txt', 'w'))
verdict:write(ok and 'passed\n' or tostring(result))
verdict:close()
return ok and result or {}
