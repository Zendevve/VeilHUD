--------------------------------------------------------------------------------
-- ZenHUD / Immersion UI - Frame Controller
-- Per-frame fade animation management for WotLK 3.3.5a
--------------------------------------------------------------------------------

local ZenHUD = _G.ZenHUD
local Config = ZenHUD.Config

--------------------------------------------------------------------------------
-- FrameController - manages fade animation for a single frame
--------------------------------------------------------------------------------
local FrameController = {}
FrameController.__index = FrameController

--- Create a new controller for a frame
-- @param frame     The WoW frame to control
-- @param category  "hidden", "faded", or "chat"
function FrameController:New(frame, category)
    local instance = {
        frame = frame,
        name = frame:GetName() or "Unknown",
        category = category or "faded",

        -- Animation state
        animating = false,
        startAlpha = frame:GetAlpha() or 1,
        targetAlpha = 1,
        currentAlpha = frame:GetAlpha() or 1,
        duration = 0,
        elapsed = 0,

        -- Track original visibility for clean restore
        wasShown = frame:IsShown(),
    }

    setmetatable(instance, self)
    return instance
end

--- Animate to a target alpha
-- @param alpha     Target alpha (0.0 to 1.0)
-- @param duration  Animation duration in seconds (optional, uses config default)
function FrameController:FadeTo(alpha, duration)
    alpha = math.max(0, math.min(1, alpha))
    duration = math.max(0.05, duration or Config:Get("fadeTime") or 0.5)

    -- Skip if already at target and not animating
    if not self.animating and math.abs(self.currentAlpha - alpha) < 0.01 then
        return
    end

    -- Smooth interruption: always start from current position
    self.startAlpha = self.currentAlpha
    self.targetAlpha = alpha
    self.duration = duration
    self.elapsed = 0
    self.animating = true

    -- If fading in (increasing alpha), ensure frame is shown first
    if alpha > self.currentAlpha and not self.frame:IsShown() then
        self.frame:Show()
        self.frame:SetAlpha(self.currentAlpha)
    end
end

--- Process one animation tick
-- @param dt  Delta time from OnUpdate
function FrameController:Update(dt)
    if not self.animating then return end

    self.elapsed = self.elapsed + dt
    local progress = math.min(1, self.elapsed / self.duration)

    -- Linear interpolation from start to target
    self.currentAlpha = self.startAlpha + (self.targetAlpha - self.startAlpha) * progress
    self.frame:SetAlpha(self.currentAlpha)

    -- Animation complete
    if progress >= 1 then
        self.animating = false
        self.currentAlpha = self.targetAlpha
        self.frame:SetAlpha(self.targetAlpha)

        -- For "hidden" and "chat" category: call Hide() when fully faded out
        -- For "faded" category: never Hide(), only use alpha (keeps frame interactive)
        if self.targetAlpha <= 0.01 and self.category ~= "faded" then
            self.frame:Hide()
        end
    end
end

--- Instantly hide the frame (no animation)
function FrameController:HideInstant()
    self.animating = false
    self.currentAlpha = 0
    self.frame:SetAlpha(0)
    if self.category ~= "faded" then
        self.frame:Hide()
    end
end

--- Instantly restore the frame to full visibility
function FrameController:RestoreInstant()
    self.animating = false
    self.currentAlpha = 1
    self.frame:SetAlpha(1)
    -- Only re-show if the frame was originally shown (respect conditional frames)
    if self.wasShown then
        self.frame:Show()
    end
end

--- Force alpha to a value without animation (for enforcement checks)
-- @param targetAlpha  The alpha the frame should be at
function FrameController:Enforce(targetAlpha)
    if self.animating then return end  -- Don't interfere with active animations

    local actualAlpha = self.frame:GetAlpha()
    if math.abs(actualAlpha - targetAlpha) > 0.05 then
        self.frame:SetAlpha(targetAlpha)
        self.currentAlpha = targetAlpha
    end
end

-- Export to namespace
ZenHUD.FrameController = FrameController
