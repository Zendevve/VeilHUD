--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Compass Module
-- Floating compass widget for WotLK 3.3.5a
-- Replaces the minimap for directional awareness
--------------------------------------------------------------------------------

local ZenHUD = _G.ZenHUD
local Config = ZenHUD.Config
local Utils = ZenHUD.Utils

--------------------------------------------------------------------------------
-- Compass Module
--------------------------------------------------------------------------------
local Compass = {
    frame = nil,
    directionText = nil,
    degreeText = nil,
    needleTexture = nil,
    updateTimer = 0,
    UPDATE_INTERVAL = 0.05,  -- 20 FPS update rate
}

--------------------------------------------------------------------------------
-- Cardinal direction lookup
--------------------------------------------------------------------------------
local DIRECTION_NAMES = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

-- Returns cardinal direction string from compass degrees (0-360, clockwise from N)
local function GetCardinal(degrees)
    local shifted = (degrees + 22.5) % 360
    local index = math.floor(shifted / 45) + 1
    return DIRECTION_NAMES[index] or "?"
end

-- Returns compass degrees from WoW facing (0=N, increases counterclockwise)
local function FacingToDegrees(facing)
    return (360 - math.deg(facing)) % 360
end

--------------------------------------------------------------------------------
-- Direction colors: gold for N, silver for others
--------------------------------------------------------------------------------
local function GetDirectionColor(direction)
    if direction == "N" then
        return 1.0, 0.84, 0.0   -- Gold
    elseif direction == "S" then
        return 0.7, 0.7, 0.7    -- Dim silver
    else
        return 0.9, 0.9, 0.9    -- Light silver
    end
end

--------------------------------------------------------------------------------
-- Create the compass frame
--------------------------------------------------------------------------------
function Compass:Create()
    if self.frame then return end

    -- Main frame
    local frame = CreateFrame("Frame", "ZenHUDCompass", UIParent)
    frame:SetSize(52, 44)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(10)
    frame:SetClampedToScreen(true)

    -- Dark semi-transparent backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.7)

    -- Direction letter (large, centered)
    local dirText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dirText:SetPoint("CENTER", frame, "CENTER", 0, 4)
    dirText:SetText("N")
    dirText:SetTextColor(1, 0.84, 0)
    self.directionText = dirText

    -- Degree number (small, below direction)
    local degText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    degText:SetPoint("TOP", dirText, "BOTTOM", 0, -1)
    degText:SetText("0")
    degText:SetTextColor(0.5, 0.5, 0.5, 0.8)
    self.degreeText = degText

    -- North indicator dot (small gold dot at top edge)
    local northDot = frame:CreateTexture(nil, "ARTWORK")
    northDot:SetSize(6, 6)
    northDot:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    northDot:SetVertexColor(1, 0.84, 0, 0.9)
    northDot:SetPoint("TOP", frame, "TOP", 0, -3)

    -- Make draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position relative to UIParent center
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        Config:Set("compassX", cx - ux)
        Config:Set("compassY", cy - uy)
    end)

    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Immersion UI Compass")
        GameTooltip:AddLine("|cFFAAAAAAdrag to reposition|r")
        GameTooltip:AddLine("|cFFAAAAAA/imui hidecompass|r to hide")
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- OnUpdate for compass heading
    frame:SetScript("OnUpdate", function(_, dt)
        Compass:OnUpdate(dt)
    end)

    self.frame = frame
    frame:Hide()  -- Start hidden, Show() called during initialization
end

--------------------------------------------------------------------------------
-- Position management
--------------------------------------------------------------------------------

--- Restore saved position or use default
function Compass:RestorePosition()
    if not self.frame then return end

    local x = Config:Get("compassX")
    local y = Config:Get("compassY")

    self.frame:ClearAllPoints()

    if x and y then
        -- Restore saved position (relative to UIParent center)
        self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    else
        -- Default: top-center, just below screen edge
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, -15)
    end
end

--------------------------------------------------------------------------------
-- Update loop
--------------------------------------------------------------------------------

function Compass:OnUpdate(dt)
    -- Throttle updates
    self.updateTimer = self.updateTimer + dt
    if self.updateTimer < self.UPDATE_INTERVAL then return end
    self.updateTimer = 0

    -- Get player facing (returns nil in some contexts)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing then return end

    -- Convert to compass degrees (0=N, clockwise)
    local degrees = FacingToDegrees(facing)
    local direction = GetCardinal(degrees)

    -- Update direction text
    self.directionText:SetText(direction)
    local r, g, b = GetDirectionColor(direction)
    self.directionText:SetTextColor(r, g, b)

    -- Update degree text
    self.degreeText:SetText(string.format("%d", math.floor(degrees + 0.5)))
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Compass:Show()
    if not self.frame then self:Create() end
    self:RestorePosition()
    self.frame:Show()
end

function Compass:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Compass:IsShown()
    return self.frame and self.frame:IsShown()
end

--- Full initialization (call after Config is ready)
function Compass:Initialize()
    self:Create()
    self:RestorePosition()

    -- Show based on config
    if Config:Get("enabled") and Config:Get("showCompass") then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

-- Export to namespace
ZenHUD.Compass = Compass
