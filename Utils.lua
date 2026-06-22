--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Utils Module
-- Utility Functions for WotLK 3.3.5a
--------------------------------------------------------------------------------

local ZenHUD = _G.ZenHUD
local Config = ZenHUD.Config

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------
local Utils = {}

-- Print with Immersion UI prefix
function Utils.Print(msg, debugOnly)
    if debugOnly and not Config:Get("debug") then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF66C2FF[Immersion UI]|r " .. msg)
end

-- Clamp value between min and max
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Safe GetTime wrapper
function Utils.GetTime()
    return GetTime and GetTime() or 0
end

-- WotLK-compatible delayed callback (C_Timer doesn't exist in 3.3.5a)
-- Creates a temporary frame with OnUpdate for one-shot delayed execution
function Utils.After(delay, callback)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

-- Export to namespace
ZenHUD.Utils = Utils
