--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Frame Manager
-- Two-tier frame visibility management for WotLK 3.3.5a
-- Supports DragonFlight UI: Reforged (DFRL) detection
--------------------------------------------------------------------------------

local ZenHUD = _G.ZenHUD
local Config = ZenHUD.Config
local Utils = ZenHUD.Utils
local FrameController = ZenHUD.FrameController

--------------------------------------------------------------------------------
-- Frame Manager
--------------------------------------------------------------------------------
local FrameManager = {
    hiddenControllers = {},     -- Frames that are completely hidden (alpha 0)
    fadedControllers = {},      -- Frames that fade between alpha levels
    chatControllers = {},       -- Chat frames (toggle via /imui showchat/hidechat)
    updateFrame = nil,          -- OnUpdate driver frame
    enforcementTimer = 0,       -- Periodic alpha enforcement timer
    currentFadedAlpha = 0.4,    -- Current target alpha for faded frames
    initialized = false,
}

--------------------------------------------------------------------------------
-- Frame Definitions
--------------------------------------------------------------------------------

-- HIDDEN: Completely hidden when addon is enabled (alpha 0, frame:Hide())
local HIDDEN_FRAMES = {
    -- Minimap cluster (entire minimap area)
    "MinimapCluster",
    "Minimap",

    -- Unit frames
    "PlayerFrame",
    "TargetFrame",
    "TargetFrameToT",
    "PetFrame",

    -- Objective tracker
    "WatchFrame",
    "QuestWatchFrame",
    "QuestTimerFrame",

    -- Vehicle
    "VehicleSeatIndicator",

    -- Social/Emotes
    "SocialsMicroButton",
}

-- FADED: Visible at reduced alpha, adjusts based on combat/mouseover/resting
-- 40% idle → 80% combat/target → 100% mouseover/resting
local FADED_FRAMES = {
    -- Buffs
    "BuffFrame",
    "TemporaryEnchantFrame",

    -- Action bars
    "MainMenuBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarLeft",
    "MultiBarRight",
    "PetActionBarFrame",
    "ShapeshiftBarFrame",
    "BonusActionBarFrame",
    "VehicleMenuBar",

    -- XP / Rep bars
    "MainMenuExpBar",
    "MainMenuBarMaxLevelBar",
    "ReputationWatchBar",

    -- Art frame (action bar background)
    "MainMenuBarArtFrame",

    -- Micro buttons (part of action bar area)
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "QuestLogMicroButton",
    "WorldMapMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",

    -- Bags
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "KeyRingButton",

    -- Unit frame extras (cast bars, runes)
    "PetCastingBarFrame",
    "RuneFrame",
}

-- CHAT: Handled separately (toggleable via /imui showchat/hidechat)
local CHAT_FRAMES = {
    "ChatFrame1",
    "ChatFrame2",
    "ChatFrame3",
    "ChatFrame4",
    "ChatFrame5",
    "ChatFrame6",
    "ChatFrame7",
    "ChatFrameMenuButton",
    "ChatFrame1UpButton",
    "ChatFrame1DownButton",
    "ChatFrame1BottomButton",
    "ChatFrame1Tab",
    "GeneralDockManager",
}

-- DragonFlight UI: Reforged - Hidden frames
local DFRL_HIDDEN = {
    "DFRL_GryphonContainer",
    "DFRLBagToggleButton",
    "DFRLEBCMicroButton",
    "DFRLLFTMicroButton",
    "DFRLPvPMicroButton",
    "DFRL_NetStatsFrame",
    "DFRL_LatencyIndicator",
    "DFRLLowLevelTalentsButton",
}

-- DragonFlight UI: Reforged - Faded frames
local DFRL_FADED = {
    "DFRL_ShapeshiftBar",
    "DFRL_MainBar",
    "DFRL_RepBar",
    "DFRL_XPBar",
    "DFRL_PagingContainer",
    "DFRL_ActionBar",
}

-- Conditional frames: don't force Show() when restoring (they appear contextually)
local CONDITIONAL_FRAMES = {
    PetFrame = true,
    TargetFrame = true,
    TargetFrameToT = true,
    PetCastingBarFrame = true,
    VehicleMenuBar = true,
    VehicleSeatIndicator = true,
    RuneFrame = true,
    BonusActionBarFrame = true,
}

--------------------------------------------------------------------------------
-- Internal helpers
--------------------------------------------------------------------------------

-- Register a single frame into a controller table
local function RegisterFrame(controllerTable, frameName, category)
    local frame = _G[frameName]
    if frame and frame.SetAlpha and frame.Show and frame.Hide then
        local controller = FrameController:New(frame, category)
        -- For conditional frames, mark wasShown based on current context
        if CONDITIONAL_FRAMES[frameName] then
            controller.wasShown = frame:IsShown()
        end
        table.insert(controllerTable, controller)
        Utils.Print("Registered: " .. frameName .. " [" .. category .. "]", true)
    else
        Utils.Print("Skipped: " .. frameName .. " (not found)", true)
    end
end

--------------------------------------------------------------------------------
-- FrameManager API
--------------------------------------------------------------------------------

--- Initialize all frame controllers and start the animation loop
function FrameManager:Initialize()
    -- Clear previous controllers (for re-initialization)
    self.hiddenControllers = {}
    self.fadedControllers = {}
    self.chatControllers = {}

    -- Register Blizzard hidden frames
    for _, name in ipairs(HIDDEN_FRAMES) do
        RegisterFrame(self.hiddenControllers, name, "hidden")
    end

    -- Register Blizzard faded frames
    for _, name in ipairs(FADED_FRAMES) do
        RegisterFrame(self.fadedControllers, name, "faded")
    end

    -- Register chat frames
    for _, name in ipairs(CHAT_FRAMES) do
        RegisterFrame(self.chatControllers, name, "chat")
    end

    -- Detect and register DragonFlight UI: Reforged frames
    self:DetectDFRL()

    -- Create the animation update frame
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
        self.updateFrame:SetScript("OnUpdate", function(_, dt)
            self:Update(dt)
        end)
    end

    self.initialized = true

    local total = #self.hiddenControllers + #self.fadedControllers + #self.chatControllers
    Utils.Print(string.format("Managing %d frames (%d hidden, %d faded, %d chat)",
        total, #self.hiddenControllers, #self.fadedControllers, #self.chatControllers), true)
end

--- Detect DragonFlight UI: Reforged and register its frames
function FrameManager:DetectDFRL()
    -- Check if any DFRL frame exists in the global namespace
    local hasDFRL = false
    for _, name in ipairs(DFRL_HIDDEN) do
        if _G[name] then
            hasDFRL = true
            break
        end
    end
    if not hasDFRL then
        for _, name in ipairs(DFRL_FADED) do
            if _G[name] then
                hasDFRL = true
                break
            end
        end
    end

    if not hasDFRL then
        Utils.Print("DFRL not detected", true)
        return
    end

    Utils.Print("DragonFlight UI: Reforged detected!", true)

    for _, name in ipairs(DFRL_HIDDEN) do
        RegisterFrame(self.hiddenControllers, name, "hidden")
    end

    for _, name in ipairs(DFRL_FADED) do
        RegisterFrame(self.fadedControllers, name, "faded")
    end
end

--- Enable immersion mode — apply all visibility rules
function FrameManager:Enable()
    -- Hide all hidden frames
    for _, controller in ipairs(self.hiddenControllers) do
        controller:FadeTo(0, Config:Get("fadeTime"))
    end

    -- Set faded frames to idle alpha
    local fadedAlpha = Config:Get("fadedAlpha")
    self.currentFadedAlpha = fadedAlpha
    for _, controller in ipairs(self.fadedControllers) do
        controller:FadeTo(fadedAlpha, Config:Get("fadeTime"))
    end

    -- Apply chat visibility
    self:SetChatVisible(Config:Get("showChat"))
end

--- Disable immersion mode — restore all frames to full visibility
function FrameManager:Disable()
    -- Restore hidden frames
    for _, controller in ipairs(self.hiddenControllers) do
        controller:FadeTo(1, Config:Get("fadeTime"))
        -- Ensure the frame is shown (in case it was Hide()'d)
        if controller.wasShown then
            controller.frame:Show()
            controller.frame:SetAlpha(controller.currentAlpha)
        end
    end

    -- Restore faded frames
    self.currentFadedAlpha = 1
    for _, controller in ipairs(self.fadedControllers) do
        controller:FadeTo(1, Config:Get("fadeTime"))
    end

    -- Restore chat
    for _, controller in ipairs(self.chatControllers) do
        controller:FadeTo(1, Config:Get("fadeTime"))
        controller.frame:Show()
    end
end

--- Set the target alpha for all faded frames
-- @param alpha  Target alpha (0.4 = idle, 0.8 = combat, 1.0 = mouseover/resting)
function FrameManager:SetFadedAlpha(alpha)
    if math.abs(self.currentFadedAlpha - alpha) < 0.01 then return end

    self.currentFadedAlpha = alpha
    local duration = Config:Get("fadeTime")

    for _, controller in ipairs(self.fadedControllers) do
        controller:FadeTo(alpha, duration)
    end
end

--- Toggle chat frame visibility
-- @param show  true to show, false to hide
function FrameManager:SetChatVisible(show)
    local duration = Config:Get("fadeTime")

    if show then
        for _, controller in ipairs(self.chatControllers) do
            controller.frame:Show()
            controller:FadeTo(1, duration)
        end
    else
        for _, controller in ipairs(self.chatControllers) do
            -- Use alpha 0 (not Hide) so the edit box remains functional
            controller:FadeTo(0, duration)
        end
    end
end

--- Animation update tick — drives all controller animations
function FrameManager:Update(dt)
    -- Update hidden controllers
    for _, controller in ipairs(self.hiddenControllers) do
        controller:Update(dt)
    end

    -- Update faded controllers
    for _, controller in ipairs(self.fadedControllers) do
        controller:Update(dt)
    end

    -- Update chat controllers
    for _, controller in ipairs(self.chatControllers) do
        controller:Update(dt)
    end

    -- Periodic enforcement: re-apply alpha if WoW's internal code resets it
    self.enforcementTimer = self.enforcementTimer + dt
    if self.enforcementTimer >= 0.5 then
        self.enforcementTimer = 0
        if Config:Get("enabled") then
            self:EnforceAlpha()
        end
    end
end

--- Enforce correct alpha on faded frames (catches WoW's internal alpha resets)
function FrameManager:EnforceAlpha()
    for _, controller in ipairs(self.fadedControllers) do
        controller:Enforce(self.currentFadedAlpha)
    end
end

--- Get count of managed frames
function FrameManager:Count()
    return #self.hiddenControllers + #self.fadedControllers + #self.chatControllers
end

-- Export to namespace
ZenHUD.FrameManager = FrameManager
