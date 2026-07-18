local ADDON_NAME, ns = ...

ns.Core = ns.Core or {}

local f = CreateFrame("Frame")
ns.frame = f
ns.Core.frame = f

-- State flags
f.inCombat                = false
f.postCombatGraceUntil    = 0   -- post-combat grace window (GetTime)
f.postTargetGraceUntil    = 0   -- post-target-loss grace window (GetTime)
f.lastTargetAlive         = nil -- last known target alive state
f.mouseOverBars           = false
f.postMouseoverGraceUntil = 0   -- post-mouseover grace window (GetTime)

-- ===================== Action bar visual fix helpers =====================
local function RestoreMainActionButtons()
  for i = 1, 12 do
    local btn = ns.G("ActionButton"..i)
    if btn then
      if btn.Show then btn:Show() end
      if btn.SetAlpha then btn:SetAlpha(1) end
    end
  end

  for i = 1, 12 do
    local btn = ns.G("BonusActionButton"..i)
    if btn then
      if btn.Show then btn:Show() end
      if btn.SetAlpha then btn:SetAlpha(1) end
    end
  end

  local mm = ns.G("MainMenuBar")
  if mm then
    if mm.Show then mm:Show() end
    if mm.SetAlpha then mm:SetAlpha(1) end
  end
end
ns.Core.RestoreMainActionButtons = RestoreMainActionButtons
ns.RestoreMainActionButtons = RestoreMainActionButtons

local function HideBlizzardButtonNormals()
  local function HideButtonNormal(btn)
    if not btn then return end

    local nt = btn.GetNormalTexture and btn:GetNormalTexture() or nil
    if nt then
      if nt.Hide then nt:Hide() end
      if nt.SetAlpha then nt:SetAlpha(0) end
    end

    local name = btn.GetName and btn:GetName() or nil
    if name then
      local normal = ns.G(name .. "NormalTexture")
      if normal then
        if normal.Hide then normal:Hide() end
        if normal.SetAlpha then normal:SetAlpha(0) end
      end

      local floatingBG = ns.G(name .. "FloatingBG")
      if floatingBG then
        if floatingBG.Hide then floatingBG:Hide() end
        if floatingBG.SetAlpha then floatingBG:SetAlpha(0) end
      end
    end
  end

  for i = 1, 12 do
    HideButtonNormal(ns.G("ActionButton"..i))
    HideButtonNormal(ns.G("BonusActionButton"..i))
  end
end
ns.Core.HideBlizzardButtonNormals = HideBlizzardButtonNormals
ns.HideBlizzardButtonNormals = HideBlizzardButtonNormals

local function NeedsActionBarFix()
  for i = 1, 12 do
    local btn = ns.G("ActionButton"..i)
    if btn then
      local nt = btn.GetNormalTexture and btn:GetNormalTexture() or nil
      if nt and nt.IsShown and nt:IsShown() then
        return true
      end
    end

    local bbtn = ns.G("BonusActionButton"..i)
    if bbtn then
      local nt = bbtn.GetNormalTexture and bbtn:GetNormalTexture() or nil
      if nt and nt.IsShown and nt:IsShown() then
        return true
      end
    end
  end
  return false
end
ns.Core.NeedsActionBarFix = NeedsActionBarFix
ns.NeedsActionBarFix = NeedsActionBarFix

-- ===================== Debounced ENTER logic =====================
local ZONE_DEBOUNCE = 0.6
local lastZoneEvent, pendingRestingCheck = 0, false

local scheduler = CreateFrame("Frame"); scheduler:Hide()
scheduler.timeLeft = 0
scheduler:SetScript("OnUpdate", function()
  scheduler.timeLeft = scheduler.timeLeft - (arg1 or 0)
  if scheduler.timeLeft <= 0 then
    scheduler:Hide()
    if pendingRestingCheck then
      pendingRestingCheck = false
      f:Evaluate("zone_debounced")
    end
  end
end)

local function DebouncedShowForResting()
  local now = GetTime and GetTime() or 0
  if now - lastZoneEvent < ZONE_DEBOUNCE then
    pendingRestingCheck = true
    scheduler.timeLeft  = ZONE_DEBOUNCE - (now - lastZoneEvent)
    if scheduler.timeLeft < 0.05 then scheduler.timeLeft = 0.05 end
    scheduler:Show()
    ns.dprint("Waiting zone debounce: "..string.format("%.2f", scheduler.timeLeft).."s")
    return
  end
  if ns.IsZoneTextActive() then
    ns.Guards.zoneShowGuard.wantShow = true
    ns.Guards.zoneShowGuard.waited   = 0
    ns.Guards.zoneShowGuard:Show()
    ns.Guards.restoreFailsafe.t = 0; ns.Guards.restoreFailsafe:Show()
  else
    ns.Guards.restoreFailsafe:Hide()
    for _,c in pairs(ns.Controllers) do
      local fr  = c.frame
      local n   = fr and (fr:GetName() or "") or ""
      local unit = fr and fr.unit or nil
      if unit and UnitExists and UnitExists(unit) then
        c.resume = true
        if fr and fr.Show then fr:Show() end
      end
      if c.resume ~= false then c:StartFade(1, "resting") end
    end
  end
end
ns.Core.DebouncedShowForResting = DebouncedShowForResting

-- ===================== Action bars mouseover watch =====================
local function IsActionBarish(name)
  if not name then return false end
  if string.find(name, "ActionButton",      1, true) then return true end
  if string.find(name, "BonusActionButton", 1, true) then return true end
  if string.find(name, "MultiBar",          1, true) then return true end
  if string.find(name, "PetActionButton",   1, true) then return true end
  if string.find(name, "ShapeshiftButton",  1, true) then return true end
  if name=="MainMenuBar" or name=="PetActionBarFrame" or name=="ShapeshiftBarFrame" then return true end
  return false
end

local hoverWatch = CreateFrame("Frame"); hoverWatch:Show()
hoverWatch.acc, hoverWatch.tick = 0, 0.05
hoverWatch:SetScript("OnUpdate", function()
  local dt = arg1 or 0
  hoverWatch.acc = hoverWatch.acc + dt
  if hoverWatch.acc < hoverWatch.tick then return end
  hoverWatch.acc = 0

  local mf   = GetMouseFocus and GetMouseFocus() or nil
  local name = mf and mf.GetName and mf:GetName() or nil
  local onBars = IsActionBarish(name)

  if onBars ~= f.mouseOverBars then
    f.mouseOverBars = onBars
    if onBars then
      f.postMouseoverGraceUntil = 0
      f:Evaluate("mouseover_bars_enter")
    else
      local now = GetTime and GetTime() or 0
      local mouseGrace = (ns.Config and ns.Config.MOUSEOVER_GRACE) or 12.0
      f.postMouseoverGraceUntil = now + mouseGrace
      if ns.C_TimerAfter then
        ns.C_TimerAfter(mouseGrace, function()
          if not f.mouseOverBars and not f.inCombat then
            f.postMouseoverGraceUntil = 0
            f:Evaluate("mouseover_bars_end_delayed")
          end
        end)
      end
      f:Evaluate("mouseover_bars_leave_grace")
    end
  end
end)
ns.Core.hoverWatch = hoverWatch

-- Returns true if the player is at full health (HP == MaxHP).
local function IsPlayerFullHealth()
  if not (UnitHealth and UnitHealthMax) then return true end
  local max = UnitHealthMax("player") or 0
  if max <= 0 then return false end
  local hp  = UnitHealth("player") or 0
  return hp >= max
end
ns.Core.IsPlayerFullHealth = IsPlayerFullHealth

-- Central brain of VeilHUD.
function f:Evaluate(reason)
  if not VeilHUDDB or not VeilHUDDB.enabled then
    ns.dprint("Disabled; no action.")
    return
  end

  local now = GetTime and GetTime() or 0

  -- Grace windows: (post-combat, post-target, post-mouseover)
  if (not f.inCombat) and (
    (f.postCombatGraceUntil    or 0) > now or
    (f.postTargetGraceUntil    or 0) > now or
    (f.postMouseoverGraceUntil or 0) > now
  ) then
    ns.Guards.restoreFailsafe:Hide()
    ns.ShowAll("grace_window")
    return
  end

  -- Do not fade out UI while in a raid
  local inRaid = (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0)
  if inRaid then
    ns.Guards.restoreFailsafe:Hide()
    ns.ShowAll("priority:raid")
    return
  end

  -- Fade-in: combat, living target, or mouseover on bars
  if f.inCombat or (
    VeilHUDDB.showOnTarget
    and UnitExists and UnitExists("target")
    and not UnitIsDeadOrGhost("target")
  ) or f.mouseOverBars then
    ns.Guards.restoreFailsafe:Hide()
    local why = f.inCombat and "combat" or (f.mouseOverBars and "mouseover" or "target")
    ns.ShowAll("priority:"..why)
    return
  end

  -- Do not fade out UI if player is not at 100% health
  if not IsPlayerFullHealth() then
    ns.Guards.restoreFailsafe:Hide()
    ns.ShowAll("priority:player_not_full_hp")
    return
  end

  -- Remaining logic
  if IsResting() then
    DebouncedShowForResting()
  else
    ns.Guards.restoreFailsafe:Hide()
    ns.HideAll("not_resting")
  end
end

ns.Evaluate = function(reason) return f:Evaluate(reason) end
ns.Core.Evaluate = f.Evaluate

-- ===================== Events =====================
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_UPDATE_RESTING")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
f:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
f:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")

f:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    ns.InitDB()

    -- Create controllers normally
    ns.ResolveControllers()
    ns.C_TimerAfter(0.3, ns.ResolveControllers)

    ns.dprint("Loaded. Applying 5-second startup delay.")

    -- Wait 5 seconds before enabling the addon
    ns.C_TimerAfter(5, function()
      f:Evaluate("entering_world_delayed")
    end)

    return
  end

  if event=="PLAYER_REGEN_DISABLED" then
    f.inCombat = true
    f.postCombatGraceUntil    = 0 -- cancel any previous window
    f.postTargetGraceUntil    = 0 -- combat has priority
    f.postMouseoverGraceUntil = 0
    f:Evaluate("combat_start")
    return
  end

  if event=="PLAYER_REGEN_ENABLED" then
    f.inCombat = false
    local grace = 10.0
    f.postCombatGraceUntil = (GetTime and GetTime() or 0) + grace
    ns.C_TimerAfter(grace, function()
      if not f.inCombat then
        f.postCombatGraceUntil = 0
        f:Evaluate("combat_end_delayed")
      end
    end)
    return
  end

  if event=="PLAYER_TARGET_CHANGED" then
    local hasTarget = UnitExists and UnitExists("target")

    if hasTarget then
      local alive = not UnitIsDeadOrGhost("target")
      f.lastTargetAlive = alive

      if alive then
        f.postTargetGraceUntil = 0
      end

      f:Evaluate("target_changed")
      return
    else
      if f.lastTargetAlive == false then
        ns.dprint("Target cleared (was dead) — no UI change.")
        f.lastTargetAlive = nil
        return
      end

      f.lastTargetAlive = nil
      local now2 = GetTime and GetTime() or 0
      local targetGrace = (ns.Config and ns.Config.TARGET_GRACE) or 5.0
      f.postTargetGraceUntil = now2 + targetGrace
      ns.C_TimerAfter(targetGrace, function()
        if not (UnitExists and UnitExists("target")) and not f.inCombat then
          f.postTargetGraceUntil = 0
          f:Evaluate("target_end_delayed")
        end
      end)
      f:Evaluate("target_lost_grace")
      return
    end
  end

  if event=="PLAYER_UPDATE_RESTING" then
    if IsResting() then
      ns.C_TimerAfter(4.0, function()
        if IsResting and IsResting() then
          DebouncedShowForResting()
          ns.C_TimerAfter(1.0, function() ns.ForceFadeInAll("resting_timer_1s") end)
          ns.C_TimerAfter(3.5, function() ns.ForceFadeInAll("resting_timer_3_5s") end)
        end
      end)
      return
    end
  end

  if event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" or event=="ZONE_CHANGED_NEW_AREA" then
    lastZoneEvent = GetTime and GetTime() or 0
    ns.dprint("Zone event: "..event)
    if IsResting() then
      DebouncedShowForResting()
      return
    end
  end

  if event=="PARTY_MEMBERS_CHANGED" or event=="RAID_ROSTER_UPDATE" then
    f:Evaluate("group_roster_update")
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    if arg1 == "player" then
      f:Evaluate("player_health_changed")
    end
    return
  end

  if event=="UPDATE_BONUS_ACTIONBAR"
  or event=="ACTIONBAR_PAGE_CHANGED"
  or event=="UPDATE_SHAPESHIFT_FORMS"
  or event=="UPDATE_SHAPESHIFT_USABLE" then

    local shouldBeVisible = false
    local now = GetTime and GetTime() or 0

    if f.inCombat
      or f.mouseOverBars
      or ((f.postCombatGraceUntil or 0) > now)
      or ((f.postTargetGraceUntil or 0) > now)
      or ((f.postMouseoverGraceUntil or 0) > now)
      or (VeilHUDDB.showOnTarget and UnitExists and UnitExists("target") and not UnitIsDeadOrGhost("target"))
      or IsResting()
      or not IsPlayerFullHealth()
      or (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) then
      shouldBeVisible = true
    end

    if shouldBeVisible then
      local function FixActionBarVisualState()
        RestoreMainActionButtons()
        HideBlizzardButtonNormals()

        local c = ns.Controllers and ns.Controllers[ns.G("MainMenuBar")]
        if c then
          c.resume = true
          c:StartFade(1, "actionbar_state_fix")
        end
      end

      ns.C_TimerAfter(0.01, function()
        FixActionBarVisualState()

        ns.C_TimerAfter(0.10, function()
          if NeedsActionBarFix() then
            FixActionBarVisualState()
          end
        end)
      end)
    end

    return
  end

  f:Evaluate(string.lower(event or ""))
end)

-- ===================== No Numbers on PlayerFrame =====================
if PlayerHitIndicator then
  PlayerHitIndicator:Hide()
  PlayerHitIndicator.Show = function() end
end
