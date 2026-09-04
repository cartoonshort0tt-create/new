-- Exercises PurchaseUpgrade through the real remote, including that the
-- stat bonus is applied live to the currently-spawned car without a
-- respawn (the whole point of applyEffectiveStats being called eagerly).

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: upgrades")

local game = harness.boot()
local remotes = game.remotes

local player = mock.newPlayer("Kip", 3)
mock.joinPlayer(player)
mock.spawnCharacter(player)

local profile = game.PlayerProfile.get(player)

local car
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Kip_Car" then
		car = child
	end
end
T.assertNear(car:GetAttribute("SpeedMultiplier"), 1.0, 1e-9, "starter car begins at 1.0x speed, no upgrades")

-- Can't afford it yet.
remotes.PurchaseUpgrade:_fireServer(player, "Engine")
local events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "upgradeFailed", "upgrade rejected with no Cash")
T.assertEqual(profile.Upgrades.Engine, 0, "level unchanged")

-- Buy level 1 (costs 50). Grant plenty for all 8 levels (total cost 1500).
profile.Cash = 5000
remotes.PurchaseUpgrade:_fireServer(player, "Engine")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "upgradeSuccess", "level 1 purchase succeeds")
T.assertEqual(events[1].newLevel, 1, "reports level 1")
T.assertEqual(5000 - profile.Cash, 50, "level 1 costs 50 Cash")
T.assertEqual(profile.Upgrades.Engine, 1, "profile records level 1")

-- The live car's SpeedMultiplier should reflect the new bonus immediately
-- -- Engine is one of 5 branches, each worth up to 4%; level 1/8 of one
-- branch = (1/8)*0.04 = 0.005 total bonus.
T.assertNear(car:GetAttribute("SpeedMultiplier"), 1.005, 1e-9, "car's SpeedMultiplier updates live after purchase, no respawn needed")

-- Max out Engine (levels 2-8) and confirm the cost curve matches
-- UpgradeCatalog exactly, plus confirm level 8 cannot be exceeded.
local expectedCosts = { 50, 100, 100, 200, 200, 400, 400 } -- levels 2..8
for i, expectedCost in ipairs(expectedCosts) do
	local before = profile.Cash
	remotes.PurchaseUpgrade:_fireServer(player, "Engine")
	events = harness.drainEventsFor(remotes.LapUpdate, player)
	T.assertEqual(events[1].type, "upgradeSuccess", "level " .. (i + 1) .. " purchase succeeds")
	T.assertEqual(before - profile.Cash, expectedCost, "level " .. (i + 1) .. " costs " .. expectedCost)
end
T.assertEqual(profile.Upgrades.Engine, 8, "Engine is now maxed at level 8")

remotes.PurchaseUpgrade:_fireServer(player, "Engine")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(#events, 0, "purchasing past max level fires no event (silently rejected, no charge)")

-- Engine alone maxed = 4% of the 20% ceiling.
T.assertNear(car:GetAttribute("SpeedMultiplier"), 1.04, 1e-9, "one maxed branch gives exactly +4%")

-- Invalid branch name is rejected outright (no crash, no charge).
local cashBefore = profile.Cash
remotes.PurchaseUpgrade:_fireServer(player, "Turbo")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(#events, 0, "a made-up branch name fires no event")
T.assertEqual(profile.Cash, cashBefore, "no Cash spent on an invalid branch")

T.report()
