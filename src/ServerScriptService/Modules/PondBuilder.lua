-- Builds the shared pond + central island arena: a lotus/water-plant
-- decorated pond with fish, a big central island with a tree cluster,
-- reed-bed hiding zones, and rocky paths, plus 20 reserved frog spawn
-- points (empty for now -- Phase 1 fills them with actual frogs), the 6
-- evenly-spaced player docks around the shore, and the invisible barrier
-- that locks/unlocks the island each round.
--
-- Placeholder geometry: a plain circle for both the pond and the island,
-- not a hand-sculpted organic shape. Good enough to prove the layout and
-- the round mechanic; a real art pass is later scope.

local PondBuilder = {}

local POND_RADIUS = 140
local ISLAND_RADIUS = 55
local WATER_THICKNESS = 4
local ISLAND_HEIGHT = 4
local BARRIER_HEIGHT = 40
local NUM_FROG_SPAWNS = 20
local NUM_DOCKS = 6
local DOCK_RING_RADIUS = POND_RADIUS + 18

local FROG_SPAWN_OUTER_RING = ISLAND_RADIUS - 8 -- near cover (trees/reeds/rocks)
local FROG_SPAWN_INNER_RING = ISLAND_RADIUS - 24 -- open ground

PondBuilder.POND_RADIUS = POND_RADIUS
PondBuilder.ISLAND_RADIUS = ISLAND_RADIUS
PondBuilder.NUM_FROG_SPAWNS = NUM_FROG_SPAWNS
PondBuilder.NUM_DOCKS = NUM_DOCKS
PondBuilder.DOCK_RING_RADIUS = DOCK_RING_RADIUS
PondBuilder.ROUND_ACTIVE_SECONDS = 300
PondBuilder.ROUND_LOCK_SECONDS = 10

local function addPart(parent, name, cframe, size, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = canCollide
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- A flat disc: a Cylinder part rotated so its round faces point up/down
-- instead of the default sideways orientation. A Cylinder's round faces
-- sit perpendicular to its local X-axis by default (the same fact that
-- made an earlier project's car wheels need NO extra rotation -- there
-- the axis needed to stay sideways). Here we deliberately add a 90-degree
-- turn around Z, which moves that axis onto world Y, because a flat disc
-- needs its round faces pointing up, not sideways.
local function addDisc(parent, name, center, diameterX, diameterZ, thickness, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = canCollide
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameterX, diameterZ)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Returns a Model with the pond water surface, a bed beneath it, and
-- decorative lotus pads/blooms, water plants, and fish scattered around
-- (not on top of the island itself).
function PondBuilder.buildPond(center)
	center = center or Vector3.new(0, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Pond"

	local water = addDisc(model, "PondWater", center, POND_RADIUS * 2, POND_RADIUS * 2, WATER_THICKNESS, Color3.fromRGB(60, 150, 190), Enum.Material.Glass, false)
	water.Transparency = 0.35

	addDisc(model, "PondBed", center - Vector3.new(0, WATER_THICKNESS, 0), (POND_RADIUS + 6) * 2, (POND_RADIUS + 6) * 2, 4, Color3.fromRGB(70, 90, 60), Enum.Material.Ground, true)

	local decorationRings = { POND_RADIUS * 0.45, POND_RADIUS * 0.7, POND_RADIUS * 0.9 }

	local lotusCount = 0
	for i = 1, 10 do
		local angle = math.rad((i - 1) * 36)
		local ringRadius = decorationRings[(i % 3) + 1]
		local pos = center + Vector3.new(math.cos(angle) * ringRadius, 0.2, math.sin(angle) * ringRadius)
		addPart(model, "LotusPad", CFrame.new(pos), Vector3.new(4, 0.2, 4), Color3.fromRGB(50, 140, 70), Enum.Material.Grass, false)
		addPart(model, "LotusBloom", CFrame.new(pos + Vector3.new(0, 0.4, 0)), Vector3.new(1.4, 0.6, 1.4), Color3.fromRGB(230, 130, 190), Enum.Material.SmoothPlastic, false)
		lotusCount = lotusCount + 1
	end

	local plantCount = 0
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45 + 20)
		local ringRadius = decorationRings[(i % 3) + 1] * 0.8
		local pos = center + Vector3.new(math.cos(angle) * ringRadius, 1, math.sin(angle) * ringRadius)
		addPart(model, "WaterPlant", CFrame.new(pos), Vector3.new(0.6, 2.5, 0.6), Color3.fromRGB(40, 120, 60), Enum.Material.Grass, false)
		plantCount = plantCount + 1
	end

	local fishCount = 0
	for i = 1, 6 do
		local angle = math.rad((i - 1) * 60 + 10)
		local ringRadius = POND_RADIUS * 0.6
		local pos = center + Vector3.new(math.cos(angle) * ringRadius, -0.5, math.sin(angle) * ringRadius)
		addPart(model, "Fish", CFrame.new(pos), Vector3.new(1.6, 0.6, 0.6), Color3.fromRGB(240, 150, 40), Enum.Material.Neon, false)
		fishCount = fishCount + 1
	end

	model:SetAttribute("LotusCount", lotusCount)
	model:SetAttribute("WaterPlantCount", plantCount)
	model:SetAttribute("FishCount", fishCount)

	return model
end

-- Returns (model, spawnPoints). spawnPoints is an ordered list of 20
-- invisible markers alternating between the outer ring (near cover --
-- trees/reeds/rocks, for the hide/reveal mechanic) and the inner ring
-- (open ground, easy to spot). Each carries a HasCover attribute. Actual
-- frogs are a later phase; these are just the reserved placement slots.
function PondBuilder.buildIsland(center)
	center = center or Vector3.new(0, 0, 0)
	local model = Instance.new("Model")
	model.Name = "FrogIsland"

	addDisc(model, "IslandPlatform", center, ISLAND_RADIUS * 2, ISLAND_RADIUS * 2, ISLAND_HEIGHT, Color3.fromRGB(100, 150, 80), Enum.Material.Grass, true)

	-- Central tree cluster.
	local treeCount = 0
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90)
		local pos = center + Vector3.new(math.cos(angle) * 8, ISLAND_HEIGHT / 2, math.sin(angle) * 8)
		addPart(model, "TreeTrunk", CFrame.new(pos + Vector3.new(0, 4, 0)), Vector3.new(2, 8, 2), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, true)
		addPart(model, "TreeLeaves", CFrame.new(pos + Vector3.new(0, 9, 0)), Vector3.new(9, 7, 9), Color3.fromRGB(230, 150, 200), Enum.Material.Grass, false)
		treeCount = treeCount + 1
	end

	-- Reed-bed hiding zones: 3 clumps of 4 reeds each.
	local reedClumpCenters = {
		center + Vector3.new(ISLAND_RADIUS * 0.5, 0, ISLAND_RADIUS * 0.3),
		center + Vector3.new(-ISLAND_RADIUS * 0.4, 0, ISLAND_RADIUS * 0.5),
		center + Vector3.new(-ISLAND_RADIUS * 0.3, 0, -ISLAND_RADIUS * 0.55),
	}
	local reedCount = 0
	for _, clumpCenter in ipairs(reedClumpCenters) do
		for i = 1, 4 do
			local offset = Vector3.new(math.cos(math.rad(i * 90)) * 3, ISLAND_HEIGHT / 2 + 1.5, math.sin(math.rad(i * 90)) * 3)
			addPart(model, "Reed", CFrame.new(clumpCenter + offset), Vector3.new(0.5, 3, 0.5), Color3.fromRGB(60, 130, 70), Enum.Material.Grass, false)
			reedCount = reedCount + 1
		end
	end

	-- Rocky paths.
	local rockOffsets = {
		Vector3.new(20, 0, -10),
		Vector3.new(-18, 0, 12),
		Vector3.new(10, 0, 28),
		Vector3.new(-25, 0, -20),
		Vector3.new(30, 0, 15),
		Vector3.new(-8, 0, -32),
	}
	local rockCount = 0
	for _, offset in ipairs(rockOffsets) do
		addPart(model, "Rock", CFrame.new(center + offset + Vector3.new(0, ISLAND_HEIGHT / 2 + 1, 0)), Vector3.new(3, 2, 3), Color3.fromRGB(120, 120, 120), Enum.Material.Slate, true)
		rockCount = rockCount + 1
	end

	local spawnPoints = {}
	for i = 1, NUM_FROG_SPAWNS do
		local angle = math.rad((i - 1) * (360 / NUM_FROG_SPAWNS))
		local hasCover = (i % 2 == 0)
		local ringRadius = hasCover and FROG_SPAWN_OUTER_RING or FROG_SPAWN_INNER_RING
		local pos = center + Vector3.new(math.cos(angle) * ringRadius, ISLAND_HEIGHT / 2 + 0.5, math.sin(angle) * ringRadius)
		local marker = addPart(model, "FrogSpawnPoint", CFrame.new(pos), Vector3.new(2, 0.2, 2), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
		marker.Transparency = 1
		marker:SetAttribute("HasCover", hasCover)
		marker:SetAttribute("Order", i)
		table.insert(spawnPoints, marker)
	end

	model:SetAttribute("TreeCount", treeCount)
	model:SetAttribute("ReedCount", reedCount)
	model:SetAttribute("RockCount", rockCount)

	return model, spawnPoints
end

-- The island lock: a single solid Cylinder part sized to the island's
-- full footprint (a bit wider, and tall enough to span from below the
-- pond bed to above the tree line). Its curved side surface acts as a
-- wall all the way around the island -- no need for a segmented ring --
-- and toggling CanCollide locks or opens the whole island at once.
function PondBuilder.buildIslandBarrier(parent, center)
	local barrier = Instance.new("Part")
	barrier.Name = "IslandLockBarrier"
	barrier.Anchored = true
	barrier.CanCollide = true -- starts locked
	barrier.Transparency = 0.55
	barrier.Color = Color3.fromRGB(130, 210, 255)
	barrier.Material = Enum.Material.ForceField
	barrier.Shape = Enum.PartType.Cylinder
	barrier.Size = Vector3.new(BARRIER_HEIGHT, (ISLAND_RADIUS + 3) * 2, (ISLAND_RADIUS + 3) * 2)
	barrier.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	barrier.Parent = parent
	return barrier
end

function PondBuilder.setBarrierLocked(barrier, locked)
	barrier.CanCollide = locked
	barrier.Transparency = locked and 0.55 or 1
end

-- Returns (model, docks). docks is a list of NUM_DOCKS entries, each
-- { platform = Part, spawnCFrame = CFrame }, evenly spaced around the
-- shore just outside the pond, each facing the pond center.
function PondBuilder.buildDocks(center)
	local model = Instance.new("Folder")
	model.Name = "Docks"

	local docks = {}
	for i = 1, NUM_DOCKS do
		local angle = math.rad((i - 1) * (360 / NUM_DOCKS))
		local pos = center + Vector3.new(math.cos(angle) * DOCK_RING_RADIUS, 1, math.sin(angle) * DOCK_RING_RADIUS)
		local platform = addPart(model, "PlayerDock", CFrame.new(pos), Vector3.new(10, 2, 10), Color3.fromRGB(200, 190, 160), Enum.Material.WoodPlanks, true)
		platform:SetAttribute("DockIndex", i)
		local spawnCFrame = CFrame.new(pos + Vector3.new(0, 3, 0), center)
		table.insert(docks, { platform = platform, spawnCFrame = spawnCFrame })
	end

	return model, docks
end

return PondBuilder
