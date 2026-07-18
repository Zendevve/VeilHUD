local ADDON_NAME, ns = ...

ns.Utils = ns.Utils or {}

-- Small safe wrapper around string.match / strmatch.
-- Some UIs override or nil-out one of these, so we try both.
local function s_match(s, p)
  local sm = (_G and _G.string and _G.string.match) and _G.string.match or _G.strmatch
  if sm then return sm(s, p) end
  return nil
end
ns.Utils.s_match = s_match
ns.s_match = s_match

-- Addon logging prefix
local prefix = "|cFF66C2FF[VeilHUD]|r "
ns.Utils.prefix = prefix
ns.prefix = prefix

-- C_Timer.After polyfill for 3.3.5a (WotLK) where native C_Timer is not available
local C_TimerAfter
if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
  C_TimerAfter = C_Timer.After
else
  local pendingTimers = {}
  local timerFrame = CreateFrame("Frame")
  timerFrame:SetScript("OnUpdate", function(self, elapsed)
    local i = 1
    while i <= #pendingTimers do
      local timer = pendingTimers[i]
      timer.elapsed = timer.elapsed + elapsed
      if timer.elapsed >= timer.delay then
        table.remove(pendingTimers, i)
        if type(timer.func) == "function" then
          local ok, err = pcall(timer.func)
          if not ok and geterrorhandler then
            geterrorhandler()(err)
          end
        end
      else
        i = i + 1
      end
    end
  end)

  C_TimerAfter = function(delay, func)
    if type(func) ~= "function" then return end
    table.insert(pendingTimers, {
      delay = tonumber(delay) or 0,
      elapsed = 0,
      func = func,
    })
  end
end
_G.C_TimerAfter = C_TimerAfter
ns.Utils.C_TimerAfter = C_TimerAfter
ns.C_TimerAfter = C_TimerAfter

-- Normalizes a value into a boolean, accepting numbers and strings
-- like "1", "true", "on", "yes" / "0", "false", etc.
local function asBool(v, d)
  if v == nil then return d end
  local t = type(v)
  if t == "boolean" then return v end
  if t == "number"  then return v ~= 0 end
  if t == "string"  then
    local s = string.lower(v)
    if s == "1" or s == "true" or s == "on" or s == "yes" then return true end
    if s == "0" or s == "false" or s == "off" or s == "no" then return false end
    return d
  end
  return d
end
ns.Utils.asBool = asBool
ns.asBool = asBool

-- Global lookup helper that works even if getglobal is nil.
local function G(n)
  if getglobal then return getglobal(n) end
  if _G then return _G[n] end
end
ns.Utils.G = G
ns.G = G

-- Debug print helper (respects VeilHUDDB.debug flag).
local function dprint(msg)
  if VeilHUDDB and VeilHUDDB.debug then
    DEFAULT_CHAT_FRAME:AddMessage(ns.prefix .. "|cFFBBBBBB" .. msg .. "|r")
  end
end
ns.Utils.dprint = dprint
ns.dprint = dprint
