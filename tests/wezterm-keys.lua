local config_path = assert(arg[1], 'expected the WezTerm config path')
local clipboard_probe

for _, triple in ipairs({ 'aarch64-apple-darwin', 'x86_64-apple-darwin', 'x86_64-pc-windows-msvc', 'x86_64-unknown-linux-gnu' }) do
  local probe_result = 'text\n'
  local probe_success = true
  local probe_throws = false
  local actions = setmetatable({}, {
    __index = function(_, name)
      return function(value) return { name = name, value = value } end
    end,
  })
  package.loaded.wezterm = {
    target_triple = triple,
    plugin = { require = function() return { setup = function() end } end },
    config_builder = function() return {} end,
    mux = {},
    action = actions,
    action_callback = function(callback) return callback end,
    font_with_fallback = function(fonts) return fonts end,
    default_wsl_domains = function() return {} end,
    on = function() end,
    run_child_process = function(command)
      if command[1] ~= '/usr/bin/osascript' then return false, '', '' end
      clipboard_probe = command[5]
      if probe_throws then error('clipboard unavailable') end
      return probe_success, probe_result, ''
    end,
  }
  local config = dofile(config_path)
  local function binding(key, mods)
    for _, entry in ipairs(config.keys) do
      if entry.key == key and entry.mods == mods then return entry.action end
    end
  end
  local function sent_key(key, mods, expected_key, expected_mods)
    local action = assert(binding(key, mods), triple .. ': missing ' .. mods .. '+' .. key)
    assert(action.name == 'SendKey')
    assert(action.value.key == expected_key and action.value.mods == expected_mods)
  end
  for _, direction in ipairs({ 'LeftArrow', 'RightArrow', 'UpArrow', 'DownArrow' }) do
    sent_key(direction, 'CTRL', direction, 'CTRL')
  end
  assert(config.leader.key == 'Space' and config.leader.mods == 'CTRL|SHIFT')
  assert(binding('m', 'LEADER').value == 'toggle-window-size')
  assert((binding('m', 'CMD') ~= nil) == (triple:find('darwin') ~= nil))
  sent_key('p', 'CTRL|SHIFT', 'p', 'CTRL|SHIFT')
  sent_key('f', 'CTRL|SHIFT', 'f', 'CTRL|SHIFT')
  sent_key('UpArrow', 'CTRL|SHIFT', 'UpArrow', 'CTRL|SHIFT')
  sent_key('DownArrow', 'CTRL|SHIFT', 'DownArrow', 'CTRL|SHIFT')
  sent_key('-', 'CTRL', '-', 'CTRL')
  sent_key('_', 'CTRL', '_', 'CTRL')
  assert(binding('v', 'CTRL') == nil, 'Control+V must reach the application')
  assert(binding('v', 'CTRL|SHIFT').name == 'PasteFrom', 'portable text paste must remain available')

  for key, direction in pairs({ h = 'Left', j = 'Down', k = 'Up', l = 'Right' }) do
    assert(binding(key, 'LEADER').value == direction)
    local resize = binding(key, 'LEADER|SHIFT')
    assert(resize.name == 'AdjustPaneSize' and resize.value[1] == direction)
  end
  local seen = {}
  for _, entry in ipairs(config.keys) do
    local chord = entry.mods .. '+' .. entry.key
    assert(not seen[chord], 'duplicate WezTerm binding: ' .. chord)
    seen[chord] = true
  end
  for _, context in ipairs({
    { alt = false, title = '', process = 'zsh', sends = false },
    { alt = true, title = '', process = 'nvim', sends = true },
    { alt = false, title = 'tmux:session', process = 'zsh', sends = true },
    { alt = false, title = '', process = 'tmux', sends = true },
  }) do
    local performed
    local pane = {
      is_alt_screen_active = function() return context.alt end,
      get_title = function() return context.title end,
      get_foreground_process_name = function() return context.process end,
    }
    local window = { perform_action = function(_, action) performed = action end }
    for _, key in ipairs({ 'PageUp', 'PageDown' }) do
      for _, mods in ipairs({ 'NONE', 'CTRL' }) do
        binding(key, mods)(window, pane)
        if context.sends then
          assert(performed.name == 'SendKey' and performed.value.key == key and performed.value.mods == mods)
        else
          assert(performed.name == (mods == 'CTRL' and 'ScrollByLine' or 'ScrollByPage'))
        end
      end
    end
  end

  assert(binding('w', 'CTRL|SHIFT').name == 'CloseCurrentTab')
  assert(binding('w', 'CTRL|SHIFT').value.confirm == true)
  if not triple:find('darwin') then
    assert(binding('[', 'CMD') == nil and binding(']', 'CMD') == nil and binding('w', 'CMD') == nil)
  end
  if triple:find('darwin') then
    assert(binding('[', 'CMD').name == 'ActivateTabRelative' and binding('[', 'CMD').value == -1)
    assert(binding(']', 'CMD').name == 'ActivateTabRelative' and binding(']', 'CMD').value == 1)
    assert(binding('w', 'CMD').name == 'CloseCurrentTab' and binding('w', 'CMD').value.confirm == true)
    sent_key('LeftArrow', 'CMD', 'Home', 'NONE')
    sent_key('RightArrow', 'CMD', 'End', 'NONE')
    sent_key('h', 'CMD', 'Home', 'NONE')
    sent_key('l', 'CMD', 'End', 'NONE')
    sent_key('LeftArrow', 'ALT', 'LeftArrow', 'CTRL')
    sent_key('RightArrow', 'ALT', 'RightArrow', 'CTRL')
    sent_key('UpArrow', 'CMD', 'Home', 'CTRL')
    sent_key('DownArrow', 'CMD', 'End', 'CTRL')
    local performed
    local pane = {}
    local window = { perform_action = function(_, action, target)
      assert(target == pane, 'paste must target the original pane')
      performed = action
    end }
    for _, kind in ipairs({ 'text\n', 'image\n', '', 'unexpected\n' }) do
      probe_result = kind
      binding('v', 'CMD')(window, pane)
      if kind == 'image\n' then
        assert(performed.name == 'SendKey' and performed.value.key == 'v' and performed.value.mods == 'CTRL')
      else
        assert(performed.name == 'PasteFrom' and performed.value == 'Clipboard')
      end
    end
    probe_result, probe_success = 'image\n', false
    binding('v', 'CMD')(window, pane)
    assert(performed.name == 'PasteFrom', 'failed clipboard probe must preserve text paste')
    probe_throws = true
    binding('v', 'CMD')(window, pane)
    assert(performed.name == 'PasteFrom', 'unavailable clipboard probe must preserve text paste')
  else
    assert(binding('h', 'CMD') == nil and binding('l', 'CMD') == nil)
    assert(binding('v', 'CMD') == nil, 'macOS paste must not change Windows or WSL')
    assert(binding('LeftArrow', 'ALT') == nil and binding('LeftArrow', 'CMD') == nil)
  end
end

-- Exercise Apple's real format negotiation on a private pasteboard, leaving the
-- user's general clipboard untouched. No screenshot data is read or generated.
if vim.uv.os_uname().sysname == 'Darwin' then
  local fixtures = {
    { types = {}, expected = 'text' },
    { types = { 'public.png' }, expected = 'image' },
    { types = { 'public.tiff' }, expected = 'image' },
    { types = { 'public.jpeg' }, expected = 'image' },
    { types = { 'public.utf8-plain-text' }, expected = 'text' },
    { types = { 'public.png', 'public.utf8-plain-text' }, expected = 'text' },
    { types = { 'public.tiff', 'public.utf16-external-plain-text' }, expected = 'text' },
    { types = { 'public.png', 'public.file-url' }, expected = 'text' },
  }
  for _, fixture in ipairs(fixtures) do
    local types_json = #fixture.types == 0 and '[]' or vim.json.encode(fixture.types)
    local probe = clipboard_probe:gsub('%$%.NSPasteboard%.generalPasteboard', 'fixtureBoard')
    local script = [[
      ObjC.import('AppKit');
      const fixtureBoard = $.NSPasteboard.pasteboardWithUniqueName;
      const fixtureTypes = ]] .. types_json .. [[;
      fixtureBoard.clearContents;
      fixtureTypes.forEach(type => fixtureBoard.setStringForType('fixture', type));
      const result = eval(]] .. vim.json.encode(probe) .. [[);
      fixtureBoard.releaseGlobally;
      result;
    ]]
    local result = vim.fn.system({ '/usr/bin/osascript', '-l', 'JavaScript', '-e', script })
    assert(vim.v.shell_error == 0, result)
    assert(vim.trim(result) == fixture.expected, 'unexpected native clipboard classification: ' .. result)
  end
end

print('WezTerm keyboard routing passed')
