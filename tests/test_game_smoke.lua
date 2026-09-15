-- Boots the real GameInit.server.lua and drives a simulated 6-player
-- session against it: player-area assignment/release, spawning at the
-- right house, the 7th player getting no area, and the round timer
-- actually opening/locking/recalling on schedule.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: pond arena smoke test")

local game = harness.boot()
local PondBuilder = game.PondBuilder
local CONFIG = PondBuilder.CONFIG

-- ===== Arena exists =====

local world = mock.workspace:FindFirstChild(CONFIG.WorldFolderName)
T.assertTrue(world ~= nil, "the world folder exists in workspace")

local playerAreasFolder = world and world:FindFirstChild("SixPlayerAreas")
T.assertTrue(playerAreasFolder ~= nil, "SixPlayerAreas folder exists")

local barrier = world and world:FindFirstChild("FrogIsland"):FindFirstChild("IslandLockBarrier")
T.assertTrue(barrier ~= nil, "IslandLockBarrier exists under the island")
T.assertTrue(game.remotes.RoundState ~= nil, "RoundState remote was created")

-- The round loop runs synchronously up to its first task.wait when
-- GameInit boots, so the arena should already be OPEN by the time boot()
-- returns -- not sitting locked and waiting for a first tick.
T.assertEqual(barrier.CanCollide, false, "island starts unlocked as soon as the game boots")

-- Gather each PlayerArea_N's actual spawn marker CFrame from the built
-- world, so tests compare against what GameInit really built instead of
-- re-deriving the geometry formula independently.
local expectedSpawnByIndex = {}
for i = 1, CONFIG.HouseCount do
	local area = playerAreasFolder:FindFirstChild("PlayerArea_" .. i)
	local marker = area and area:FindFirstChild("PlayerSpawn_" .. i)
	T.assertTrue(marker ~= nil, "PlayerArea_" .. i .. " has its spawn marker")
	expectedSpawnByIndex[i] = marker
end

-- ===== 6 players join, get distinct areas =====

local players = {}
for i = 1, 6 do
	local player = mock.newPlayer("Player" .. i, i)
	mock.joinPlayer(player)
	mock.spawnCharacter(player)
	table.insert(players, player)
end

local seenPositions = {}
for i, player in ipairs(players) do
	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	local key = string.format("%.1f,%.1f", rootPart.CFrame.X, rootPart.CFrame.Z)
	T.assertTrue(not seenPositions[key], "player " .. i .. " got a house nobody else is on")
	seenPositions[key] = true

	-- Confirm it actually matches SOME area's spawn marker (which one
	-- depends on assignment order, which this test doesn't need to
	-- predict -- just that it's a real spawn marker, not left at the
	-- default origin).
	local matchedAny = false
	for _, marker in pairs(expectedSpawnByIndex) do
		if math.abs(rootPart.CFrame.X - marker.CFrame.X) < 0.01 and math.abs(rootPart.CFrame.Z - marker.CFrame.Z) < 0.01 then
			matchedAny = true
		end
	end
	T.assertTrue(matchedAny, "player " .. i .. " was moved to one of the 6 real spawn markers")
end

-- ===== A 7th player gets no area (only 6 exist) =====

local seventhPlayer = mock.newPlayer("Player7", 7)
mock.joinPlayer(seventhPlayer)
mock.spawnCharacter(seventhPlayer)
local seventhRoot = seventhPlayer.Character:FindFirstChild("HumanoidRootPart")
T.assertEqual(seventhRoot.CFrame.X, 0, "the 7th player wasn't moved to a house (none free)")
T.assertEqual(seventhRoot.CFrame.Z, 0, "the 7th player wasn't moved to a house (none free)")

-- ===== Leaving frees an area for the next joiner =====

mock.leavePlayer(players[1])
local eighthPlayer = mock.newPlayer("Player8", 8)
mock.joinPlayer(eighthPlayer)
mock.spawnCharacter(eighthPlayer)
local eighthRoot = eighthPlayer.Character:FindFirstChild("HumanoidRootPart")
local eighthMatchedAny = false
for _, marker in pairs(expectedSpawnByIndex) do
	if math.abs(eighthRoot.CFrame.X - marker.CFrame.X) < 0.01 and math.abs(eighthRoot.CFrame.Z - marker.CFrame.Z) < 0.01 then
		eighthMatchedAny = true
	end
end
T.assertTrue(eighthMatchedAny, "the freed area went to the next joiner")

-- ===== Round timer: open -> locked (with recall) -> open =====

-- The round loop shares the same "resume everything past one wait"
-- mechanism as every mock.joinPlayer/spawnCharacter/leavePlayer call
-- above, so all that player setup may have silently advanced it through
-- several open/locked cycles already. Normalize to a known "open"
-- baseline by reading its actual current state instead of trying to
-- predict how many implicit advances happened.
if barrier.CanCollide then
	mock.advancePending()
end
T.assertEqual(barrier.CanCollide, false, "(setup) island normalized to open before the round-timer checks")

-- Wander player 2 away from their house, as if they'd swum out mid-round.
local wanderer = players[2]
local wandererRoot = wanderer.Character:FindFirstChild("HumanoidRootPart")
wandererRoot.CFrame = mock.CFrame.new(0, 3, 0)

mock.advancePending() -- resumes past task.wait(ActiveRoundSeconds): locks + recalls
T.assertEqual(barrier.CanCollide, true, "island locks when the round timer fires")

local wandererMatchedAny = false
for _, marker in pairs(expectedSpawnByIndex) do
	if math.abs(wandererRoot.CFrame.X - marker.CFrame.X) < 0.01 and math.abs(wandererRoot.CFrame.Z - marker.CFrame.Z) < 0.01 then
		wandererMatchedAny = true
	end
end
T.assertTrue(wandererMatchedAny, "a wandering player is recalled to their house when the round locks")

mock.advancePending() -- resumes past task.wait(ResetSeconds): unlocks again
T.assertEqual(barrier.CanCollide, false, "island unlocks again after the reset gap")

T.report()
