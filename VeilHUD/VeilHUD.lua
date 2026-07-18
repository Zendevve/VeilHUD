-- VeilHUD — smart UI auto-hide for WotLK 3.3.5a (Interface 30300)
-- Fades out action bars, the micro menu, bags, and unit frames during normal
-- play, and brings them back when they matter: combat, a living target,
-- mousing over the bars, low health, being grouped, or resting.

local ADDON_NAME, ns = ...

-- Main initialization entry point.
-- Modules are loaded in sequence via VeilHUD.toc:
--   1. Modules\Utils.lua
--   2. Modules\Config.lua
--   3. Modules\Controller.lua
--   4. Modules\Guards.lua
--   5. Modules\Core.lua
--   6. VeilHUD.lua

ns.dprint("VeilHUD initialization complete.")
