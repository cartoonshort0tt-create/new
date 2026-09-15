-- Boots the real GameInit.server.lua and drives a simulated 6-player
-- session against it: dock assignment/release, spawning at the right
-- dock, the 7th player getting no dock, and the round timer actually
-- opening/locking/recalling on schedule.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: pond arena smoke test")

local game = harness.boot()
local PondBuilder = game.PondBuilder

-- ===== Arena exists =====

local pond = mock.workspace:FindFirstChild("Pond")
local island = mock.workspace:FindFirstChild("FrogIsland")
local barrier = mock.workspace:FindFirstChild("IslandLockBarrier")
local docksFolder = mock.workspace:FindFirstChild("Docks")

T.assertTrue(pond ~= nil, "Pond exists in workspace")
T.assertTrue(island ~= nil, "FrogIsland exists in workspace")
T.assertTrue(barrier ~= nil, "IslandLockBarrier exists in workspace")
T.assertTrue(docksFolder ~= nil, "Docks folder exists in workspace")
T.assertTrue(game.remotes.RoundState ~= nil, "RoundState remote was created")

-- The round loop runs synchronously up to its first task.wait when
-- GameInit boots, so the arena should already be OPEN by the time boot()
-- returns -- not sitting locked and waiting for a first tick.
T.assertEqual(barrier.CanCollide, false, "island starts unlocked as soon as the game boots")

-- ===== 6 players join, get distinct docks on the ring =====

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
	local radius = math.sqrt(rootPart.CFrame.X ^ 2 + rootPart.CFrame.Z ^ 2)
	T.assertNear(radius, PondBuilder.DOCK_RING_RADIUS, 0.5, "player " .. i .. " spawned on the dock ring")
	local key = string.format("%.1f,%.1f", rootPart.CFrame.X, rootPart.CFrame.Z)
	T.assertTrue(not seenPositions[key], "player " .. i .. " got a dock nobody else is on")
	seenPositions[key] = true
end

-- ===== A 7th player gets no dock (only 6 exist) =====

local seventhPlayer = mock.newPlayer("Player7", 7)
mock.joinPlayer(seventhPlayer)
mock.spawnCharacter(seventhPlayer)
local seventhRoot = seventhPlayer.Character:FindFirstChild("HumanoidRootPart")
T.assertEqual(seventhRoot.CFrame.X, 0, "the 7th player wasn't moved to a dock (none free)")
T.assertEqual(seventhRoot.CFrame.Z, 0, "the 7th player wasn't moved to a dock (none free)")

-- ===== Leaving frees a dock for the next joiner =====

mock.leavePlayer(players[1])
local eighthPlayer = mock.newPlayer("Player8", 8)
mock.joinPlayer(eighthPlayer)
mock.spawnCharacter(eighthPlayer)
local eighthRoot = eighthPlayer.Character:FindFirstChild("HumanoidRootPart")
local eighthRadius = math.sqrt(eighthRoot.CFrame.X ^ 2 + eighthRoot.CFrame.Z ^ 2)
T.assertNear(eighthRadius, PondBuilder.DOCK_RING_RADIUS, 0.5, "the freed dock went to the next joiner")

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

-- Wander player 2 away from their dock, as if they'd swum out mid-round.
local wanderer = players[2]
local wandererRoot = wanderer.Character:FindFirstChild("HumanoidRootPart")
wandererRoot.CFrame = mock.CFrame.new(0, 3, 0)

mock.advancePending() -- resumes past task.wait(ROUND_ACTIVE_SECONDS): locks + recalls
T.assertEqual(barrier.CanCollide, true, "island locks when the round timer fires")

local wandererRadiusAfterRecall = math.sqrt(wandererRoot.CFrame.X ^ 2 + wandererRoot.CFrame.Z ^ 2)
T.assertNear(wandererRadiusAfterRecall, PondBuilder.DOCK_RING_RADIUS, 0.5, "a wandering player is recalled to their dock when the round locks")

mock.advancePending() -- resumes past task.wait(ROUND_LOCK_SECONDS): unlocks again
T.assertEqual(barrier.CanCollide, false, "island unlocks again after the 10-second reset gap")

T.report()
