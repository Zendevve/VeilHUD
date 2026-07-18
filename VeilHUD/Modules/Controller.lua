local ADDON_NAME, ns = ...

ns.Controller = ns.Controller or {}
ns.Controllers = ns.Controllers or {}

-- ===================== FIXED LIST OF FRAMES =====================
-- List of frames controlled by VeilHUD.
local FRAME_NAMES = {
  -- Action bars
  "MainMenuBar",
  "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
  "PetActionBarFrame",

  -- MicroMenu (includes the WotLK-only buttons: Achievement, PVP, LFD/Dungeon Finder)
  "CharacterMicroButton","SpellbookMicroButton","TalentMicroButton",
  "AchievementMicroButton","QuestLogMicroButton","SocialsMicroButton",
  "PVPMicroButton","LFDMicroButton","WorldMapMicroButton",
  "MainMenuMicroButton","HelpMicroButton",

  -- Bags
  "MainMenuBarBackpackButton","CharacterBag0Slot","CharacterBag1Slot",
  "CharacterBag2Slot","CharacterBag3Slot","KeyRingButton",

  -- Unit frames
  "PlayerFrame","PetFrame","TargetFrameToT",

  -- ChatFrame
  "ChatFrameMenuButton","ChatFrame1UpButton","ChatFrame1DownButton","ChatFrame1BottomButton",

  -- Quest tracker
  "QuestWatchFrame",

  -- Cast/Buffs
  "PetCastingBarFrame",
  "BuffFrame","TemporaryEnchantFrame",
}
ns.Controller.FRAME_NAMES = FRAME_NAMES

-- Frames we must NOT force :Show() on (conditional frames).
local DO_NOT_FORCE_SHOW = {
  TargetFrameToT = true,
  PetFrame = true,
  PetCastingBarFrame = true,
}
ns.Controller.DO_NOT_FORCE_SHOW = DO_NOT_FORCE_SHOW

-- Bars/frames that should only alpha-fade (we do NOT call :Hide() at the end).
local FADE_ONLY = {
  MainMenuBar = true,
  MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarLeft = true, MultiBarRight = true,
  PetActionBarFrame = true,
  PetFrame = true,
}
ns.Controller.FADE_ONLY = FADE_ONLY

-- Creates a controller object for a single frame.
local function NewController(fr)
  local function IsBuffLike(name)
    return name == "BuffFrame" or name == "TemporaryEnchantFrame"
  end

  local c = {}
  c.frame = fr
  c.fadeCtrl = CreateFrame("Frame"); c.fadeCtrl:Hide()
  c.Fade = { active=false, target=nil, start=1, elapsed=0, duration=3.0 }
  c.resume = fr:IsShown()
  c.deferFadeIn = false      -- defers fade-in if a fade-out is in progress (buffs only)
  c.deferReason = nil        -- optional: remember reason
  c.deferFadeOut = false
  c.deferOutReason = nil

  local function GetAlphaSafe()
    local a = c.frame and c.frame.GetAlpha and c.frame:GetAlpha() or 1
    return a or 1
  end

  local function ClampDuration(x)
    x = tonumber(x or 0) or 0
    if x < 0.05 then x = 0.05 end
    return x
  end

  function c:StartFade(targetAlpha, reason)
    if not self.frame then return end
    local name = self.frame:GetName() or ""

    -- Minimal anti-flicker: if Buff-like is mid fade-IN and fade-OUT is requested, defer the OUT
    if IsBuffLike(name) and targetAlpha == 0 and self.Fade.active and self.Fade.target == 1 then
      self.deferFadeOut  = true
      self.deferOutReason = reason or "deferred_buff_fadeout"
      return
    end

    local dontForce = DO_NOT_FORCE_SHOW[name]
    if targetAlpha == 1 and dontForce and not self.frame:IsShown() then
      ns.dprint("["..name.."] skip force-show (conditional)")
      self.Fade.active = false
      self.Fade.target = nil
      return
    end

    if targetAlpha == 1 and self.frame:IsShown() then
      self.resume = true
    end

    -- default duration
    self.Fade.duration = ClampDuration(VeilHUDDB and VeilHUDDB.fadeTime or 3.0)

    -- priority fade-ins are shorter
    if targetAlpha == 1 and reason and (
      string.find(reason, "priority:combat", 1, true) or
      string.find(reason, "priority:target", 1, true) or
      string.find(reason, "priority:mouseover", 1, true)
    ) then
      self.Fade.duration = ClampDuration(0.8)
    end

    -- If BUFF-like is fading out and a fade-in arrives, defer the fade-in
    if IsBuffLike(name) and self.Fade.active and self.Fade.target == 0 and targetAlpha == 1 then
      self.deferFadeIn = true
      self.deferReason = reason or "deferred_buff_fadein"
      return
    end

    if self.Fade.active and self.Fade.target == targetAlpha then
      ns.dprint("["..(name).."] Fade -> "..targetAlpha.." (skip) ["..(reason or "").."]")
      return
    end

    ns.dprint("["..(name).."] StartFade -> "..targetAlpha.." ["..(reason or "").."]")
    self.Fade.active  = true
    self.Fade.target  = targetAlpha
    self.Fade.elapsed = 0
    self.Fade.start   = GetAlphaSafe()

    if targetAlpha > self.Fade.start then
      if self.frame.Show then self.frame:Show() end
      if self.frame.SetAlpha then self.frame:SetAlpha(self.Fade.start) end
    end

    self.fadeCtrl:Show()
  end

  c.fadeCtrl:SetScript("OnUpdate", function()
    if not (c.Fade.active and c.Fade.target and c.frame) then return end
    local dt = arg1 or 0
    c.Fade.elapsed = c.Fade.elapsed + dt
    local t = c.Fade.elapsed / (c.Fade.duration > 0 and c.Fade.duration or 0.05)

    local name = c.frame:GetName() or ""
    if t >= 1 then
      if c.frame.SetAlpha then c.frame:SetAlpha(c.Fade.target) end

      -- If we just completed a fade-in and a fade-out was deferred, run it now
      if c.Fade.target == 1 and c.deferFadeOut then
        local _r = c.deferOutReason or "deferred_buff_fadeout"
        c.deferFadeOut, c.deferOutReason = false, nil
        c.Fade.active, c.Fade.target = false, nil
        c.Fade.elapsed, c.Fade.start = 0, 1
        c:StartFade(0, _r)
        return
      end

      if c.Fade.target == 0 then
        -- end of fade-out
        if name=="BuffFrame" or name=="TemporaryEnchantFrame" then
          if c.frame.Hide then c.frame:Hide() end
          -- if a fade-in was deferred, trigger it now cleanly
          if c.deferFadeIn then
            c.deferFadeIn = false
            local reason = c.deferReason or "deferred_buff_fadein"
            c.deferReason = nil
            -- prepare: show at 0 and then fade-in
            if c.frame.Show then c.frame:Show() end
            if c.frame.SetAlpha then c.frame:SetAlpha(0) end
            c.Fade.active  = false
            c.Fade.target  = nil
            c.Fade.elapsed = 0
            c.Fade.start   = 0
            c:StartFade(1, reason)
            return
          end
        elseif not FADE_ONLY[name] and c.frame.Hide then
          c.frame:Hide()
        end
      end

      c.Fade.active, c.Fade.target = false, nil
      c.fadeCtrl:Hide()
      return
    end

    local newAlpha = c.Fade.start + (c.Fade.target - c.Fade.start) * t
    if c.frame.SetAlpha then c.frame:SetAlpha(newAlpha) end
  end)

  return c
end
ns.Controller.NewController = NewController

-- Rebuilds the Controllers table from FRAME_NAMES.
local function ResolveControllers()
  ns.Controllers = {}
  for _,name in ipairs(FRAME_NAMES) do
    local fr = ns.G(name)
    if fr and fr.SetAlpha and fr.Show and fr.Hide then
      ns.Controllers[fr] = NewController(fr)
      ns.dprint("OK: "..name)
    else
      ns.dprint("Skip: "..name.." (missing/not API-compatible)")
    end
  end
  local count=0; for _ in pairs(ns.Controllers) do count=count+1 end
  ns.dprint("Controllers created: "..count)
end
ns.Controller.ResolveControllers = ResolveControllers
ns.ResolveControllers = ResolveControllers
