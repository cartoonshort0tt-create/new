-- Smallest possible end-to-end check: boot the real GameInit.server.lua,
-- join one player, drive one practice lap, confirm Cash increases by
-- exactly the practice rate. If this fails, nothing else downstream will
-- make sense, so it's kept separate from the larger scenario test.

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

-- Find the practice track assigned to plot 1 (first player to join gets
-- plot 1) and drive one lap on it.
local plotTrack
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Plot1Practice" then
		plotTrack = child
	end
end
T.assertTrue(plotTrack ~= nil, "Plot1Practice track exists in workspace")

local checkpointsByOrder = {}
for _, child in ipairs(plotTrack:GetChildren()) do
	local orderValue = child:FindFirstChild("Order")
	if orderValue then
		checkpointsByOrder[orderValue.Value] = child
	end
end
T.assertEqual(#checkpointsByOrder, 4, "found all 4 of plot 1's checkpoints")

harness.driveOneLap(checkpointsByOrder, car)

local afterLapState = remotes.GetInitialState.OnServerInvoke(player)
T.assertEqual(afterLapState.cash, 25, "one practice lap earns 25 Cash")
T.assertEqual(afterLapState.laps, 1, "lap counter incremented")

T.report()
