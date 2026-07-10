# VeilHUD

*A minimal, intelligent UI for a more cinematic WotLK.*

VeilHUD is a lightweight addon for WotLK 3.3.5a that fades your action
bars, micro menu, bags, unit frames, and a handful of other UI pieces out
of view during normal exploration, and brings them back the moment they're
actually useful — combat, a living target, mousing over the bars, low
health, or being grouped.

The goal is a cleaner screen while you're running around doing nothing
combat-related, without ever getting in the way once something happens.

---

## Contents

- [Features](#features)
- [How it works](#how-it-works)
- [Installation](#installation)
- [What it controls](#what-it-controls)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [File overview](#file-overview)

---

## Features

- Automatic, state-driven fading — no keybinds or manual toggling needed.
- Grace windows on every trigger so the UI doesn't flicker in and out on
  brief gaps (e.g. a half-second between targets).
- A dedicated anti-flicker path for buffs, so buff icons don't visually
  pop or blink when the rest of the UI fades in and out around them.
- A startup delay so nothing fades out while your UI is still loading in.
- Fully in-game configurable enable/disable and debug logging via
  SavedVariables — no need to edit files just to turn it off.

## How it works

VeilHUD keeps the UI **visible** whenever any of the following is true,
and fades it out only when *none* of them are:

| Condition | Notes |
|---|---|
| In combat | `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` |
| Have a living target | Only if `VeilHUDDB.showOnTarget` is `true` (default) |
| Mouse is over the action bars | Polled continuously, not event-driven |
| Not at full health | Compares `UnitHealth("player")` to `UnitHealthMax("player")` |
| In a raid group | `GetNumRaidMembers() > 0` |
| Resting (inn/city) | `IsResting()` |
| Still within a grace window | See table below |

**Grace windows** — once a trigger condition ends, the UI stays visible a
little longer before fading, so nothing flickers on brief gaps:

| Trigger ends | Grace period |
|---|---|
| Lose a living target | 5 seconds (`TARGET_GRACE`) |
| Mouse leaves the action bars | 12 seconds (`MOUSEOVER_GRACE`) |
| Combat ends | 10 seconds (`grace` in the `PLAYER_REGEN_ENABLED` handler) |

Two more timing details worth knowing:

- **Startup delay** — VeilHUD waits 5 seconds after `PLAYER_ENTERING_WORLD`
  before it starts fading anything, so you're never staring at a half-loaded
  UI mid-fade.
- **Zone debounce** — zone-change events are debounced by 0.6 seconds
  (`ZONE_DEBOUNCE`) before VeilHUD re-checks your resting state, so rapid
  zone-boundary crossing doesn't cause repeated re-evaluation.

## Installation

1. Unzip the package.
2. Drop the **VeilHUD** folder into `Interface/AddOns/`, so you end up with
   `Interface/AddOns/VeilHUD/VeilHUD.toc`.
3. Relaunch the game (or `/reload`).

No configuration is required — it works immediately with sensible defaults.

## What it controls

| Category | Frames |
|---|---|
| Action bars | `MainMenuBar`, `MultiBarBottomLeft`, `MultiBarBottomRight`, `MultiBarLeft`, `MultiBarRight`, `PetActionBarFrame` |
| Micro menu | Character, Spellbook, Talent, Achievement, Quest Log, Socials, PVP, LFD (Dungeon Finder), World Map, Main Menu, Help |
| Bags | Backpack + all 4 bag slots + key ring |
| Unit frames | `PlayerFrame`, `PetFrame`, `TargetFrameToT` (target-of-target) |
| Chat | The chat menu button and the up/down/bottom scroll buttons |
| Quest tracker | `QuestWatchFrame` |
| Casting/buffs | `PetCastingBarFrame`, `BuffFrame`, `TemporaryEnchantFrame` |

**Deliberately left alone:** your own `CastingBarFrame` is never touched —
your cast bar stays under the game's normal rules regardless of fade state.

Two frames get special handling:

- `TargetFrameToT` and `PetFrame` are never *force-shown* — VeilHUD will
  fade them if they're already visible, but won't summon them onto screen
  on its own (that's still up to the game: you need an actual target-of-
  target or pet).
- `BuffFrame` and `TemporaryEnchantFrame` use a dedicated anti-flicker path:
  instead of a plain alpha fade, they're explicitly hidden once a fade-out
  finishes and shown-at-alpha-0-then-animated on the way back in, so a buff
  icon doesn't visually "pop" into the space where your target frame used
  to be.

## Configuration

Everything is a plain Lua constant near the top of `VeilHUD.lua`, or a
SavedVariables field you can set from in-game chat.

**In `VeilHUD.lua`:**

```lua
local TARGET_GRACE          = 5.0   -- seconds to stay visible after losing a target
local MOUSEOVER_GRACE       = 12.0  -- seconds to stay visible after leaving the bars
local CLOSE_WINDOWS_ON_FADE = false -- if true, calls CloseAllWindows() on fade-out
local ZONE_DEBOUNCE         = 0.6   -- seconds between zone-change re-checks
```

Post-combat grace lives inline inside the `PLAYER_REGEN_ENABLED` handler —
search the file for `grace = 10.0` to find and change it.

**From in-game chat (saved automatically, survives `/reload` and logout):**

```
/run VeilHUDDB.enabled = false        -- turn VeilHUD off entirely
/run VeilHUDDB.debug = true           -- verbose chat log of every fade decision
/run VeilHUDDB.showOnTarget = false   -- targeting something no longer keeps the UI up
/run VeilHUDDB.fadeTime = 1.5         -- faster fade animation (default 3.0 seconds)
```

Disabling VeilHUD with `VeilHUDDB.enabled = false` stops it from making any
further visibility decisions — whatever state your UI happens to be in at
that moment is where it stays. If you disable it mid-fade and want
everything back to normal immediately, `/reload` afterward.

**Adding or removing frames:** edit the `FRAME_NAMES`, `DO_NOT_FORCE_SHOW`,
and `FADE_ONLY` tables directly in `VeilHUD.lua`. Any frame that supports
`:Show()`, `:Hide()`, and `:SetAlpha()` can be added to `FRAME_NAMES`.

## Troubleshooting

**The addon doesn't show up in my AddOns list.**
Make sure the folder is named exactly `VeilHUD` and sits directly inside
`Interface/AddOns/` (not nested in an extra subfolder), and that
`VeilHUD.toc` is directly inside that folder.

**Nothing ever fades.**
Check `VeilHUDDB.enabled` — run `/run print(VeilHUDDB.enabled)` in chat.
Also confirm you're past the 5-second startup delay and not resting, in
combat, targeting something, or hovering the action bars.

**The UI fades but flickers rapidly.**
This usually means a grace window is too short for your play style — try
raising `MOUSEOVER_GRACE` or `TARGET_GRACE`.

**A specific frame never fades.**
It may not be in `FRAME_NAMES`, or it may not support `:SetAlpha()`. Turn
on `VeilHUDDB.debug = true` and check the chat log for that frame's name.

## File overview

| File | Purpose |
|---|---|
| `VeilHUD.toc` | Addon manifest (interface version, saved variables, file list) |
| `VeilHUD.lua` | The entire addon — fade engine, event handling, configuration |
| `README.md` | This document |
