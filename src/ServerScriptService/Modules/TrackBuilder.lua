-- Builds a placeholder rectangular loop track: four straight brick road
-- segments overlapping at the corners, plus four ordered checkpoints
-- (checkpoint 1 doubles as start/finish). This is deliberately simple
-- geometry so it's correct without needing hand-placed art -- the real
-- Speed Oval / Technical Circuit / Stunt Yard layouts come later.

local TrackBuilder = {}

local ROAD_WIDTH = 16
local ROAD_COLOR = Color3.fromRGB(90, 92, 100)
local DEFAULT_HALF_SPAN_X = 40 -- distance from center to the left/right straights
local DEFAULT_HALF_LENGTH_Z = 60 -- distance from center to the front/back straights

local function addRoadPart(parent, cframe, size)
	local part = Instance.new("Part")
	part.Name = "RoadSegment"
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = ROAD_COLOR
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addCheckpoint(parent, cframe, size, order)
	local checkpoint = Instance.new("Part")
	checkpoint.Name = "Checkpoint" .. order
	checkpoint.Anchored = true
	checkpoint.CanCollide = false
	checkpoint.Transparency = 1
	checkpoint.Size = size
	checkpoint.CFrame = cframe
	checkpoint.Parent = parent

	local orderValue = Instance.new("IntValue")
	orderValue.Name = "Order"
	orderValue.Value = order
	orderValue.Parent = checkpoint

	return checkpoint
end

-- Returns (trackModel, orderedCheckpoints, spawnCFrame).
-- halfSpanX/halfLengthZ let callers vary footprint per track archetype;
-- both default to the original prototype loop's size.
function TrackBuilder.buildLoop(center, halfSpanX, halfLengthZ)
	center = center or Vector3.new(0, 0, 0)
	halfSpanX = halfSpanX or DEFAULT_HALF_SPAN_X
	halfLengthZ = halfLengthZ or DEFAULT_HALF_LENGTH_Z

	local model = Instance.new("Model")
	model.Name = "PrototypeCircuit"

	-- Left / right straights run along Z; front / back straights run along X.
	-- Sized to overlap at the corners so there are no visible gaps.
	addRoadPart(
		model,
		CFrame.new(center + Vector3.new(-halfSpanX, 0.5, 0)),
		Vector3.new(ROAD_WIDTH, 1, halfLengthZ * 2 + ROAD_WIDTH)
	)
	addRoadPart(
		model,
		CFrame.new(center + Vector3.new(halfSpanX, 0.5, 0)),
		Vector3.new(ROAD_WIDTH, 1, halfLengthZ * 2 + ROAD_WIDTH)
	)
	addRoadPart(
		model,
		CFrame.new(center + Vector3.new(0, 0.5, halfLengthZ)),
		Vector3.new(halfSpanX * 2 + ROAD_WIDTH, 1, ROAD_WIDTH)
	)
	addRoadPart(
		model,
		CFrame.new(center + Vector3.new(0, 0.5, -halfLengthZ)),
		Vector3.new(halfSpanX * 2 + ROAD_WIDTH, 1, ROAD_WIDTH)
	)

	-- Checkpoints in travel order: front -> right -> back -> left -> (wrap to front = lap).
	local checkpoints = {
		addCheckpoint(
			model,
			CFrame.new(center + Vector3.new(0, 4, halfLengthZ)),
			Vector3.new(2, 8, ROAD_WIDTH),
			1
		),
		addCheckpoint(
			model,
			CFrame.new(center + Vector3.new(halfSpanX, 4, 0)),
			Vector3.new(ROAD_WIDTH, 8, 2),
			2
		),
		addCheckpoint(
			model,
			CFrame.new(center + Vector3.new(0, 4, -halfLengthZ)),
			Vector3.new(2, 8, ROAD_WIDTH),
			3
		),
		addCheckpoint(
			model,
			CFrame.new(center + Vector3.new(-halfSpanX, 4, 0)),
			Vector3.new(ROAD_WIDTH, 8, 2),
			4
		),
	}

	-- Spawn on the front straight, left of center, facing toward checkpoint 1.
	local spawnPosition = center + Vector3.new(-halfSpanX + 10, 3, halfLengthZ)
	local spawnCFrame = CFrame.new(spawnPosition, spawnPosition + Vector3.new(1, 0, 0))

	return model, checkpoints, spawnCFrame
end

return TrackBuilder
