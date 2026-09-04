-- Exercises the same-server matchmaking system end to end: a full 6-player
-- heat starting immediately, a partial heat starting after the grace
-- period, placement-based payout math, and the DNF timeout path.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: matchmaking")

local game = harness.boot()
local remotes = game.remotes

local function findTrackModel(name)
	for _, child in ipairs(mock.workspace:GetChildren()) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function checkpointsFor(trackModel)
	local byOrder = {}
	for _, child in ipairs(trackModel:GetChildren()) do
		local orderValue = child:FindFirstChild("Order")
		if orderValue then
			byOrder[orderValue.Value] = child
		end
	end
	return byOrder
end

local function carFor(player)
	for _, child in ipairs(mock.workspace:GetChildren()) do
		if child.Name == player.Name .. "_Car" then
			return child
		end
	end
	return nil
end

local speedOvalCheckpoints = checkpointsFor(findTrackModel("SpeedOval"))
local technicalCheckpoints = checkpointsFor(findTrackModel("TechnicalCircuit"))

-- ===== Scenario A: a full 6-player heat starts immediately =====

local racersA = {}
for i = 1, 6 do
	local player = mock.newPlayer("RacerA" .. i, 100 + i)
	mock.joinPlayer(player)
	mock.spawnCharacter(player)
	table.insert(racersA, player)
end

for _, player in ipairs(racersA) do
	remotes.QueueForRace:_fireServer(player, "speed_oval")
end
mock.advancePending() -- lets the matchmaking loop's next tick see the full queue and start it

for _, player in ipairs(racersA) do
	local events = harness.drainEventsFor(remotes.LapUpdate, player)
	local sawRaceStart = false
	for _, event in ipairs(events) do
		if event.type == "raceStart" then
			sawRaceStart = true
			T.assertEqual(event.trackId, "speed_oval", "raceStart reports the right track")
			T.assertEqual(event.racerCount, 6, "raceStart reports 6 racers")
		end
	end
	T.assertTrue(sawRaceStart, player.Name .. " gets a raceStart event")
end

-- Finish in a deliberately scrambled order: RacerA3 first, ..., RacerA5 last.
local finishOrderA = { racersA[3], racersA[1], racersA[6], racersA[2], racersA[4], racersA[5] }
-- Speed Oval: RACE_BASE_REWARD(200) * raceMultiplier(4.5) = 900 base.
local expectedRewardsA = { 900, 675, 495, 360, 252, 162 } -- 900 * {1.00,.75,.55,.40,.28,.18}

for rank, player in ipairs(finishOrderA) do
	local car = carFor(player)
	T.assertTrue(car ~= nil, "car found for " .. player.Name)
	local cashBefore = game.PlayerProfile.get(player).Cash
	harness.driveOneLap(speedOvalCheckpoints, car)
	local events = harness.drainEventsFor(remotes.LapUpdate, player)

	local finishEvent
	for _, event in ipairs(events) do
		if event.type == "raceFinish" then
			finishEvent = event
		end
	end
	T.assertTrue(finishEvent ~= nil, player.Name .. " received a raceFinish event")
	T.assertEqual(finishEvent.rank, rank, player.Name .. " finished in the expected rank")
	T.assertEqual(finishEvent.reward, expectedRewardsA[rank], "rank " .. rank .. " pays " .. expectedRewardsA[rank])
	T.assertEqual(
		game.PlayerProfile.get(player).Cash - cashBefore,
		expectedRewardsA[rank],
		player.Name .. "'s Cash increased by exactly the reward"
	)
end

-- After everyone finishes, the session must be closed (no lingering
-- "still racing" state that would block a future queue).
local extraTouchPlayer = racersA[1]
local carAgain = carFor(extraTouchPlayer)
harness.driveOneLap(speedOvalCheckpoints, carAgain) -- a normal freeform lap now, not a race finish
local postRaceEvents = harness.drainEventsFor(remotes.LapUpdate, extraTouchPlayer)
local sawPlainLap = false
for _, event in ipairs(postRaceEvents) do
	if event.type == "lap" and event.cashEarned and event.cashEarned > 0 then
		sawPlainLap = true
	end
end
T.assertTrue(sawPlainLap, "after the race closes, laps on that track go back to normal freeform Cash, not race payouts")

-- ===== Scenario B + C: partial heat via grace timeout, then a DNF =====

local racersB = {}
for i = 1, 3 do
	local player = mock.newPlayer("RacerB" .. i, 200 + i)
	mock.joinPlayer(player)
	mock.spawnCharacter(player)
	table.insert(racersB, player)
end

for _, player in ipairs(racersB) do
	remotes.QueueForRace:_fireServer(player, "technical_circuit")
end
mock.advancePending() -- first tick: queue is 3 (>= min, < max), starts the grace timer, does not start yet

for _, player in ipairs(racersB) do
	local events = harness.drainEventsFor(remotes.LapUpdate, player)
	local sawRaceStart = false
	for _, event in ipairs(events) do
		if event.type == "raceStart" then
			sawRaceStart = true
		end
	end
	T.assertEqual(sawRaceStart, false, player.Name .. " has not started racing yet (grace period not elapsed)")
end

mock.advanceClock(21) -- past the 20s grace period
mock.advancePending() -- next tick: starts the heat with just these 3

for _, player in ipairs(racersB) do
	local events = harness.drainEventsFor(remotes.LapUpdate, player)
	local sawRaceStart = false
	for _, event in ipairs(events) do
		if event.type == "raceStart" then
			sawRaceStart = true
			T.assertEqual(event.trackId, "technical_circuit", "grace-timeout heat is on the right track")
			T.assertEqual(event.racerCount, 3, "grace-timeout heat has exactly the 3 queued racers")
		end
	end
	T.assertTrue(sawRaceStart, player.Name .. " starts racing once the grace period elapses")
end

-- RacerB1 and RacerB2 finish; RacerB3 never does.
harness.driveOneLap(technicalCheckpoints, carFor(racersB[1]))
harness.drainEventsFor(remotes.LapUpdate, racersB[1])
harness.driveOneLap(technicalCheckpoints, carFor(racersB[2]))
harness.drainEventsFor(remotes.LapUpdate, racersB[2])

local cashBeforeDnf = game.PlayerProfile.get(racersB[3]).Cash
mock.fireDelayedTasks() -- simulates every pending race's RACE_TIMEOUT_SECONDS elapsing, incl. Scenario A's (already closed, must no-op)

local dnfEvents = harness.drainEventsFor(remotes.LapUpdate, racersB[3])
local dnfEvent
for _, event in ipairs(dnfEvents) do
	if event.type == "raceFinish" then
		dnfEvent = event
	end
end
T.assertTrue(dnfEvent ~= nil, "RacerB3 gets a raceFinish event from the timeout")
T.assertTrue(dnfEvent.dnf, "it's flagged as a DNF")
-- Technical Circuit: 200 * 4.0 = 800 base; lowest share is 18%.
T.assertEqual(dnfEvent.reward, 144, "DNF pays the lowest placement share (800 * 0.18 = 144)")
T.assertEqual(
	game.PlayerProfile.get(racersB[3]).Cash - cashBeforeDnf,
	144,
	"RacerB3's Cash increased by the DNF consolation, not zero"
)

-- Scenario A's already-finished racers must NOT have been paid again by
-- this same fireDelayedTasks() call (their session was already closed).
local a1CashAfter = game.PlayerProfile.get(racersA[1]).Cash
local a1Events = harness.drainEventsFor(remotes.LapUpdate, racersA[1])
local sawSecondFinish = false
for _, event in ipairs(a1Events) do
	if event.type == "raceFinish" then
		sawSecondFinish = true
	end
end
T.assertEqual(sawSecondFinish, false, "an already-closed race session doesn't pay out again on a later timeout tick")

T.report()
