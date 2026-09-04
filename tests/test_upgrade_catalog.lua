-- Real unit tests for UpgradeCatalog.lua. This module has zero Roblox API
-- surface, so it runs under plain Lua unmodified -- these assertions are
-- checking actual behavior, not just syntax.

require("tests.luau_compat")
local T = require("tests.helpers")
T.suite("UpgradeCatalog")

local UpgradeCatalog = require("src.ServerScriptService.Modules.UpgradeCatalog")

T.assertEqual(#UpgradeCatalog.BRANCHES, 5, "five branches")
T.assertEqual(UpgradeCatalog.MAX_LEVEL, 8, "max level is 8")

-- Cost curve: doubles every 2 levels, starting at 50.
T.assertEqual(UpgradeCatalog.costForNextLevel(0), 50, "level 0->1 costs 50")
T.assertEqual(UpgradeCatalog.costForNextLevel(1), 50, "level 1->2 costs 50 (same tier)")
T.assertEqual(UpgradeCatalog.costForNextLevel(2), 100, "level 2->3 costs 100")
T.assertEqual(UpgradeCatalog.costForNextLevel(3), 100, "level 3->4 costs 100")
T.assertEqual(UpgradeCatalog.costForNextLevel(4), 200, "level 4->5 costs 200")
T.assertEqual(UpgradeCatalog.costForNextLevel(6), 400, "level 6->7 costs 400")
T.assertNil(UpgradeCatalog.costForNextLevel(8), "no cost past max level")
T.assertNil(UpgradeCatalog.costForNextLevel(9), "no cost above max level either")

-- Bonus curve: each branch caps at 4% (0.04) at level 8.
T.assertEqual(UpgradeCatalog.bonusForLevel(0), 0, "level 0 gives no bonus")
T.assertNear(UpgradeCatalog.bonusForLevel(8), 0.04, 1e-9, "level 8 gives 4% bonus")
T.assertNear(UpgradeCatalog.bonusForLevel(4), 0.02, 1e-9, "level 4 gives half of max bonus")

-- Total bonus: five branches all maxed should hit the blueprint's +20% ceiling exactly.
local maxedUpgrades = { Engine = 8, Tires = 8, Nitro = 8, Handling = 8, Chassis = 8 }
T.assertNear(UpgradeCatalog.totalBonus(maxedUpgrades), 0.20, 1e-9, "all branches maxed = +20%")

local emptyUpgrades = {}
T.assertEqual(UpgradeCatalog.totalBonus(emptyUpgrades), 0, "no upgrades = 0 bonus")
T.assertEqual(UpgradeCatalog.totalBonus(nil), 0, "nil upgrades table doesn't error, gives 0 bonus")

local partialUpgrades = { Engine = 4 }
T.assertNear(UpgradeCatalog.totalBonus(partialUpgrades), 0.02, 1e-9, "one branch half-leveled, others absent")

-- Branch validation, used by GameInit to reject bogus RemoteEvent payloads.
T.assertTrue(UpgradeCatalog.isValidBranch("Engine"), "Engine is a real branch")
T.assertTrue(UpgradeCatalog.isValidBranch("Chassis"), "Chassis is a real branch")
T.assertEqual(UpgradeCatalog.isValidBranch("Turbo"), false, "Turbo is not a real branch")
T.assertEqual(UpgradeCatalog.isValidBranch(""), false, "empty string is not a real branch")

T.report()
