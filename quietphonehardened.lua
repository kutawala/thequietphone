-- Quiet Phone EP: Resonant Trace Registry
-- Version 2.0 (Hardened)
local json = require("json")

-- 1. Optimized State Initialization
state = state or {
  traces = {},
  by_sender = {},
  by_combination = {},
  status = "Active"
}

Steward = Steward or "yv8hmCG7dbM7wf_YKvTCGnmGg2nUXL_ThfDOxKo1mXk"

-- 2. Strict Schema Definition
local ALLOWED_TRAITS = {
  ["head"] = true, ["arms-accent"] = true, ["underpads"] = true,
  ["speakersandpadding"] = true, ["chest"] = true, ["mechanicals"] = true,
  ["thigh-accent"] = true, ["strips"] = true, ["jointsanddetails"] = true,
  ["shin-accent"] = true, ["feet-accent"] = true
}

-- 3. Validation Utilities
local function is_valid_hex(hex)
  return type(hex) == "string" and hex:match("^#[0-9a-fA-F]{6}$") ~= nil
end

local function validate_traits(traits)
  if type(traits) ~= "table" then return false, "Payload must be a JSON object" end

  local count = 0
  for k, v in pairs(traits) do
    if not ALLOWED_TRAITS[k] then return false, "Unauthorized trait key: " .. tostring(k) end
    if not is_valid_hex(v) then return false, "Invalid hex color for " .. tostring(k) end
    count = count + 1
  end

  -- Ensure no traits are missing (hardcoded to 11 based on schema)
  if count ~= 11 then return false, "Incomplete resonance. Expected 11 traits, got " .. count end

  return true, "Valid"
end

local function hash_combination(traits)
  local keys = {}
  for k in pairs(traits) do table.insert(keys, k) end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    -- Normalize to uppercase to prevent #ffffff and #FFFFFF from registering as different
    table.insert(parts, k .. ":" .. string.upper(traits[k]))
  end
  return table.concat(parts, "|")
end

-- ─────────────────────────────────────────────
-- Handler: Commit Resonance
-- ─────────────────────────────────────────────
Handlers.add(
  "CommitResonance",
  Handlers.utils.hasMatchingTag("Action", "Commit-Resonance"),
  function(msg)
    if state.status ~= "Active" then
      msg.reply({ Tags = { Action = "Commit-Resonance-Result" }, Data = json.encode({ status = "inactive", message = "Cave is inactive" })})
      return
    end

    -- 4. Pre-flight checks on state BEFORE parsing to save compute
    if state.by_sender[msg.From] then
      msg.reply({ Tags = { Action = "Commit-Resonance-Result" }, Data = json.encode({ status = "sender-exists", message = "Wallet has already committed." })})
      return
    end

    -- 5. Safe Parsing & Strict Validation
    local ok, traits = pcall(json.decode, msg.Data)
    if not ok then
      msg.reply({ Tags = { Action = "Commit-Resonance-Result" }, Data = json.encode({ status = "error", message = "Malformed JSON" })})
      return
    end

    local is_valid, val_msg = validate_traits(traits)
    if not is_valid then
      msg.reply({ Tags = { Action = "Commit-Resonance-Result" }, Data = json.encode({ status = "error", message = val_msg })})
      return
    end

    -- 6. Combination Check
    local combo_hash = hash_combination(traits)
    if state.by_combination[combo_hash] then
      msg.reply({ Tags = { Action = "Commit-Resonance-Result" }, Data = json.encode({ status = "duplicate", message = "Exact combination exists." })})
      return
    end

    -- 7. Sanitize Tags and Store
    local trace = {
      sender = msg.From,
      traits = traits,
      country = tostring(msg.Tags.Country or "unknown"):sub(1, 10), -- limit length
      variant = tostring(msg.Tags.Variant or "unspecified"):sub(1, 20),
      timestamp = msg.Timestamp,
      combo_hash = combo_hash
    }

    table.insert(state.traces, trace)
    state.by_sender[msg.From] = trace
    state.by_combination[combo_hash] = trace

    msg.reply({
      Tags = { Action = "Commit-Resonance-Result" },
      Data = json.encode({ status = "ok", message = "Resonance committed", count = #state.traces })
    })
  end
)

Handlers.add("Dissolve", Handlers.utils.hasMatchingTag("Action", "Dissolve-Cave"), function(msg)
    assert(msg.From == Steward, "Unauthorized")
    state.traces, state.by_sender, state.by_combination, state.status = {}, {}, {}, "Dissolved"
end)

Handlers.add("GetStatus", Handlers.utils.hasMatchingTag("Action", "Get-Status"), function(msg)
    msg.reply({ Tags = { Action = "Status" }, Data = json.encode({ status = state.status, count = #state.traces })})
end)
