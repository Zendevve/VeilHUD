local ADDON_NAME, ns = ...

ns.Guards = ns.Guards or {}

-- Returns true if the frame is shown and has a visible alpha (> 0.1).
local function IsFrameAlphaActive(fr)
  if not fr or not fr.IsShown or not fr:IsShown() then return false end
  if fr.GetAlpha then
    local a = fr:GetAlpha() or 1
    if a <= 0.1 then return false end
  end
  return true
end
ns.Guards.IsFrameAlphaActive = IsFrameAlphaActive

-- Returns true if the ZoneText or SubZoneText frames are visible.
local function IsZoneTextActive()
  local Z, S = ns.G("ZoneTextFrame"), ns.G("SubZoneTextFrame")
  return IsFrameAlphaActive(Z) or IsFrameAlphaActive(S)
end
ns.Guards.IsZoneTextActive = IsZoneTextActive
ns.IsZoneTextActive = IsZoneTextActive

-- EXIT (fade-out): wait for ZoneText to clear, with TIMEOUT (3s)
local zoneHideGuard = CreateFrame("Frame"); zoneHideGuard:Hide()
zoneHideGuard.acc, zoneHideGuard.tick = 0, 0.05
zoneHideGuard.waited, zoneHideGuard.maxWait = 0, 3.0
zoneHideGuard.wantHide = false
zoneHideGuard:SetScript("OnUpdate", function()
  local dt = arg1 or 0
  zoneHideGuard.acc    = zoneHideGuard.acc + dt
  zoneHideGuard.waited = zoneHideGuard.waited + dt
  if zoneHideGuard.acc < zoneHideGuard.tick then return end
  zoneHideGuard.acc = 0
  if (not IsZoneTextActive()) or (zoneHideGuard.waited >= zoneHideGuard.maxWait) then
    zoneHideGuard:Hide()
    if zoneHideGuard.wantHide then
      zoneHideGuard.wantHide = false
      if ns.Config and ns.Config.CloseWindowsIfAllowed then
        ns.Config.CloseWindowsIfAllowed()
      end
      for fr,c in pairs(ns.Controllers) do
        if fr:IsShown() then
          c.resume = true
        end
        c:StartFade(0, (zoneHideGuard.waited >= zoneHideGuard.maxWait) and "hide_timeout" or "hide_after_zone")
      end
    end
  end
end)
ns.Guards.zoneHideGuard = zoneHideGuard

-- ENTER (fade-in): guard + timeout
local zoneShowGuard = CreateFrame("Frame"); zoneShowGuard:Hide()
zoneShowGuard.acc, zoneShowGuard.tick = 0, 0.05
zoneShowGuard.waited, zoneShowGuard.maxWait = 0, 0
zoneShowGuard.wantShow = false
zoneShowGuard:SetScript("OnUpdate", function()
  local dt = arg1 or 0
  zoneShowGuard.acc    = zoneShowGuard.acc + dt
  zoneShowGuard.waited = zoneShowGuard.waited + dt
  if zoneShowGuard.acc < zoneShowGuard.tick then return end
  zoneShowGuard.acc = 0
  if (not IsZoneTextActive()) or (zoneShowGuard.waited >= zoneShowGuard.maxWait) then
    zoneShowGuard:Hide()
    if zoneShowGuard.wantShow then
      zoneShowGuard.wantShow = false
      for _,c in pairs(ns.Controllers) do
        if c.resume ~= false then
          c:StartFade(1, (zoneShowGuard.waited >= zoneShowGuard.maxWait) and "show_timeout" or "show_after_zone")
        end
      end
    end
  end
end)
ns.Guards.zoneShowGuard = zoneShowGuard

-- Forces a fade-in on all controllers that are allowed to resume.
local function ForceFadeInAll(reason)
  local doNotForce = (ns.Controller and ns.Controller.DO_NOT_FORCE_SHOW) or {}
  for fr,c in pairs(ns.Controllers) do
    local name = fr:GetName() or ""
    local dontForce = doNotForce[name]
    if not dontForce and c.resume ~= false then
      c:StartFade(1, reason or "force_fade_in")
    end
  end
end
ns.Guards.ForceFadeInAll = ForceFadeInAll
ns.ForceFadeInAll = ForceFadeInAll

-- Immediately restores all resumable frames to full alpha and shown state.
local function ForceRestoreAllInstant()
  local doNotForce = (ns.Controller and ns.Controller.DO_NOT_FORCE_SHOW) or {}
  for fr,c in pairs(ns.Controllers) do
    if c.resume ~= false then
      local n = fr:GetName() or ""
      local unit = fr.unit
      if unit and UnitExists and UnitExists(unit) then
        c.resume = true
        if fr.SetAlpha then fr:SetAlpha(1) end
        if fr.Show then fr:Show() end
      end
      if not doNotForce[n] then -- do not force-show conditional frames
        if fr.Show then fr:Show() end
        if fr.SetAlpha then fr:SetAlpha(1) end
      end
    end
  end
end
ns.Guards.ForceRestoreAllInstant = ForceRestoreAllInstant
ns.ForceRestoreAllInstant = ForceRestoreAllInstant

-- Failsafe timer frame
local restoreFailsafe = CreateFrame("Frame"); restoreFailsafe:Hide()
restoreFailsafe.t, restoreFailsafe.timeout = 0, 4.0
restoreFailsafe:SetScript("OnUpdate", function()
  restoreFailsafe.t = restoreFailsafe.t + (arg1 or 0)
  if restoreFailsafe.t >= restoreFailsafe.timeout then
    restoreFailsafe:Hide()
    ns.dprint("Failsafe: forcing fade-in (respecting resume/conditionals).")
    ForceFadeInAll("failsafe_timer")
  end
end)
ns.Guards.restoreFailsafe = restoreFailsafe

-- Triggers fade-out on all controlled frames, optionally delayed by ZoneText.
local function HideAll(reason)
  local any = false; for _ in pairs(ns.Controllers) do any = true; break end
  if not any then return end

  if IsZoneTextActive() then
    ns.dprint("ZoneText visible — delaying fade-out (all)")
    zoneHideGuard.wantHide = true
    zoneHideGuard.waited   = 0
    zoneHideGuard:Show()
    return
  end
  if ns.Config and ns.Config.CloseWindowsIfAllowed then
    ns.Config.CloseWindowsIfAllowed()
  end
  for fr,c in pairs(ns.Controllers) do
    if fr:IsShown() then
      c.resume = true
    end
    c:StartFade(0, reason or "hide")
  end
end
ns.Guards.HideAll = HideAll
ns.HideAll = HideAll

-- Triggers fade-in on all frames that have resume ~= false.
local function ShowAll(reason)
  local any = false; for _ in pairs(ns.Controllers) do any = true; break end
  if not any then return end

  if IsZoneTextActive() then
    ns.dprint("ZoneText visible — delaying fade-in (all)")
    zoneShowGuard.wantShow = true
    zoneShowGuard.waited   = 0
    zoneShowGuard:Show()
    restoreFailsafe.t = 0; restoreFailsafe:Show()
    return
  end

  restoreFailsafe:Hide()
  for _,c in pairs(ns.Controllers) do
    local fr = c.frame
    local n  = fr and (fr:GetName() or "") or ""
    local unit = fr and fr.unit or nil
    if unit and UnitExists and UnitExists(unit) then
      c.resume = true
      if fr and fr.Show then fr:Show() end
    end
    if c.resume ~= false then c:StartFade(1, reason or "show") end
  end
end
ns.Guards.ShowAll = ShowAll
ns.ShowAll = ShowAll
