# Changelog

All notable changes to **ZenHUD — Immersion UI** will be documented in this file.

---

## [2.0.0] - 2026-06-22

### 💥 Ground-Up Rewrite (Immersion UI)
- Fully transitioned the addon to a **minimal, intelligent, two-tier visibility model** inspired by Immersion UI.
- All configurations are now saved **per-character** using `SavedVariablesPerCharacter: ZenHUDCharDB`. Account-wide settings and profiles have been removed for simplicity and stability.
- Addon is now **disabled by default** upon first loading to prevent sudden interface shifts, allowing players to activate it cleanly with `/imui on`.

### ✨ Added
- **Floating Directional Compass**: A brand-new draggable widget that replaces the standard minimap. Displays cardinal direction (N/NE/E/etc.) and degree headings (updated at 20 FPS). Highlights North in gold. Dragging position is saved per-character.
- **Resting Visibility State**: When in cities or inns (resting), action bars, buffs, and utility frames automatically lock to 100% opacity for ease of gameplay.
- **Grace Periods**: Transition delays (8s post-combat, 2s post-target, 2s post-mouseover) to prevent rapid fade-in/fade-out during normal exploration.
- **Native DFRL Detection**: Auto-detects **DragonFlight UI: Reforged** frames and automatically controls their visibility and alpha fade values without manual configuration.

### ⚡ Performance & Optimization
- **Zero-Polling Cursor Hotspots**: Utilizes mouseover event states instead of heavy CPU/OnUpdate polling loop.
- **Smooth Animation Controller**: Interpolated alpha fades that support smooth interruption (mid-fade target changes) without visual stutter or blockages.
- **Periodic Alpha Enforcement**: Every 0.5 seconds, the manager checks and corrects frame alphas, catching and resolving standard Blizzard UI buff-frame overrides.

### 🧹 Removed (Obsolete Modules)
- `EventHandler.lua`: Event listeners merged directly into main entry point `ZenHUD.lua`.
- `StateManager.lua`: Redundant state machine simplified into direct evaluation logic in `ZenHUD.lua`.
- `MouseoverDetector.lua`: Hotspot checks merged into event/update routines.
- `Options.lua`: Legacy config interface replaced with a streamlined slash command menu (`/imui`).
- `MinimapButton.lua`: Removed since the standard minimap is hidden in immersion mode.
