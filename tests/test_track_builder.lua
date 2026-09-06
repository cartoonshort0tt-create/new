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
-- same spacing assumption GameInit relies on for the 3 competitive tracks
-- sharing one workspace.
local farModel, farCheckpoints, farSpawn = TrackBuilder.buildLoop(mock.Vector3.new(3000, 0, 0))
T.assertTrue(farSpawn.X > 2900, "a track built far from the origin is actually built there, not at (0,0,0)")

-- Barrier walls: exactly 8 (2 per straight segment), all solid, so a car
-- can't drive off the track -- the whole point of adding them.
local wallCount = 0
for _, child in ipairs(model:GetChildren()) do
	if child.Name == "Wall" then
		wallCount = wallCount + 1
		T.assertEqual(child.CanCollide, true, "wall is solid")
		T.assertEqual(child.Anchored, true, "wall is anchored")
	end
end
T.assertEqual(wallCount, 8, "8 walls (2 flanking each of the 4 road segments)")

-- The exact bug found in the first Studio playtest: walls sized to each
-- straight's own full length (including its corner overlap zone) seal
-- every corner into a closed box instead of a driveable turn. Lock this
-- in structurally: every wall must sit at one of exactly two distances
-- from center (the outer ring or the inner ring), never some in-between
-- value that would only make sense if a wall were cutting across the
-- corridor near a corner.
local wallHalfSpanX, wallHalfLengthZ = 30, 40 -- matches the smallModel built below
local outerX, innerX = wallHalfSpanX + 8, wallHalfSpanX - 8
local outerZ, innerZ = wallHalfLengthZ + 8, wallHalfLengthZ - 8
local smallModelForWalls = TrackBuilder.buildLoop(mock.Vector3.new(0, 0, 0), wallHalfSpanX, wallHalfLengthZ)
for _, child in ipairs(smallModelForWalls:GetChildren()) do
	if child.Name == "Wall" then
		if child.Size.Z > child.Size.X then
			-- a left/right-style wall: its offset from center is |X|, and
			-- its length (Size.Z) must match a length appropriate to
			-- WHICHEVER ring it's on -- an inner-ring wall sized to the
			-- outer ring's length (or to the single shared length the old
			-- per-straight code used) is exactly the bug that boxed in
			-- every corner.
			local distance = math.abs(child.CFrame.X)
			if math.abs(distance - outerX) < 0.01 then
				T.assertNear(child.Size.Z, outerZ * 2 + 1, 0.01, "outer X-wall length matches the outer ring")
			elseif math.abs(distance - innerX) < 0.01 then
				T.assertNear(child.Size.Z, innerZ * 2 + 1, 0.01, "inner X-wall length matches the inner ring (shorter, not boxing the corner)")
			else
				T.assertTrue(false, "X-wall sits on the outer or inner ring, not a boxing position")
			end
		else
			local distance = math.abs(child.CFrame.Z)
			if math.abs(distance - outerZ) < 0.01 then
				T.assertNear(child.Size.X, outerX * 2 + 1, 0.01, "outer Z-wall length matches the outer ring")
			elseif math.abs(distance - innerZ) < 0.01 then
				T.assertNear(child.Size.X, innerX * 2 + 1, 0.01, "inner Z-wall length matches the inner ring (shorter, not boxing the corner)")
			else
				T.assertTrue(false, "Z-wall sits on the outer or inner ring, not a boxing position")
			end
		end
	end
end

-- Custom theme colors actually get applied, not silently ignored.
local themedModel = TrackBuilder.buildLoop(mock.Vector3.new(500, 0, 0), nil, nil, {
	roadColor = mock.Color3.fromRGB(1, 2, 3),
	wallColor = mock.Color3.fromRGB(4, 5, 6),
	lineColor = mock.Color3.fromRGB(7, 8, 9),
})
for _, child in ipairs(themedModel:GetChildren()) do
	if child.Name == "RoadSegment" then
		T.assertEqual(child.Color.R, 1 / 255, "custom roadColor is applied")
	elseif child.Name == "Wall" then
		T.assertEqual(child.Color.R, 4 / 255, "custom wallColor is applied")
	elseif child.Name == "Centerline" then
		T.assertEqual(child.Color.R, 7 / 255, "custom lineColor is applied")
	end
end

-- Showroom: a floor plus a neutral SpawnLocation (so it spawns players
-- regardless of any leftover Teams setup in the place), and a car spawn
-- point distinct from the humanoid spawn so a car doesn't overlap it.
local showroomModel, carSpawnCFrame = TrackBuilder.buildShowroom(mock.Vector3.new(0, 0, 0))
T.assertEqual(showroomModel.ClassName, "Model", "buildShowroom returns a Model")
local spawnLocation = showroomModel:FindFirstChild("ShowroomSpawn")
T.assertTrue(spawnLocation ~= nil, "showroom has a SpawnLocation")
if spawnLocation then
	T.assertEqual(spawnLocation.ClassName, "SpawnLocation", "ShowroomSpawn is actually a SpawnLocation")
	T.assertEqual(spawnLocation.Neutral, true, "showroom spawn is neutral (not team-restricted)")
end
T.assertTrue(carSpawnCFrame ~= nil, "buildShowroom returns a car spawn CFrame")

T.report()
