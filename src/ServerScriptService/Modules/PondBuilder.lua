--[[
    FROG GAME - POND & ISLAND WORLD BUILDER

    Builds the shared pond + central Frog Island environment: a large
    pond with lily pads/lotus flowers, sakura trees, reed beds, rocks, a
    decorative sailboat, and six player display buildings (each with 6
    doll display slots) arranged in a ring facing the pond.

    This module owns geometry only. PondBuilder.build() does the actual
    world construction (parenting everything into Workspace/Lighting) and
    returns a handle table for the caller (GameInit) to layer gameplay on
    top of -- frog spawning, catching, kissing, the island lock/round
    timer, and the economy are built separately in GameInit.server.lua.
]]

local PondBuilder = {}

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------

local CONFIG = {
	WorldFolderName = "FrogGameWorld",

	PondCenter = Vector3.new(0, 0, 0),
	PondRadius = 150,
	WaterHeight = 2,

	IslandCenter = Vector3.new(0, 3, 0),
	IslandRadius = 48,

	PlayerAreaRadius = 125,
	HouseCount = 6,

	-- Decorative density
	LilyPadCount = 30,
	LotusCount = 12,
	RockCount = 45,
	ReedBedCount = 10,
	SakuraTreeCount = 12,
	FallingPetalCount = 80,

	-- Layered on top by GameInit; stored here too so the world's own
	-- attributes (set at the bottom of build()) always match.
	MaxPlayers = 6,
	MaxFrogs = 20,
	ActiveRoundSeconds = 300,
	ResetSeconds = 10,
	LegendaryTimerSeconds = 1800,
	SecretTimerSeconds = 3600,
}

PondBuilder.CONFIG = CONFIG

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function makePart(parent, name, size, cframe, material, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color or Color3.fromRGB(255, 255, 255)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth

	if shape then
		p.Shape = shape
	end

	p.Parent = parent
	return p
end

local function makeCylinder(parent, name, radius, height, position, material, color)
	return makePart(
		parent,
		name,
		Vector3.new(radius * 2, height, radius * 2),
		CFrame.new(position),
		material,
		color,
		Enum.PartType.Cylinder
	)
end

local function makeBall(parent, name, size, position, material, color)
	return makePart(parent, name, size, CFrame.new(position), material, color, Enum.PartType.Ball)
end

local function polar(center, radius, angle, y)
	return center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function randomXZ(center, radius, y)
	local angle = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * radius
	return polar(center, r, angle, y)
end

local function makeBillboardText(parent, text, position)
	local anchor = makePart(
		parent,
		"LabelAnchor",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position),
		Enum.Material.SmoothPlastic,
		Color3.new(1, 1, 1)
	)
	anchor.Transparency = 1
	anchor.CanCollide = false

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 55)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

	return anchor
end

local function makeSakuraTree(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "SakuraTree"
	model.Parent = parent

	local trunkHeight = 13 * scale
	makeCylinder(
		model,
		"Trunk",
		1.8 * scale,
		trunkHeight,
		position + Vector3.new(0, trunkHeight / 2, 0),
		Enum.Material.Wood,
		Color3.fromRGB(91, 61, 46)
	)

	local crownPositions = {
		Vector3.new(0, 17, 0),
		Vector3.new(-5, 15, 1),
		Vector3.new(5, 15, -1),
		Vector3.new(0, 20, -2),
		Vector3.new(-3, 19, 3),
		Vector3.new(4, 18, 3),
	}

	for i, offset in ipairs(crownPositions) do
		makeBall(
			model,
			"PinkCrown_" .. i,
			Vector3.new(10, 8, 10) * scale,
			position + offset * scale,
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(245, 157, 198)
		)
	end

	for i = 1, 15 do
		local a = math.random() * math.pi * 2
		local r = math.random(3, 9) * scale
		local y = math.random(14, 21) * scale

		makeBall(
			model,
			"Blossom_" .. i,
			Vector3.new(1.2, 1.2, 1.2) * scale,
			position + Vector3.new(math.cos(a) * r, y, math.sin(a) * r),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 191, 218)
		)
	end

	return model
end

local function makeBush(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "Bush"
	model.Parent = parent

	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2
		local offset = Vector3.new(math.cos(a) * 2.2, math.random() * 1.3, math.sin(a) * 2.2)

		makeBall(
			model,
			"LeafCluster",
			Vector3.new(5, 4, 5) * scale,
			position + offset * scale,
			Enum.Material.Grass,
			Color3.fromRGB(58, 117 + math.random(0, 25), 61)
		)
	end

	return model
end

local function makeRock(parent, position, scale)
	return makePart(
		parent,
		"Rock",
		Vector3.new(5, 3.5, 4) * scale,
		CFrame.new(position)
			* CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(math.random(0, 180)), math.rad(math.random(-8, 8))),
		Enum.Material.Slate,
		Color3.fromRGB(112, 116, 108)
	)
end

local function makeReedBed(parent, center, width, count)
	local folder = Instance.new("Folder")
	folder.Name = "ReedBed"
	folder.Parent = parent

	for i = 1, count do
		local x = (math.random() - 0.5) * width
		local z = (math.random() - 0.5) * width
		local h = math.random(5, 9)

		local reed = makePart(
			folder,
			"Reed",
			Vector3.new(0.35, h, 0.35),
			CFrame.new(center + Vector3.new(x, h / 2, z))
				* CFrame.Angles(math.rad(math.random(-10, 10)), 0, math.rad(math.random(-10, 10))),
			Enum.Material.Grass,
			Color3.fromRGB(69, 124, 61)
		)
		reed.CanCollide = false

		local tip = makePart(
			folder,
			"ReedTip",
			Vector3.new(0.55, 1.2, 0.55),
			reed.Position + Vector3.new(0, h / 2, 0),
			Enum.Material.Grass,
			Color3.fromRGB(102, 75, 47),
			Enum.PartType.Cylinder
		)
		tip.CanCollide = false
	end
end

local function makeLilyPad(parent, position, scale)
	local pad = makePart(
		parent,
		"LilyPad",
		Vector3.new(4.5, 0.35, 4.5) * scale,
		CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi, 0),
		Enum.Material.Grass,
		Color3.fromRGB(75, 150, 72)
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.CanCollide = false
	return pad
end

local function makeLotus(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "LotusFlower"
	model.Parent = parent

	makeLilyPad(model, position, scale * 1.15)

	local petalCount = 8
	for i = 1, petalCount do
		local angle = ((i - 1) / petalCount) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 1.15 * scale, 0.75 * scale, math.sin(angle) * 1.15 * scale)

		local petal = makeBall(
			model,
			"Petal",
			Vector3.new(1.6, 0.5, 2.5) * scale,
			position + offset,
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 172, 205)
		)

		petal.CFrame = CFrame.lookAt(petal.Position, position + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(-25), 0, 0)
		petal.CanCollide = false
	end

	makeBall(
		model,
		"FlowerCenter",
		Vector3.new(1.4, 0.8, 1.4) * scale,
		position + Vector3.new(0, 1.0 * scale, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(255, 221, 93)
	)
end

-- Builds one player's display house at CFrame `cf` (its facing direction
-- is CF's -Z / LookVector -- the door and windows are built along that
-- axis so the house actually faces wherever `cf` points, instead of every
-- house facing the same fixed world direction regardless of its spot on
-- the ring).
local function makeHouse(parent, cf, index)
	local model = Instance.new("Model")
	model.Name = "Player" .. index .. "_DisplayBuilding"
	model.Parent = parent

	makePart(model, "HouseBase", Vector3.new(22, 1, 18), cf * CFrame.new(0, 0.5, 0), Enum.Material.WoodPlanks, Color3.fromRGB(155, 106, 73))

	makePart(model, "HouseWalls", Vector3.new(20, 10, 16), cf * CFrame.new(0, 5.5, 0), Enum.Material.Wood, Color3.fromRGB(218, 174, 127))

	local roof = makePart(
		model,
		"Roof",
		Vector3.new(23, 3, 19),
		cf * CFrame.new(0, 12, 0) * CFrame.Angles(0, math.rad(45), 0),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(155, 75, 89)
	)
	roof.CanCollide = true

	makePart(model, "Door", Vector3.new(4, 6, 0.5), cf * CFrame.new(0, 3.5, -8.2), Enum.Material.Wood, Color3.fromRGB(92, 59, 43))

	for _, x in ipairs({ -6, 6 }) do
		local window = makePart(
			model,
			"Window",
			Vector3.new(4, 3.5, 0.35),
			cf * CFrame.new(x, 6, -8.25),
			Enum.Material.Glass,
			Color3.fromRGB(143, 218, 231)
		)
		window.CanCollide = false
	end

	makeBillboardText(model, "PLAYER " .. index, (cf * CFrame.new(0, 15, 0)).Position)

	local displayFolder = Instance.new("Folder")
	displayFolder.Name = "SixDollDisplaySlots"
	displayFolder.Parent = model

	local slotOffsets = {
		Vector3.new(-6, 2, -3),
		Vector3.new(0, 2, -3),
		Vector3.new(6, 2, -3),
		Vector3.new(-6, 2, 3),
		Vector3.new(0, 2, 3),
		Vector3.new(6, 2, 3),
	}

	for slot, offset in ipairs(slotOffsets) do
		local display = makePart(
			displayFolder,
			"DollSlot_" .. slot,
			Vector3.new(3.5, 0.35, 3.5),
			cf * CFrame.new(offset.X, 1.2, offset.Z),
			Enum.Material.Marble,
			Color3.fromRGB(210, 201, 183)
		)
		display.CanCollide = true
	end

	return model
end

----------------------------------------------------------------
-- BUILD
----------------------------------------------------------------

-- Builds the whole world into Workspace/Lighting and returns a handle:
-- { world, pond, island, playerAreasFolder, decoration, markers,
--   playerAreas (list of { index, folder, house, spawnCFrame }),
--   frogSpawnRegion, visibilityBreakPositions (list of Vector3) }
function PondBuilder.build()
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")

	local oldWorld = Workspace:FindFirstChild(CONFIG.WorldFolderName)
	if oldWorld then
		oldWorld:Destroy()
	end

	local World = Instance.new("Folder")
	World.Name = CONFIG.WorldFolderName
	World.Parent = Workspace

	local PondFolder = Instance.new("Folder")
	PondFolder.Name = "Pond"
	PondFolder.Parent = World

	local IslandFolder = Instance.new("Folder")
	IslandFolder.Name = "FrogIsland"
	IslandFolder.Parent = World

	local PlayerAreasFolder = Instance.new("Folder")
	PlayerAreasFolder.Name = "SixPlayerAreas"
	PlayerAreasFolder.Parent = World

	local DecorationFolder = Instance.new("Folder")
	DecorationFolder.Name = "Decoration"
	DecorationFolder.Parent = World

	local MarkersFolder = Instance.new("Folder")
	MarkersFolder.Name = "GameplayMarkers"
	MarkersFolder.Parent = World

	-- ===== Lighting / atmosphere =====

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 190)

	local atmosphere = Lighting:FindFirstChild("FrogPondAtmosphere")
	if atmosphere then
		atmosphere:Destroy()
	end

	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "FrogPondAtmosphere"
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(190, 220, 225)
	atmosphere.Decay = Color3.fromRGB(120, 160, 145)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 0.55
	atmosphere.Parent = Lighting

	-- ===== Ground =====

	makePart(World, "WorldGround", Vector3.new(430, 4, 430), CFrame.new(0, -2, 0), Enum.Material.Grass, Color3.fromRGB(93, 140, 78))

	-- ===== Pond =====

	makeCylinder(PondFolder, "PondBed", CONFIG.PondRadius, 5, Vector3.new(0, -0.5, 0), Enum.Material.Sand, Color3.fromRGB(206, 188, 135))

	local water = makeCylinder(
		PondFolder,
		"PondWater",
		CONFIG.PondRadius - 2,
		1.2,
		Vector3.new(0, CONFIG.WaterHeight, 0),
		Enum.Material.Glass,
		Color3.fromRGB(104, 190, 220)
	)
	water.Transparency = 0.35
	water.CanCollide = false
	water.CastShadow = false

	local shoreline = makeCylinder(
		PondFolder,
		"PondShore",
		CONFIG.PondRadius + 1,
		1,
		Vector3.new(0, 0.9, 0),
		Enum.Material.Grass,
		Color3.fromRGB(88, 132, 72)
	)
	shoreline.CanCollide = true

	-- ===== Central Frog Island =====

	makeCylinder(IslandFolder, "IslandBase", CONFIG.IslandRadius, 6, CONFIG.IslandCenter, Enum.Material.Grass, Color3.fromRGB(91, 148, 77))

	makeCylinder(
		IslandFolder,
		"IslandEdge",
		CONFIG.IslandRadius + 2,
		1.5,
		CONFIG.IslandCenter + Vector3.new(0, 2.4, 0),
		Enum.Material.Ground,
		Color3.fromRGB(145, 113, 77)
	)

	makeCylinder(
		IslandFolder,
		"IslandInner",
		CONFIG.IslandRadius - 5,
		1.2,
		CONFIG.IslandCenter + Vector3.new(0, 5.0, 0),
		Enum.Material.Grass,
		Color3.fromRGB(112, 165, 83)
	)

	-- Natural path stones ringing the island.
	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "NaturalPaths"
	pathFolder.Parent = IslandFolder

	local pathRadius = 25
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local pos = polar(CONFIG.IslandCenter, pathRadius, angle, 6.1)
		local stone = makePart(
			pathFolder,
			"PathStone_" .. i,
			Vector3.new(7, 0.7, 4.5),
			CFrame.new(pos) * CFrame.Angles(0, -angle, 0),
			Enum.Material.Slate,
			Color3.fromRGB(137, 139, 132)
		)
		stone.CanCollide = true
	end

	-- Central sakura tree.
	makeSakuraTree(DecorationFolder, CONFIG.IslandCenter + Vector3.new(0, 5, 0), 1.25)

	-- Bush/rock groups that deliberately block sightlines -- Phase 1's
	-- frog hide/reveal-near-cover mechanic hides frogs near these.
	local visibilityBreaks = {
		Vector3.new(-27, 6, -13),
		Vector3.new(26, 6, -10),
		Vector3.new(-25, 6, 17),
		Vector3.new(27, 6, 18),
		Vector3.new(-12, 6, 27),
		Vector3.new(14, 6, 27),
	}

	local visibilityBreakPositions = {}
	for _, p in ipairs(visibilityBreaks) do
		local absolutePosition = CONFIG.IslandCenter + p
		makeBush(IslandFolder, absolutePosition, 1)
		makeRock(IslandFolder, absolutePosition + Vector3.new(4, 0, 2), 0.9)
		table.insert(visibilityBreakPositions, absolutePosition)
	end

	-- Reed beds.
	makeReedBed(DecorationFolder, CONFIG.IslandCenter + Vector3.new(22, 6, 17), 13, 22)
	makeReedBed(DecorationFolder, CONFIG.IslandCenter + Vector3.new(-24, 6, -18), 11, 20)

	-- ===== Lily pads / lotus flowers =====

	for _ = 1, CONFIG.LilyPadCount do
		local p = randomXZ(CONFIG.PondCenter, CONFIG.PondRadius - 12, CONFIG.WaterHeight + 0.75)
		if p.Magnitude > CONFIG.IslandRadius + 12 then
			makeLilyPad(DecorationFolder, p, math.random(70, 110) / 100)
		end
	end

	local lotusPositions = {
		Vector3.new(-80, 3.2, -48),
		Vector3.new(-58, 3.2, 55),
		Vector3.new(72, 3.2, 48),
		Vector3.new(84, 3.2, -35),
		Vector3.new(-15, 3.2, 78),
		Vector3.new(32, 3.2, -88),
		Vector3.new(-92, 3.2, 5),
		Vector3.new(93, 3.2, 8),
		Vector3.new(50, 3.2, 82),
		Vector3.new(-50, 3.2, -82),
		Vector3.new(8, 3.2, 95),
		Vector3.new(-20, 3.2, -65),
	}
	for _, p in ipairs(lotusPositions) do
		makeLotus(DecorationFolder, p, math.random(80, 115) / 100)
	end

	-- ===== Pond rocks =====

	for _ = 1, CONFIG.RockCount do
		local p = randomXZ(CONFIG.PondCenter, CONFIG.PondRadius - 5, 2.6)
		if p.Magnitude > CONFIG.IslandRadius + 7 then
			makeRock(DecorationFolder, p, math.random(55, 130) / 100)
		end
	end

	-- ===== More sakura trees around the pond =====

	local treePositions = {
		Vector3.new(-120, 0, -95),
		Vector3.new(-70, 0, -120),
		Vector3.new(15, 0, -125),
		Vector3.new(85, 0, -105),
		Vector3.new(125, 0, -30),
		Vector3.new(120, 0, 70),
		Vector3.new(75, 0, 120),
		Vector3.new(-10, 0, 125),
		Vector3.new(-90, 0, 105),
		Vector3.new(-130, 0, 45),
		Vector3.new(-135, 0, -35),
	}
	for _, p in ipairs(treePositions) do
		makeSakuraTree(DecorationFolder, p, math.random(80, 115) / 100)
	end

	-- ===== Falling sakura petals =====

	local petalsFolder = Instance.new("Folder")
	petalsFolder.Name = "FallingSakuraPetals"
	petalsFolder.Parent = DecorationFolder

	for _ = 1, CONFIG.FallingPetalCount do
		local angle = math.random() * math.pi * 2
		local r = math.random(15, 135)
		local y = math.random(8, 35)
		local petal = makePart(
			petalsFolder,
			"Petal",
			Vector3.new(0.35, 0.08, 0.6),
			polar(CONFIG.PondCenter, r, angle, y),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 172, 207)
		)
		petal.CanCollide = false
		petal.CanTouch = false
		petal.CanQuery = false
		petal.Transparency = 0.15
	end

	-- ===== Decorative sailboat =====

	local boatFolder = Instance.new("Model")
	boatFolder.Name = "DecorativeSailboat"
	boatFolder.Parent = DecorationFolder

	local boatPosition = Vector3.new(70, 4.0, -15)

	makePart(
		boatFolder,
		"Hull",
		Vector3.new(18, 2.5, 7),
		CFrame.new(boatPosition) * CFrame.Angles(0, math.rad(-15), 0),
		Enum.Material.Wood,
		Color3.fromRGB(120, 75, 45)
	)
	makePart(
		boatFolder,
		"Bow",
		Vector3.new(6, 2.5, 7),
		CFrame.new(boatPosition + Vector3.new(8, 0, 0)) * CFrame.Angles(0, math.rad(-15), 0),
		Enum.Material.Wood,
		Color3.fromRGB(145, 89, 49)
	)
	makeCylinder(boatFolder, "Mast", 0.35, 14, boatPosition + Vector3.new(0, 7, 0), Enum.Material.Wood, Color3.fromRGB(87, 61, 43))
	local sail = makePart(
		boatFolder,
		"Sail",
		Vector3.new(0.25, 9, 8),
		CFrame.new(boatPosition + Vector3.new(1, 8, 0)),
		Enum.Material.Fabric,
		Color3.fromRGB(245, 238, 210)
	)
	sail.CanCollide = false

	-- ===== Six player areas + display houses =====

	local playerAreas = {}

	for i = 1, CONFIG.HouseCount do
		local angle = ((i - 1) / CONFIG.HouseCount) * math.pi * 2
		local p = polar(Vector3.new(0, 0, 0), CONFIG.PlayerAreaRadius, angle, 0)
		local housePos = Vector3.new(p.X, 0, p.Z)

		-- Face the house (door, windows, spawn point) toward the pond.
		local houseCFrame = CFrame.lookAt(housePos, Vector3.new(0, housePos.Y, 0))

		local area = Instance.new("Folder")
		area.Name = "PlayerArea_" .. i
		area.Parent = PlayerAreasFolder

		local house = makeHouse(area, houseCFrame, i)

		-- Just outside the front door, between the house and the pond.
		local spawnCFrame = houseCFrame * CFrame.new(0, 1, -14)
		local spawn = makePart(
			area,
			"PlayerSpawn_" .. i,
			Vector3.new(6, 0.25, 6),
			spawnCFrame,
			Enum.Material.Neon,
			Color3.fromRGB(150, 220, 160)
		)
		spawn.Transparency = 1
		spawn.CanCollide = false

		table.insert(playerAreas, { index = i, folder = area, house = house, houseCFrame = houseCFrame, spawnCFrame = spawnCFrame })
	end

	-- ===== Island access / race start markers =====

	local raceStart = makePart(
		MarkersFolder,
		"RaceStart",
		Vector3.new(42, 0.4, 18),
		CFrame.new(0, 3.2, -72),
		Enum.Material.Neon,
		Color3.fromRGB(255, 235, 120)
	)
	raceStart.Transparency = 0.75
	raceStart.CanCollide = false

	local islandEntrance = makePart(
		MarkersFolder,
		"IslandEntrance",
		Vector3.new(18, 0.5, 18),
		CFrame.new(0, 6, -47),
		Enum.Material.Neon,
		Color3.fromRGB(120, 255, 170)
	)
	islandEntrance.Transparency = 0.8
	islandEntrance.CanCollide = false

	makeBillboardText(MarkersFolder, "FROG ISLAND", CONFIG.IslandCenter + Vector3.new(0, 25, 0))

	-- ===== Island decoration: small flowers =====

	local flowerColors = {
		Color3.fromRGB(255, 188, 208),
		Color3.fromRGB(255, 232, 139),
		Color3.fromRGB(184, 155, 245),
		Color3.fromRGB(255, 255, 255),
	}

	for _ = 1, 35 do
		local p = randomXZ(CONFIG.IslandCenter, CONFIG.IslandRadius - 9, 6.4)
		local stem = makePart(
			DecorationFolder,
			"SmallFlowerStem",
			Vector3.new(0.18, 1.2, 0.18),
			CFrame.new(p + Vector3.new(0, 0.6, 0)),
			Enum.Material.Grass,
			Color3.fromRGB(61, 128, 60)
		)
		stem.CanCollide = false

		makeBall(
			DecorationFolder,
			"SmallFlower",
			Vector3.new(0.9, 0.5, 0.9),
			p + Vector3.new(0, 1.25, 0),
			Enum.Material.SmoothPlastic,
			flowerColors[math.random(1, #flowerColors)]
		)
	end

	-- ===== Water ripple rings (decorative) =====

	local rippleFolder = Instance.new("Folder")
	rippleFolder.Name = "WaterRipples"
	rippleFolder.Parent = DecorationFolder

	for _ = 1, 14 do
		local p = randomXZ(CONFIG.PondCenter, CONFIG.PondRadius - 15, CONFIG.WaterHeight + 0.65)
		if p.Magnitude > CONFIG.IslandRadius + 15 then
			local ripple = makeCylinder(rippleFolder, "Ripple", math.random(2, 5), 0.04, p, Enum.Material.Neon, Color3.fromRGB(170, 230, 240))
			ripple.Transparency = 0.65
			ripple.CanCollide = false
		end
	end

	-- ===== Frog spawn region marker =====
	-- A single area marker covering the island -- Phase 1's frog spawner
	-- picks positions within it (and near the visibilityBreakPositions
	-- above for the hide/reveal mechanic), rather than a fixed list of
	-- slots.

	local frogRegion = makePart(
		MarkersFolder,
		"FrogSpawnRegion",
		Vector3.new(CONFIG.IslandRadius * 1.7, 0.3, CONFIG.IslandRadius * 1.7),
		CFrame.new(CONFIG.IslandCenter + Vector3.new(0, 6.5, 0)),
		Enum.Material.Neon,
		Color3.fromRGB(120, 255, 100)
	)
	frogRegion.Transparency = 1
	frogRegion.CanCollide = false
	frogRegion.CanTouch = false
	frogRegion.CanQuery = true

	-- ===== Final organization =====

	World:SetAttribute("MaxPlayers", CONFIG.MaxPlayers)
	World:SetAttribute("MaxFrogs", CONFIG.MaxFrogs)
	World:SetAttribute("ActiveRoundSeconds", CONFIG.ActiveRoundSeconds)
	World:SetAttribute("ResetSeconds", CONFIG.ResetSeconds)
	World:SetAttribute("LegendaryTimerSeconds", CONFIG.LegendaryTimerSeconds)
	World:SetAttribute("SecretTimerSeconds", CONFIG.SecretTimerSeconds)

	return {
		world = World,
		pond = PondFolder,
		island = IslandFolder,
		playerAreasFolder = PlayerAreasFolder,
		decoration = DecorationFolder,
		markers = MarkersFolder,
		playerAreas = playerAreas,
		frogSpawnRegion = frogRegion,
		visibilityBreakPositions = visibilityBreakPositions,
	}
end

----------------------------------------------------------------
-- ISLAND LOCK BARRIER (not part of the uploaded environment script --
-- added back so GameInit can run the 5-minute-open/10-second-lock round
-- exactly as designed).
----------------------------------------------------------------

-- A single solid Cylinder sized to the island's full footprint. Its
-- curved side surface acts as a wall all the way around -- no segmented
-- ring needed -- and toggling CanCollide locks/unlocks the whole island
-- at once. The 90-degree Z rotation turns its round faces to point
-- up/down instead of the default sideways orientation (the same rotation
-- math the pond/island discs already rely on).
function PondBuilder.buildIslandBarrier(parent, center, radius)
	center = center or CONFIG.IslandCenter
	radius = radius or CONFIG.IslandRadius

	local barrierHeight = 50
	local barrier = Instance.new("Part")
	barrier.Name = "IslandLockBarrier"
	barrier.Anchored = true
	barrier.CanCollide = true -- starts locked
	barrier.Transparency = 0.55
	barrier.Color = Color3.fromRGB(130, 210, 255)
	barrier.Material = Enum.Material.ForceField
	barrier.Shape = Enum.PartType.Cylinder
	barrier.Size = Vector3.new(barrierHeight, (radius + 3) * 2, (radius + 3) * 2)
	barrier.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	barrier.Parent = parent
	return barrier
end

function PondBuilder.setBarrierLocked(barrier, locked)
	barrier.CanCollide = locked
	barrier.Transparency = locked and 0.55 or 1
end

return PondBuilder
