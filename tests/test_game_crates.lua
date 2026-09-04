-- Exercises OpenCrate/GetCrateInfo through the real remotes. The shop test
-- already covers the garage-full interaction; this focuses on disclosure,
-- currency validation, and duplicate compensation.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: crates")

local game = harness.boot()
local remotes = game.remotes

local player = mock.newPlayer("Zee", 4)
mock.joinPlayer(player)
mock.spawnCharacter(player)

local profile = game.PlayerProfile.get(player)

-- Disclosure: odds must be present and sum to 100%, pity threshold present.
local info = remotes.GetCrateInfo.OnServerInvoke(player)
T.assertTrue(info.cost ~= nil, "crate cost is disclosed")
T.assertTrue(info.pityEpicThreshold ~= nil, "pity threshold is disclosed")
local totalOdds = 0
for _, entry in ipairs(info.odds) do
	totalOdds = totalOdds + entry.chance
end
T.assertNear(totalOdds, 1.0, 1e-9, "disclosed odds sum to 100%")

-- Can't open with 0 Crystals.
remotes.OpenCrate:_fireServer(player)
local events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertEqual(events[1].type, "crateFailed", "rejected with no Crystals")
T.assertEqual(events[1].reason, "insufficient_crystals", "rejected for the right reason")

-- Pull until Rare hits twice (rare_kei is the only Rare-pool car, so a
-- second Rare pull is guaranteed to be a duplicate) -- proves the
-- duplicate-compensation path pays Cash instead of silently discarding
-- the pull.
profile.Crystals = info.cost * 200
math.randomseed(1234)
local rareHits = 0
local sawDuplicateCash = false
for _ = 1, 200 do
	if rareHits < 2 then
		remotes.OpenCrate:_fireServer(player)
		local crateEvents = harness.drainEventsFor(remotes.LapUpdate, player)
		for _, event in ipairs(crateEvents) do
			T.assertEqual(event.type, "crateResult", "every successful pull fires exactly one crateResult")
			if event.tier == "Rare" then
				rareHits = rareHits + 1
				if rareHits == 2 then
					T.assertEqual(event.reward, "duplicate_cash", "second Rare pull is a duplicate, paid in Cash")
					T.assertEqual(event.amount, 150, "duplicate compensation is 150 Cash")
					sawDuplicateCash = true
				end
			end
		end
	end
end
T.assertTrue(rareHits >= 2, "sample was large enough to hit Rare at least twice")
T.assertTrue(sawDuplicateCash, "duplicate compensation was actually observed")
T.assertTrue(profile.OwnedCars.rare_kei, "rare_kei is owned from the first Rare pull")

-- Every crateResult should also carry updated Cash/Crystals so the client
-- never has to separately re-fetch state after a pull.
remotes.OpenCrate:_fireServer(player)
events = harness.drainEventsFor(remotes.LapUpdate, player)
T.assertTrue(events[1].cash ~= nil, "crateResult includes updated Cash")
T.assertTrue(events[1].crystals ~= nil, "crateResult includes updated Crystals")
T.assertEqual(events[1].crystals, profile.Crystals, "reported Crystals balance matches the profile")

T.report()
