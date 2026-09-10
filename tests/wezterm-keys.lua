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
  assert(binding('v', 'CTRL') == nil, 'Control+V must reach the application')
  assert(binding('v', 'CTRL|SHIFT').name == 'PasteFrom', 'portable text paste must remain available')

  if triple:find('darwin') then
    sent_key('LeftArrow', 'CMD', 'Home', 'NONE')
    sent_key('RightArrow', 'CMD', 'End', 'NONE')
    for key, sequence in pairs({ LeftArrow = '\x1bb', RightArrow = '\x1bf' }) do
      assert(binding(key, 'ALT').name == 'SendString' and binding(key, 'ALT').value == sequence)
    end
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
