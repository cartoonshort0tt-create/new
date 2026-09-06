-- Builds a rectangular loop track: four straight brick road segments
-- overlapping at the corners, flanking barrier walls on both edges so a
-- car can't drive off, a painted centerline for readability, plus four
-- ordered checkpoints (checkpoint 1 doubles as start/finish). Also builds
-- the showroom/lobby players spawn into. This is deliberately simple
-- rectangular geometry so it's correct without needing hand-placed art --
-- real curved Speed Oval / Technical Circuit / Stunt Yard layouts are
-- still a later art pass, but walls + size + per-track color theming get
-- it much closer to "a real track" than the original bare rectangle.

local TrackBuilder = {}

local ROAD_WIDTH = 16
local WALL_HEIGHT = 6
local WALL_THICKNESS = 1
local DEFAULT_HALF_SPAN_X = 55 -- distance from center to the left/right straights
local DEFAULT_HALF_LENGTH_Z = 85 -- distance from center to the front/back straights

local DEFAULT_THEME = {
	roadColor = Color3.fromRGB(90, 92, 100),
	wallColor = Color3.fromRGB(210, 40, 40),
	lineColor = Color3.fromRGB(250, 220, 60),
}

local function addRoadPart(parent, cframe, size, roadColor)
	local part = Instance.new("Part")
	part.Name = "RoadSegment"
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = roadColor
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A thin decorative centerline down the middle of a straight segment.
-- lengthAxis is "x" or "z" -- whichever axis the segment runs along.
local function addCenterline(parent, segmentCenter, length, lengthAxis, lineColor)
	local size
	if lengthAxis == "x" then
		size = Vector3.new(length - ROAD_WIDTH, 0.1, 1.5)
	else
		size = Vector3.new(1.5, 0.1, length - ROAD_WIDTH)
	end
	local line = Instance.new("Part")
	line.Name = "Centerline"
	line.Anchored = true
	line.CanCollide = false
	line.Size = size
	line.CFrame = CFrame.new(segmentCenter + Vector3.new(0, 1.05, 0))
	line.Color = lineColor
	line.Material = Enum.Material.Neon
	line.Parent = parent
end

-- Barrier walls flanking a straight segment so a car can't drive off the
-- track. widthAxis is the axis the road's ROAD_WIDTH runs along ("x" for
-- the left/right straights, "z" for the front/back straights); length is
-- the segment's length along the other axis.
local function addWalls(parent, segmentCenter, length, widthAxis, wallColor)
	local offset = ROAD_WIDTH / 2 + WALL_THICKNESS / 2
	local wallY = 1 + WALL_HEIGHT / 2 -- sits on top of the 1-stud-thick road

	local function addWall(position, size)
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.CanCollide = true
		wall.Size = size
		wall.CFrame = CFrame.new(position)
		wall.Color = wallColor
		wall.Material = Enum.Material.Metal
		wall.Parent = parent
	end

	if widthAxis == "x" then
		local size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length)
		addWall(segmentCenter + Vector3.new(offset, wallY, 0), size)
		addWall(segmentCenter + Vector3.new(-offset, wallY, 0), size)
	else
		local size = Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS)
		addWall(segmentCenter + Vector3.new(0, wallY, offset), size)
		addWall(segmentCenter + Vector3.new(0, wallY, -offset), size)
	end
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
-- theme lets callers vary road/wall/line color per track archetype.
function TrackBuilder.buildLoop(center, halfSpanX, halfLengthZ, theme)
	center = center or Vector3.new(0, 0, 0)
	halfSpanX = halfSpanX or DEFAULT_HALF_SPAN_X
	halfLengthZ = halfLengthZ or DEFAULT_HALF_LENGTH_Z
	theme = theme or DEFAULT_THEME

	local model = Instance.new("Model")
	model.Name = "PrototypeCircuit"

	-- Left / right straights run along Z; front / back straights run along X.
	-- Sized to overlap at the corners so there are no visible gaps.
	local straightLength = halfLengthZ * 2 + ROAD_WIDTH
	local crossLength = halfSpanX * 2 + ROAD_WIDTH

	local leftCenter = center + Vector3.new(-halfSpanX, 0.5, 0)
	local rightCenter = center + Vector3.new(halfSpanX, 0.5, 0)
	local frontCenter = center + Vector3.new(0, 0.5, halfLengthZ)
	local backCenter = center + Vector3.new(0, 0.5, -halfLengthZ)

	addRoadPart(model, CFrame.new(leftCenter), Vector3.new(ROAD_WIDTH, 1, straightLength), theme.roadColor)
	addRoadPart(model, CFrame.new(rightCenter), Vector3.new(ROAD_WIDTH, 1, straightLength), theme.roadColor)
	addRoadPart(model, CFrame.new(frontCenter), Vector3.new(crossLength, 1, ROAD_WIDTH), theme.roadColor)
	addRoadPart(model, CFrame.new(backCenter), Vector3.new(crossLength, 1, ROAD_WIDTH), theme.roadColor)

	addWalls(model, leftCenter, straightLength, "x", theme.wallColor)
	addWalls(model, rightCenter, straightLength, "x", theme.wallColor)
	addWalls(model, frontCenter, crossLength, "z", theme.wallColor)
	addWalls(model, backCenter, crossLength, "z", theme.wallColor)

	addCenterline(model, leftCenter, straightLength, "z", theme.lineColor)
	addCenterline(model, rightCenter, straightLength, "z", theme.lineColor)
	addCenterline(model, frontCenter, crossLength, "x", theme.lineColor)
	addCenterline(model, backCenter, crossLength, "x", theme.lineColor)

	-- Checkpoints in travel order: front -> right -> back -> left -> (wrap to front = lap).
	local checkpoints = {
		addCheckpoint(model, CFrame.new(frontCenter + Vector3.new(0, 3.5, 0)), Vector3.new(2, 8, ROAD_WIDTH), 1),
		addCheckpoint(model, CFrame.new(rightCenter + Vector3.new(0, 3.5, 0)), Vector3.new(ROAD_WIDTH, 8, 2), 2),
		addCheckpoint(model, CFrame.new(backCenter + Vector3.new(0, 3.5, 0)), Vector3.new(2, 8, ROAD_WIDTH), 3),
		addCheckpoint(model, CFrame.new(leftCenter + Vector3.new(0, 3.5, 0)), Vector3.new(ROAD_WIDTH, 8, 2), 4),
	}

	-- Spawn on the front straight, left of center, facing toward checkpoint 1.
	local spawnPosition = center + Vector3.new(-halfSpanX + 10, 3, halfLengthZ)
	local spawnCFrame = CFrame.new(spawnPosition, spawnPosition + Vector3.new(1, 0, 0))

	return model, checkpoints, spawnCFrame
end

-- Builds the showroom/lobby: a flat platform with a neutral SpawnLocation.
-- Teleport pads to each track are added by the caller (GameInit), which
-- owns the game-flow wiring of which pad leads where -- this module only
-- knows geometry. Returns (model, carSpawnCFrame) where carSpawnCFrame is
-- offset from the SpawnLocation so a player's car doesn't overlap it.
function TrackBuilder.buildShowroom(center, size)
	center = center or Vector3.new(0, 0, 0)
	size = size or 220

	local model = Instance.new("Model")
	model.Name = "Showroom"

	local floor = Instance.new("Part")
	floor.Name = "ShowroomFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(size, 2, size)
	floor.CFrame = CFrame.new(center + Vector3.new(0, -1, 0))
	floor.Color = Color3.fromRGB(235, 235, 240)
	floor.Material = Enum.Material.SmoothPlastic
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "ShowroomSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(center)
	spawnLocation.Color = Color3.fromRGB(60, 140, 220)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Parent = model

	local carSpawnCFrame = CFrame.new(center + Vector3.new(14, 3, 0), center + Vector3.new(24, 3, 0))

	return model, carSpawnCFrame
end

return TrackBuilder
