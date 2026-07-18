local ADDON_NAME, ns = ...

ns.Config = ns.Config or {}

-- Delay tweaks
ns.Config.TARGET_GRACE    = 5.0   -- seconds to keep UI visible after losing a living target
ns.Config.MOUSEOVER_GRACE = 12.0  -- seconds to keep UI visible after leaving action bars
ns.Config.CLOSE_WINDOWS_ON_FADE = false -- close game windows on fade if enabled

-- Helper to close open game windows when allowed by config
local function CloseWindowsIfAllowed()
  if ns.Config.CLOSE_WINDOWS_ON_FADE and CloseAllWindows then
    CloseAllWindows()
  end
end
ns.Config.CloseWindowsIfAllowed = CloseWindowsIfAllowed

-- Returns a brand-new default DB table.
local function FreshDB()
  return { enabled = true, debug = false, showOnTarget = true, fadeTime = 3.0 }
end
ns.Config.FreshDB = FreshDB

-- Initializes VeilHUDDB, filling defaults and normalizing types.
local function InitDB()
  if type(VeilHUDDB) ~= "table" then VeilHUDDB = FreshDB() end
  VeilHUDDB.enabled      = ns.asBool(VeilHUDDB.enabled, true)
  VeilHUDDB.debug        = ns.asBool(VeilHUDDB.debug,   false)
  VeilHUDDB.showOnTarget = ns.asBool(VeilHUDDB.showOnTarget, true)
  VeilHUDDB.fadeTime     = tonumber(VeilHUDDB.fadeTime or 3.0)
end
ns.Config.InitDB = InitDB
ns.InitDB = InitDB
