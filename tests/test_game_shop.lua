-- Exercises the car shop and garage slot cap through the real remotes,
-- against the real GameInit.server.lua logic.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: shop & garage slots")

local game = harness.boot()
local remotes = game.remotes

local player = mock.newPlayer("Nova", 2)
mock.joinPlayer(player)
mock.spawnCharacter(player)

local profile = game.PlayerProfile.get(player)

-- Can't afford anything yet.
remotes.PurchaseCar:_fireServer(player, "muscle_v8")
local events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(#events, 1, "one event fired for a rejected purchase")
T.assertEqual(events[1].type, "purchaseFailed", "purchase rejected")
T.assertEqual(events[1].reason, "insufficient_cash", "rejected for insufficient Cash")
T.assertEqual(profile.OwnedCars.muscle_v8, nil, "car was not granted")

-- Grant Cash directly (this is setup for the shop test, not a re-test of
-- how Cash is earned -- that's covered by the smoke test) and buy it.
profile.Cash = 1000
remotes.PurchaseCar:_fireServer(player, "muscle_v8")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "purchaseSuccess", "purchase succeeds with enough Cash")
T.assertEqual(profile.Cash, 700, "700 Cash left after a 300 Cash car")
T.assertTrue(profile.OwnedCars.muscle_v8, "muscle_v8 is now owned")

-- Buying the same car again is a no-op (not a refund exploit, not a
-- double-charge).
remotes.PurchaseCar:_fireServer(player, "muscle_v8")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(#events, 0, "re-buying an owned car fires no event at all")
T.assertEqual(profile.Cash, 700, "Cash unchanged by the no-op re-buy")

-- Select it: the car should respawn with muscle_v8's stats.
remotes.SelectCar:_fireServer(player, "muscle_v8")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "carSelected", "carSelected event fires")

local car
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Nova_Car" then
		car = child
	end
end
T.assertTrue(car ~= nil, "respawned car found in workspace")
T.assertNear(car:GetAttribute("SpeedMultiplier"), 1.15, 1e-9, "respawned car has muscle_v8's SpeedMultiplier")

-- Garage slot cap: buy the third shop car too (3 owned, cap 4 -- room for
-- exactly one more).
remotes.PurchaseCar:_fireServer(player, "rally_gt")
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "purchaseSuccess", "third shop car purchase succeeds (3/4 slots used)")

-- Construct an exactly-full garage deterministically (owns 4 distinct
-- cars, cap is 4) rather than relying on crate RNG to happen to land a
-- 4th car -- precise setup for this specific edge case.
profile.OwnedCars.rare_kei = true
T.assertEqual(profile.GarageSlots, 4, "still 4 slots")

-- A 5th distinct car should now be blocked, even with enough Cash.
profile.Cash = 5000
remotes.PurchaseCar:_fireServer(player, "epic_offroad") -- not owned, not purchasable via shop anyway (crate-only)
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(#events, 0, "crate-only car id is silently ignored by PurchaseCar, not a workaround")

-- Confirm the cap actually blocks a real crate-car grant once full: seed
-- deterministically and pull until either a car is (correctly) refused in
-- favor of Cash, or pity/luck hands back a duplicate -- either outcome
-- proves no 5th car is ever granted while the garage is full.
profile.Crystals = 50 * 60 -- enough for 60 pulls, comfortably past hard pity (50)
math.randomseed(99)
local sawCarReward = false
for _ = 1, 60 do
	remotes.OpenCrate:_fireServer(player)
	local crateEvents = harness.drainEventsFor(remotes.LapUpdate, player)
	for _, event in ipairs(crateEvents) do
		if event.type == "crateResult" and event.reward == "car" then
			sawCarReward = true
		end
	end
end
T.assertEqual(sawCarReward, false, "no car is ever granted from crates while the garage is full")
local ownedCount = 0
for _ in pairs(profile.OwnedCars) do
	ownedCount = ownedCount + 1
end
T.assertEqual(ownedCount, 4, "still exactly 4 owned cars after 60 crate pulls at a full garage")

-- Now expand the garage and confirm the cost curve, then confirm a car
-- can actually be granted again.
profile.Cash = 100000
local initialCash = profile.Cash
remotes.PurchaseGarageSlot:_fireServer(player)
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "garageSlotPurchased", "slot purchase succeeds")
T.assertEqual(events[1].garageSlots, 5, "garage slots incremented to 5")
T.assertEqual(initialCash - profile.Cash, 200, "first slot beyond the start costs 200 Cash (base tier)")

profile.Crystals = 50 * 60 -- replenish; the first loop spent all of it
sawCarReward = false
for _ = 1, 60 do
	if not sawCarReward then
		remotes.OpenCrate:_fireServer(player)
		local crateEvents = harness.drainEventsFor(remotes.LapUpdate, player)
		for _, event in ipairs(crateEvents) do
			if event.type == "crateResult" and event.reward == "car" then
				sawCarReward = true
			end
		end
	end
end
T.assertTrue(sawCarReward, "once there's room again, a crate pull can grant a 5th car")

T.report()
