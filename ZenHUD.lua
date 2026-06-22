--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Main Entry Point
-- Events, slash commands, state evaluation for WotLK 3.3.5a
--
-- "Best of both worlds": two-tier hidden/faded model from Immersion UI spec
-- combined with smart triggers (mouseover, combat, target, resting) from ZenHUD
--------------------------------------------------------------------------------

local ADDON_NAME = "ZenHUD"
local VERSION = "2.0.0"

local ZenHUD = _G.ZenHUD
ZenHUD.version = VERSION

-- Module references (loaded from separate files via .toc)
local Config = ZenHUD.Config
local Utils = ZenHUD.Utils
local FrameManager = ZenHUD.FrameManager
local Compass = ZenHUD.Compass

--------------------------------------------------------------------------------
-- State Tracking
--------------------------------------------------------------------------------
local State = {
    inCombat = false,
    hasLivingTarget = false,
    isResting = false,
    mouseoverUI = false,

    -- Grace period deadlines (GetTime() values)
    graceUntil = {
        combat = 0,
        target = 0,
        mouseover = 0,
    },

    -- Zone debouncing
    lastZoneTime = 0,
    pendingZoneCheck = false,

    -- Mouseover detection
    lastMouseoverState = false,
    mouseoverTimer = 0,
    MOUSEOVER_INTERVAL = 0.05,  -- Check every 50ms
}

--------------------------------------------------------------------------------
-- Mouseover Detection (action bar area)
--------------------------------------------------------------------------------

--- Check if a frame name belongs to the action bar area
local function IsActionBarFrame(name)
    if not name then return false end

    -- Blizzard action buttons
    if string.find(name, "ActionButton") then return true end
    if string.find(name, "MultiBar") then return true end
    if string.find(name, "PetActionButton") then return true end
    if string.find(name, "ShapeshiftButton") then return true end
    if string.find(name, "BonusActionButton") then return true end

    -- Action bar containers
    if name == "MainMenuBar" then return true end
    if name == "PetActionBarFrame" then return true end
    if name == "ShapeshiftBarFrame" then return true end
    if name == "MainMenuBarArtFrame" then return true end

    -- Micro buttons and bags (part of the bottom bar area)
    if string.find(name, "MicroButton") then return true end
    if string.find(name, "Bag") then return true end
    if name == "KeyRingButton" then return true end
    if name == "MainMenuExpBar" then return true end
    if name == "ReputationWatchBar" then return true end

    -- Player frame (mouseover to see HP)
    if name == "PlayerFrame" or string.find(name, "^PlayerFrame") then return true end

    -- DragonFlight UI: Reforged
    if string.find(name, "^DFRL_") then return true end
    if string.find(name, "^DFRL") then return true end

    return false
end

--- Mouseover detection polling (called from OnUpdate)
local function CheckMouseover(dt)
    State.mouseoverTimer = State.mouseoverTimer + dt
    if State.mouseoverTimer < State.MOUSEOVER_INTERVAL then return end
    State.mouseoverTimer = 0

    local focus = GetMouseFocus and GetMouseFocus()
    local name = focus and focus.GetName and focus:GetName()
    local isOver = IsActionBarFrame(name)

    if isOver ~= State.lastMouseoverState then
        State.lastMouseoverState = isOver
        SetMouseover(isOver)
    end
end

--------------------------------------------------------------------------------
-- State Setters
--------------------------------------------------------------------------------

--- Handle mouseover state change
function SetMouseover(mouseoverUI)
    local wasMouseover = State.mouseoverUI
    State.mouseoverUI = mouseoverUI

    if mouseoverUI then
        -- Entering UI area: cancel mouseover grace
        State.graceUntil.mouseover = 0
        Utils.Print("Mouseover: entering UI area", true)
    else
        -- Leaving UI area: start grace period
        if wasMouseover then
            local grace = Config:Get("graceMouseover")
            State.graceUntil.mouseover = Utils.GetTime() + grace
            Utils.Print(string.format("Mouseover: left UI, %.1fs grace", grace), true)

            Utils.After(grace, function()
                State.graceUntil.mouseover = 0
                Evaluate("mouseover_grace_expired")
            end)
        end
    end

    Evaluate("mouseover_" .. (mouseoverUI and "enter" or "leave"))
end

--- Handle combat state change
local function SetCombat(inCombat)
    State.inCombat = inCombat

    if inCombat then
        -- Entering combat: clear all grace periods
        for k in pairs(State.graceUntil) do
            State.graceUntil[k] = 0
        end
        Utils.Print("Combat: ENTERING", true)
    else
        -- Leaving combat: start grace period
        local grace = Config:Get("graceCombat")
        State.graceUntil.combat = Utils.GetTime() + grace
        Utils.Print(string.format("Combat: LEAVING, %.1fs grace", grace), true)

        Utils.After(grace, function()
            State.graceUntil.combat = 0
            Evaluate("combat_grace_expired")
        end)
    end

    Evaluate("combat_" .. (inCombat and "enter" or "leave"))
end

--- Handle target change
local function SetTarget(hasTarget, isAlive)
    local hadLivingTarget = State.hasLivingTarget
    State.hasLivingTarget = hasTarget and isAlive

    if hasTarget and isAlive then
        -- Acquired living target: cancel target grace
        State.graceUntil.target = 0
        Utils.Print("Target: acquired living target", true)
    elseif not hasTarget and hadLivingTarget then
        -- Lost living target: start grace period
        local grace = Config:Get("graceTarget")
        State.graceUntil.target = Utils.GetTime() + grace
        Utils.Print(string.format("Target: lost, %.1fs grace", grace), true)

        Utils.After(grace, function()
            State.graceUntil.target = 0
            Evaluate("target_grace_expired")
        end)
    end

    Evaluate("target_changed")
end

--- Handle resting state change (debounced for zone transitions)
local function SetResting(isResting)
    State.isResting = isResting
    Evaluate("resting_" .. (isResting and "enter" or "leave"))
end

--- Debounced zone change handler
local function OnZoneChanged()
    local ZONE_DEBOUNCE = 0.6
    local now = Utils.GetTime()

    if now - State.lastZoneTime < ZONE_DEBOUNCE then
        -- Within debounce window: schedule delayed check
        State.pendingZoneCheck = true
        local timeLeft = ZONE_DEBOUNCE - (now - State.lastZoneTime)
        if timeLeft < 0.05 then timeLeft = 0.05 end

        Utils.After(timeLeft, function()
            if State.pendingZoneCheck then
                State.pendingZoneCheck = false
                SetResting(IsResting())
            end
        end)
        return
    end

    -- Outside debounce window: update immediately
    State.lastZoneTime = now
    SetResting(IsResting())
end

--------------------------------------------------------------------------------
-- Core Evaluation — determines the correct alpha for faded frames
--------------------------------------------------------------------------------

--- Evaluate current state and apply the appropriate alpha to faded frames
-- Priority (highest wins):
--   1. Resting (in town/inn) → 100%
--   2. Mouseover action bars → 100%
--   3. In combat → 80%
--   4. Has living target → 80%
--   5. Post-combat grace → 80%
--   6. Post-target grace → 80%
--   7. Post-mouseover grace → 100%
--   8. Default idle → 40%
function Evaluate(reason)
    if not Config:Get("enabled") then return end
    if not ZenHUD.loaded then return end

    local now = Utils.GetTime()
    local targetAlpha

    -- Priority 1: Resting → full visibility for faded frames
    if State.isResting then
        targetAlpha = 1.0

    -- Priority 2: Mouseover → full visibility
    elseif State.mouseoverUI then
        targetAlpha = 1.0

    -- Priority 3: In combat → combat alpha
    elseif State.inCombat then
        targetAlpha = Config:Get("combatAlpha")

    -- Priority 4: Has living target → combat alpha
    elseif State.hasLivingTarget then
        targetAlpha = Config:Get("combatAlpha")

    -- Priority 5-6: Combat/target grace → combat alpha
    elseif State.graceUntil.combat > now or State.graceUntil.target > now then
        targetAlpha = Config:Get("combatAlpha")

    -- Priority 7: Mouseover grace → full visibility
    elseif State.graceUntil.mouseover > now then
        targetAlpha = 1.0

    -- Priority 8: Default idle
    else
        targetAlpha = Config:Get("fadedAlpha")
    end

    Utils.Print(string.format("Evaluate [%s]: alpha=%.0f%% (combat=%s, target=%s, hover=%s, rest=%s)",
        reason or "?",
        targetAlpha * 100,
        tostring(State.inCombat),
        tostring(State.hasLivingTarget),
        tostring(State.mouseoverUI),
        tostring(State.isResting)
    ), true)

    FrameManager:SetFadedAlpha(targetAlpha)
end

--------------------------------------------------------------------------------
-- Slash Commands: /imui
--------------------------------------------------------------------------------
SLASH_IMUI1 = "/imui"

local function ShowHelp()
    Utils.Print("Immersion UI v" .. VERSION)
    print("  |cFF00FF00/imui on|r — Enable immersion mode")
    print("  |cFF00FF00/imui off|r — Disable immersion mode")
    print("  |cFF00FF00/imui showcompass|r — Show compass")
    print("  |cFF00FF00/imui hidecompass|r — Hide compass")
    print("  |cFF00FF00/imui showchat|r — Show chat frames")
    print("  |cFF00FF00/imui hidechat|r — Hide chat frames")
    print("  |cFF00FF00/imui status|r — Show current status")
    print("  |cFF00FF00/imui debug|r — Toggle debug mode")
end

SlashCmdList["IMUI"] = function(msg)
    msg = string.lower(msg or "")
    local cmd = string.match(msg, "^(%S+)") or ""

    if cmd == "on" then
        Config:Set("enabled", true)
        FrameManager:Enable()
        -- Show compass if configured
        if Config:Get("showCompass") then
            Compass:Show()
        end
        -- Set initial state
        State.isResting = IsResting()
        State.inCombat = UnitAffectingCombat("player")
        local hasTarget = UnitExists("target")
        local isAlive = hasTarget and not UnitIsDeadOrGhost("target")
        State.hasLivingTarget = hasTarget and isAlive
        Evaluate("enabled")
        Utils.Print("Immersion mode |cFF00FF00enabled|r")

    elseif cmd == "off" then
        Config:Set("enabled", false)
        FrameManager:Disable()
        Compass:Hide()
        Utils.Print("Immersion mode |cFFFF4444disabled|r")

    elseif cmd == "showcompass" then
        Config:Set("showCompass", true)
        if Config:Get("enabled") then
            Compass:Show()
        end
        Utils.Print("Compass |cFF00FF00shown|r")

    elseif cmd == "hidecompass" then
        Config:Set("showCompass", false)
        Compass:Hide()
        Utils.Print("Compass |cFFFF4444hidden|r")

    elseif cmd == "showchat" then
        Config:Set("showChat", true)
        if Config:Get("enabled") then
            FrameManager:SetChatVisible(true)
        end
        Utils.Print("Chat |cFF00FF00shown|r")

    elseif cmd == "hidechat" then
        Config:Set("showChat", false)
        if Config:Get("enabled") then
            FrameManager:SetChatVisible(false)
        end
        Utils.Print("Chat |cFFFF4444hidden|r")

    elseif cmd == "status" then
        Utils.Print("Status:")
        print(string.format("  Enabled: %s", Config:Get("enabled") and "|cFF00FF00Yes|r" or "|cFFFF4444No|r"))
        print(string.format("  Compass: %s", Config:Get("showCompass") and "|cFF00FF00Shown|r" or "|cFFFF4444Hidden|r"))
        print(string.format("  Chat: %s", Config:Get("showChat") and "|cFF00FF00Shown|r" or "|cFFFF4444Hidden|r"))
        print(string.format("  In Combat: %s", State.inCombat and "Yes" or "No"))
        print(string.format("  Has Target: %s", State.hasLivingTarget and "Yes" or "No"))
        print(string.format("  Resting: %s", State.isResting and "Yes" or "No"))
        print(string.format("  Mouseover: %s", State.mouseoverUI and "Yes" or "No"))
        print(string.format("  Frames managed: %d", FrameManager:Count()))

    elseif cmd == "debug" then
        local debug = not Config:Get("debug")
        Config:Set("debug", debug)
        Utils.Print(string.format("Debug mode %s", debug and "|cFF00FF00enabled|r" or "|cFFFF4444disabled|r"))

    elseif cmd == "" or cmd == "help" then
        ShowHelp()

    else
        Utils.Print("Unknown command: " .. cmd)
        ShowHelp()
    end
end

--------------------------------------------------------------------------------
-- Event Handler
--------------------------------------------------------------------------------
local EventFrame = CreateFrame("Frame")

EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
EventFrame:RegisterEvent("ZONE_CHANGED")
EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- Mouseover detection OnUpdate
local mouseoverFrame = CreateFrame("Frame")
mouseoverFrame:SetScript("OnUpdate", function(_, dt)
    if not ZenHUD.loaded then return end
    if not Config:Get("enabled") then return end
    CheckMouseover(dt)
end)

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        ZenHUD:Initialize()

    elseif event == "PLAYER_REGEN_DISABLED" then
        SetCombat(true)

    elseif event == "PLAYER_REGEN_ENABLED" then
        SetCombat(false)

    elseif event == "PLAYER_TARGET_CHANGED" then
        local hasTarget = UnitExists("target")
        local isAlive = hasTarget and not UnitIsDeadOrGhost("target")
        SetTarget(hasTarget, isAlive)

    elseif event == "PLAYER_UPDATE_RESTING" then
        SetResting(IsResting())

        -- Failsafe timers for resting state (some zones report late)
        if IsResting() then
            Utils.After(1.0, function()
                if ZenHUD.loaded and IsResting() then
                    Evaluate("resting_failsafe_1")
                end
            end)
            Utils.After(3.5, function()
                if ZenHUD.loaded and IsResting() then
                    Evaluate("resting_failsafe_2")
                end
            end)
        end

    elseif event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS"
        or event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChanged()
    end
end)

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
function ZenHUD:Initialize()
    if self.loaded then return end

    -- Initialize config (merge defaults into SavedVariables)
    Config:Initialize()

    Utils.Print(string.format("v%s loaded", VERSION))

    -- Initialize frame management
    FrameManager:Initialize()

    -- Retry after 300ms for late-loading frames
    Utils.After(0.3, function()
        FrameManager:Initialize()
    end)

    -- Initialize compass
    Compass:Initialize()

    -- Delayed activation (give all frames time to load)
    Utils.After(2.0, function()
        self.loaded = true

        -- Set initial state
        State.inCombat = UnitAffectingCombat("player")
        State.isResting = IsResting()
        local hasTarget = UnitExists("target")
        local isAlive = hasTarget and not UnitIsDeadOrGhost("target")
        State.hasLivingTarget = hasTarget and isAlive
        State.mouseoverUI = false

        -- Apply settings if enabled
        if Config:Get("enabled") then
            FrameManager:Enable()
            if Config:Get("showCompass") then
                Compass:Show()
            end
            Evaluate("initial")
            Utils.Print("Immersion mode active")
        else
            Utils.Print("Type |cFF00FF00/imui on|r to enable immersion mode")
        end
    end)
end
