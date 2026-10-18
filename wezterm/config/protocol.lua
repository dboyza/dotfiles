-- Shared behavior is specified by tests/fixtures/floating-tabs.json.
local protocol = { freshness_seconds = 3, max_bytes = 65536, input_interval_ms = 16, max_label_bytes = 64,
  max_branch_bytes = 64, max_path_bytes = 256 }

-- Section: Numeric and freshness rules
local PROGRESS_STATES = { normal = true, error = true, indeterminate = true }
-- Requests that name a tab and nothing else.
local TAB_ACTIONS = { close_tab = true, rename_tab = true, duplicate_tab = true, detach_tab = true }
local function integer(value)
  return type(value) == 'number' and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end

function protocol.fresh(value, title, now)
  return type(value) == 'table' and value.title == title and type(value.updated) == 'number'
    and math.abs(now - value.updated) < protocol.freshness_seconds
end

-- Section: Snapshot identity and tab invariants
function protocol.valid_snapshot(value, filename, now)
  if type(value) ~= 'table' or type(value.key) ~= 'string' or not value.key:match('^[%w]+%-%d+$') then return false end
  local title = 'WezTerm [' .. value.key:gsub('-', ':') .. ']'
  if filename ~= 'window-' .. value.key .. '.json' or not protocol.fresh(value, title, now)
    or type(value.tabs) ~= 'table' or #value.tabs == 0 then return false end
  local ids, indices, active = {}, {}, 0
  for _, tab in ipairs(value.tabs) do
    if type(tab) ~= 'table' or not integer(tab.id) or not integer(tab.index) or tab.index > 2147483647
      or type(tab.active) ~= 'boolean' or ids[tab.id] or indices[tab.index] then return false end
    -- Labels and alerts are optional display hints; wrong types or oversized labels invalidate the snapshot.
    if tab.label ~= nil and (type(tab.label) ~= 'string' or #tab.label > protocol.max_label_bytes) then return false end
    if tab.alert ~= nil and type(tab.alert) ~= 'boolean' then return false end
    if tab.branch ~= nil and (type(tab.branch) ~= 'string' or #tab.branch > protocol.max_branch_bytes) then return false end
    if tab.path ~= nil and (type(tab.path) ~= 'string' or #tab.path > protocol.max_path_bytes) then return false end
    if tab.progress ~= nil and (not integer(tab.progress) or tab.progress > 100) then return false end
    if tab.progress_state ~= nil and not PROGRESS_STATES[tab.progress_state] then return false end
    ids[tab.id], indices[tab.index] = true, true
    if tab.active then active = active + 1 end
  end
  return active == 1
end

-- Section: Accepted requests (activate, new_tab, move_tab, and tab actions)
function protocol.valid_request(value, title, now)
  if not protocol.fresh(value, title, now) then return false end
  if value.action == 'new_tab' then return value.tab_id == nil and value.index == nil end
  if value.action == 'move_tab' then
    return integer(value.tab_id) and integer(value.index) and value.index <= 2147483647
  end
  if TAB_ACTIONS[value.action] then return integer(value.tab_id) and value.index == nil end
  return value.action == nil and integer(value.tab_id) and value.index == nil
end

return protocol
