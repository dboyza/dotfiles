-- Shared behavior is specified by tests/fixtures/floating-tabs.json.
local protocol = { freshness_seconds = 3, max_bytes = 65536, input_interval_ms = 16 }

-- Section: Numeric and freshness rules
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
    ids[tab.id], indices[tab.index] = true, true
    if tab.active then active = active + 1 end
  end
  return active == 1
end

-- Section: Accepted click actions
function protocol.valid_request(value, title, now)
  if not protocol.fresh(value, title, now) then return false end
  if value.action == 'new_tab' then return value.tab_id == nil end
  return value.action == nil and integer(value.tab_id)
end

return protocol
