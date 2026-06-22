--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Config Module
-- Per-Character Settings for WotLK 3.3.5a
--------------------------------------------------------------------------------

local ADDON_NAME = "ZenHUD"

-- Create ZenHUD namespace (first file loaded)
if not _G.ZenHUD then
    _G.ZenHUD = {
        version = "2.0.0",
        loaded = false,
    }
end

local ZenHUD = _G.ZenHUD

--------------------------------------------------------------------------------
-- Config Module
--------------------------------------------------------------------------------
local Config = {}

-- All settings are per-character (SavedVariablesPerCharacter: ZenHUDCharDB)
Config.defaults = {
    -- Core toggle
    enabled = false,            -- Off by default per spec

    -- Compass
    showCompass = true,         -- Compass visible by default
    compassX = nil,             -- Compass X position (nil = default top-center)
    compassY = nil,             -- Compass Y position (nil = default top-center)

    -- Chat visibility
    showChat = false,           -- Chat hidden by default

    -- Alpha levels
    fadedAlpha = 0.4,           -- 40% opacity for faded frames at idle
    combatAlpha = 0.8,          -- 80% opacity for faded frames in combat

    -- Animation
    fadeTime = 0.5,             -- Fade animation duration in seconds

    -- Grace periods (seconds after trigger ends)
    graceCombat = 8.0,          -- Post-combat grace period
    graceTarget = 2.0,          -- Post-target-loss grace period
    graceMouseover = 2.0,       -- Post-mouseover grace period

    -- Debug
    debug = false,              -- Debug messages in chat
}

function Config:Initialize()
    -- Initialize per-character DB
    if type(ZenHUDCharDB) ~= "table" then
        ZenHUDCharDB = {}
    end

    -- Merge defaults for any missing keys
    for key, defaultValue in pairs(self.defaults) do
        if ZenHUDCharDB[key] == nil then
            ZenHUDCharDB[key] = defaultValue
        end
    end
end

function Config:Get(key)
    if ZenHUDCharDB and ZenHUDCharDB[key] ~= nil then
        return ZenHUDCharDB[key]
    end
    return self.defaults[key]
end

function Config:Set(key, value)
    if not ZenHUDCharDB then
        ZenHUDCharDB = {}
    end
    ZenHUDCharDB[key] = value
end

-- Export to namespace
ZenHUD.Config = Config
