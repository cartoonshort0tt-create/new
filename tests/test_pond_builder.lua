-- Exercises PondBuilder's actual world-building logic against the mock
-- Roblox environment -- catches real math/API mistakes, not just syntax.
-- Position math for randomly-scattered decoration (lily pads, pond rocks,
-- falling petals filtered by distance) isn't asserted exactly since it's
-- genuinely randomized; everything with a deterministic count or a fixed
-- position IS checked.

local mock = require("tests.mock_roblox")
local T = require("tests.helpers")
T.suite("PondBuilder")

local moduleInstance = mock.newModuleScript(nil, "PondBuilder", "src/ServerScriptService/Modules/PondBuilder.lua")
local PondBuilder = mock.load(moduleInstance)

local world = PondBuilder.build()
local CONFIG = PondBuilder.CONFIG

-- ===== Top-level structure =====

T.assertEqual(world.world.Name, CONFIG.WorldFolderName, "world folder is named per CONFIG")
T.assertEqual(world.world.Parent, mock.workspace, "world folder is parented to Workspace")
T.assertEqual(world.pond.Name, "Pond", "pond folder exists")
T.assertEqual(world.island.Name, "FrogIsland", "island folder exists")
T.assertEqual(world.playerAreasFolder.Name, "SixPlayerAreas", "player areas folder exists")
T.assertEqual(world.decoration.Name, "Decoration", "decoration folder exists")
T.assertEqual(world.markers.Name, "GameplayMarkers", "markers folder exists")

-- Calling build() again should replace the old world, not duplicate it
-- (GameInit only calls this once, but a stale leftover from a previous
-- run in Studio shouldn't linger).
local secondWorld = PondBuilder.build()
local worldFolders = 0
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == CONFIG.WorldFolderName then
		worldFolders = worldFolders + 1
	end
end
T.assertEqual(worldFolders, 1, "re-building replaces the old world instead of duplicating it")
world = secondWorld

-- ===== Pond =====

local pondWater = world.pond:FindFirstChild("PondWater")
T.assertTrue(pondWater ~= nil, "pond has a PondWater part")
if pondWater then
	T.assertEqual(pondWater.CanCollide, false, "water isn't solid -- players swim through it")
	T.assertEqual(pondWater.Shape, mock.Enum.PartType.Cylinder, "water is a disc (Cylinder shape)")
end
local pondShore = world.pond:FindFirstChild("PondShore")
T.assertTrue(pondShore ~= nil, "pond has a PondShore ring")
if pondShore then
	T.assertEqual(pondShore.CanCollide, true, "shoreline is solid ground")
end

-- ===== Island =====

T.assertTrue(world.island:FindFirstChild("IslandBase") ~= nil, "island has a base platform")
T.assertTrue(world.island:FindFirstChild("IslandEdge") ~= nil, "island has an edge ring")
T.assertTrue(world.island:FindFirstChild("IslandInner") ~= nil, "island has an inner platform")

local pathStoneCount = 0
local naturalPaths = world.island:FindFirstChild("NaturalPaths")
T.assertTrue(naturalPaths ~= nil, "island has a NaturalPaths folder")
if naturalPaths then
	for _, child in ipairs(naturalPaths:GetChildren()) do
		if child.Name:match("^PathStone_") then
			pathStoneCount = pathStoneCount + 1
		end
	end
end
T.assertEqual(pathStoneCount, 18, "18 path stones ring the island")

local bushCount, visibilityRockCount = 0, 0
for _, child in ipairs(world.island:GetChildren()) do
	if child.Name == "Bush" then
		bushCount = bushCount + 1
	elseif child.Name == "Rock" then
		visibilityRockCount = visibilityRockCount + 1
	end
end
T.assertEqual(bushCount, 6, "6 visibility-break bushes on the island")
T.assertEqual(visibilityRockCount, 6, "6 visibility-break rocks on the island")
T.assertEqual(#world.visibilityBreakPositions, 6, "6 visibility-break positions returned for Phase 1's frog hiding spots")

-- ===== Reed beds (fixed counts, no random filtering) =====

local reedCount = 0
for _, child in ipairs(world.decoration:GetChildren()) do
	if child.Name == "ReedBed" then
		for _, reedChild in ipairs(child:GetChildren()) do
			if reedChild.Name == "Reed" then
				reedCount = reedCount + 1
			end
		end
	end
end
T.assertEqual(reedCount, 42, "42 reeds total across the two reed beds (22 + 20)")

-- ===== Lotus flowers (fixed position list, no filtering) =====

local lotusCount = 0
for _, child in ipairs(world.decoration:GetChildren()) do
	if child.Name == "LotusFlower" then
		lotusCount = lotusCount + 1
	end
end
T.assertEqual(lotusCount, 12, "12 lotus flowers at their fixed positions")

-- ===== Sakura trees (1 central + 11 around the pond, fixed positions) =====

local sakuraCount = 0
for _, child in ipairs(world.decoration:GetChildren()) do
	if child.Name == "SakuraTree" then
		sakuraCount = sakuraCount + 1
	end
end
T.assertEqual(sakuraCount, 12, "12 sakura trees (1 central island tree + 11 around the pond)")

-- ===== Falling petals + small flowers (fixed counts, no filtering) =====

local petalCount = 0
local fallingPetals = world.decoration:FindFirstChild("FallingSakuraPetals")
if fallingPetals then
	petalCount = #fallingPetals:GetChildren()
end
T.assertEqual(petalCount, CONFIG.FallingPetalCount, "80 falling sakura petals")

local smallFlowerCount = 0
for _, child in ipairs(world.decoration:GetChildren()) do
	if child.Name == "SmallFlower" then
		smallFlowerCount = smallFlowerCount + 1
	end
end
T.assertEqual(smallFlowerCount, 35, "35 small island flowers")

-- ===== Six player areas + display houses =====

T.assertEqual(#world.playerAreas, CONFIG.HouseCount, "6 player areas returned")

local seenSpots = {}
for i, area in ipairs(world.playerAreas) do
	T.assertEqual(area.index, i, "player area " .. i .. " keeps its index")
	T.assertEqual(area.folder.Name, "PlayerArea_" .. i, "player area " .. i .. " folder is named correctly")
	T.assertEqual(area.house.Name, "Player" .. i .. "_DisplayBuilding", "player area " .. i .. " has its display building")

	local slots = area.house:FindFirstChild("SixDollDisplaySlots")
	T.assertTrue(slots ~= nil, "player area " .. i .. " has a doll display slots folder")
	if slots then
		T.assertEqual(#slots:GetChildren(), 6, "player area " .. i .. " has exactly 6 doll slots")
	end

	local spawnMarker = area.folder:FindFirstChild("PlayerSpawn_" .. i)
	T.assertTrue(spawnMarker ~= nil, "player area " .. i .. " has its spawn marker")

	-- Built via CFrame.lookAt on the HOUSE's position, so the mock's
	-- LookVector reflects real "facing the pond center" direction math --
	-- this is what actually catches the house-rotation bug this module
	-- was fixed for (the uploaded script computed a facing CFrame but
	-- never applied it). The spawn point is offset from the house, so the
	-- expected direction must be derived from the house's own position,
	-- not the spawn point's.
	local toCenter = { x = -area.houseCFrame.X, z = -area.houseCFrame.Z }
	local toCenterLen = math.sqrt(toCenter.x ^ 2 + toCenter.z ^ 2)
	T.assertNear(area.spawnCFrame.LookVector.X, toCenter.x / toCenterLen, 0.01, "player area " .. i .. " spawn faces the pond center (X)")
	T.assertNear(area.spawnCFrame.LookVector.Z, toCenter.z / toCenterLen, 0.01, "player area " .. i .. " spawn faces the pond center (Z)")

	local key = string.format("%.1f,%.1f", area.spawnCFrame.X, area.spawnCFrame.Z)
	T.assertTrue(not seenSpots[key], "player area " .. i .. " doesn't overlap another area's spawn")
	seenSpots[key] = true
end

-- ===== Island lock barrier =====

local parentFolder = mock.Instance.new("Folder")
local barrier = PondBuilder.buildIslandBarrier(parentFolder, CONFIG.IslandCenter, CONFIG.IslandRadius)
T.assertEqual(barrier.Parent, parentFolder, "barrier is parented where told")
T.assertEqual(barrier.CanCollide, true, "barrier starts locked (solid)")
T.assertEqual(barrier.Shape, mock.Enum.PartType.Cylinder, "barrier is a cylinder")

PondBuilder.setBarrierLocked(barrier, false)
T.assertEqual(barrier.CanCollide, false, "unlocking clears CanCollide")
T.assertEqual(barrier.Transparency, 1, "unlocked barrier is fully invisible")

PondBuilder.setBarrierLocked(barrier, true)
T.assertEqual(barrier.CanCollide, true, "re-locking sets CanCollide")
T.assertTrue(barrier.Transparency < 1, "locked barrier is visible (a shimmering shield, not fully invisible)")

-- ===== World attributes =====

T.assertEqual(world.world:GetAttribute("MaxPlayers"), 6, "MaxPlayers attribute set")
T.assertEqual(world.world:GetAttribute("MaxFrogs"), 20, "MaxFrogs attribute set")
T.assertEqual(world.world:GetAttribute("ActiveRoundSeconds"), 300, "ActiveRoundSeconds attribute set")
T.assertEqual(world.world:GetAttribute("ResetSeconds"), 10, "ResetSeconds attribute set")

-- ===== Lighting =====

T.assertEqual(mock.Lighting.ClockTime, 14, "ClockTime is set for the pond's daytime look")
local atmosphere = mock.Lighting:FindFirstChild("FrogPondAtmosphere")
T.assertTrue(atmosphere ~= nil, "an Atmosphere instance is set up")
if atmosphere then
	T.assertEqual(atmosphere.ClassName, "Atmosphere", "the atmosphere child is actually an Atmosphere instance")
end

T.report()
