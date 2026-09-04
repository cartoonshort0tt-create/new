-- Exercises TrackBuilder.buildLoop's actual geometry math against the mock
-- Roblox environment -- catches real math/API mistakes, not just syntax.

local mock = require("tests.mock_roblox")
local T = require("tests.helpers")
T.suite("TrackBuilder")

local moduleInstance = mock.newModuleScript(nil, "TrackBuilder", "src/ServerScriptService/Modules/TrackBuilder.lua")
local TrackBuilder = mock.load(moduleInstance)

-- Default-sized loop (used for the 6 practice plots).
local model, checkpoints, spawnCFrame = TrackBuilder.buildLoop(mock.Vector3.new(0, 0, 0))

T.assertEqual(model.ClassName, "Model", "buildLoop returns a Model")
T.assertEqual(#checkpoints, 4, "default loop has 4 checkpoints")

-- Checkpoints must be numbered 1..4 in order, contiguous, no gaps or
-- duplicates -- GameInit's lap-wrap logic depends entirely on this.
local seenOrders = {}
for i, checkpoint in ipairs(checkpoints) do
	local orderValue = checkpoint:FindFirstChild("Order")
	T.assertTrue(orderValue ~= nil, "checkpoint " .. i .. " has an Order IntValue child")
	if orderValue then
		seenOrders[orderValue.Value] = true
	end
end
for i = 1, 4 do
	T.assertTrue(seenOrders[i] == true, "checkpoint order " .. i .. " is present exactly once")
end

-- Checkpoints must not carry CanCollide, or a fast car would bounce off
-- the finish line instead of crossing it.
for _, checkpoint in ipairs(checkpoints) do
	T.assertEqual(checkpoint.CanCollide, false, "checkpoint is non-solid")
end

-- Road segments (children of the model that aren't checkpoints) should be
-- anchored, or the whole track would fall through the world under gravity.
local roadSegmentCount = 0
for _, child in ipairs(model:GetChildren()) do
	if child.Name == "RoadSegment" then
		roadSegmentCount = roadSegmentCount + 1
		T.assertEqual(child.Anchored, true, "road segment is anchored")
	end
end
T.assertEqual(roadSegmentCount, 4, "4 road segments (2 straights, 2 connectors)")

-- Spawn point should sit on the front straight, roughly at road height,
-- not buried underground or floating far above the track.
T.assertNear(spawnCFrame.Y, 3, 5, "spawn height is near road level")

-- A custom-sized loop (Technical Circuit style: smaller footprint) should
-- actually change checkpoint placement, not silently ignore the args.
local smallModel, smallCheckpoints = TrackBuilder.buildLoop(mock.Vector3.new(0, 0, 0), 30, 40)
local defaultRightCheckpoint, smallRightCheckpoint
for _, cp in ipairs(checkpoints) do
	if cp:FindFirstChild("Order").Value == 2 then
		defaultRightCheckpoint = cp
	end
end
for _, cp in ipairs(smallCheckpoints) do
	if cp:FindFirstChild("Order").Value == 2 then
		smallRightCheckpoint = cp
	end
end
T.assertTrue(smallRightCheckpoint.CFrame.X < defaultRightCheckpoint.CFrame.X, "smaller halfSpanX pulls checkpoint 2 inward")

-- Two loops built at different centers must not collide -- this is the
-- same spacing assumption GameInit relies on for 6 plots + 3 competitive
-- tracks sharing one workspace.
local farModel, farCheckpoints, farSpawn = TrackBuilder.buildLoop(mock.Vector3.new(3000, 0, 0))
T.assertTrue(farSpawn.X > 2900, "a track built far from the origin is actually built there, not at (0,0,0)")

T.report()
