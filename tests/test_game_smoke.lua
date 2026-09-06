-- Smallest possible end-to-end check: boot the real GameInit.server.lua,
-- join one player, confirm they land in the showroom with a car, use the
-- outbound teleport pad to reach a competitive track, drive one lap,
-- confirm Cash increases by exactly that track's freeform rate. If this
-- fails, nothing else downstream will make sense, so it's kept separate
-- from the larger scenario tests.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game smoke test")

local game = harness.boot()
local remotes = game.remotes

for name, remote in pairs(remotes) do
	T.assertTrue(remote ~= nil, "remote '" .. name .. "' was created")
end

local player = mock.newPlayer("Rex", 1)
mock.joinPlayer(player)
local character = mock.spawnCharacter(player)

local initialState = remotes.GetInitialState.OnServerInvoke(player)
T.assertEqual(initialState.cash, 0, "new player starts with 0 Cash")
T.assertEqual(initialState.garageSlots, 4, "new player starts with 4 garage slots")

-- Find this player's car: GameInit names it "<PlayerName>_Car" and parents
-- it directly to workspace.
local car
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Rex_Car" then
		car = child
	end
end
T.assertTrue(car ~= nil, "player's car was spawned into workspace")

-- The showroom should exist and hold 3 outbound teleport pads.
local showroom
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Showroom" then
		showroom = child
	end
end
T.assertTrue(showroom ~= nil, "Showroom exists in workspace")

local speedOvalPad
for _, child in ipairs(showroom:GetChildren()) do
	if child.Name == "TeleportPad" and child:GetAttribute("TeleportTo") == "speed_oval" then
		speedOvalPad = child
	end
end
T.assertTrue(speedOvalPad ~= nil, "Showroom has an outbound pad to Speed Oval")

-- Drive onto the pad (touch it with the car) to travel to the track.
local hitPart = car:FindFirstChild("Chassis")
speedOvalPad.Touched:Fire(hitPart)

local speedOval
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "SpeedOval" then
		speedOval = child
	end
end
T.assertTrue(speedOval ~= nil, "SpeedOval track exists in workspace")

local checkpointsByOrder = {}
for _, child in ipairs(speedOval:GetChildren()) do
	local orderValue = child:FindFirstChild("Order")
	if orderValue then
		checkpointsByOrder[orderValue.Value] = child
	end
end
T.assertEqual(#checkpointsByOrder, 4, "found all 4 of Speed Oval's checkpoints")

harness.driveOneLap(checkpointsByOrder, car)

local afterLapState = remotes.GetInitialState.OnServerInvoke(player)
T.assertEqual(afterLapState.cash, 60, "one freeform lap on Speed Oval earns its 60 Cash rate")
T.assertEqual(afterLapState.laps, 1, "lap counter incremented")

-- The return-to-showroom button should send the car straight back.
remotes.ReturnToShowroom:_fireServer(player)
T.assertNear(car.PrimaryPart.CFrame.X, 14, 1, "car returns to the showroom's car spawn point")

T.report()
