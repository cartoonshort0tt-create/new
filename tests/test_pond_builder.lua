-- Exercises PondBuilder's actual geometry/attribute math against the mock
-- Roblox environment -- catches real math/API mistakes, not just syntax.

local mock = require("tests.mock_roblox")
local T = require("tests.helpers")
T.suite("PondBuilder")

local moduleInstance = mock.newModuleScript(nil, "PondBuilder", "src/ServerScriptService/Modules/PondBuilder.lua")
local PondBuilder = mock.load(moduleInstance)

-- ===== Pond =====

local pond = PondBuilder.buildPond(mock.Vector3.new(0, 0, 0))
T.assertEqual(pond.ClassName, "Model", "buildPond returns a Model")
T.assertEqual(pond:GetAttribute("LotusCount"), 10, "10 lotus pads")
T.assertEqual(pond:GetAttribute("WaterPlantCount"), 8, "8 water plants")
T.assertEqual(pond:GetAttribute("FishCount"), 6, "6 fish")

local lotusPadCount, lotusBloomCount, waterPlantCount, fishCount = 0, 0, 0, 0
local water = pond:FindFirstChild("PondWater")
for _, child in ipairs(pond:GetChildren()) do
	if child.Name == "LotusPad" then
		lotusPadCount = lotusPadCount + 1
	elseif child.Name == "LotusBloom" then
		lotusBloomCount = lotusBloomCount + 1
	elseif child.Name == "WaterPlant" then
		waterPlantCount = waterPlantCount + 1
	elseif child.Name == "Fish" then
		fishCount = fishCount + 1
	end
end
T.assertTrue(water ~= nil, "pond has a PondWater part")
if water then
	T.assertEqual(water.CanCollide, false, "water isn't solid -- a car^H^H^Hplayer swims through it, not on it")
	T.assertEqual(water.Shape, mock.Enum.PartType.Cylinder, "water is a disc (Cylinder shape)")
	T.assertNear(water.Size.Y, PondBuilder.POND_RADIUS * 2, 0.01, "water disc diameter matches POND_RADIUS")
end
T.assertEqual(lotusPadCount, 10, "10 LotusPad children")
T.assertEqual(lotusBloomCount, 10, "10 LotusBloom children")
T.assertEqual(waterPlantCount, 8, "8 WaterPlant children")
T.assertEqual(fishCount, 6, "6 Fish children")

-- Every pond decoration should sit within the pond's radius (sanity bound
-- -- nothing scattered off into empty space).
for _, child in ipairs(pond:GetChildren()) do
	if child.Name == "LotusPad" or child.Name == "WaterPlant" or child.Name == "Fish" then
		local distance = math.sqrt(child.CFrame.X ^ 2 + child.CFrame.Z ^ 2)
		T.assertTrue(distance < PondBuilder.POND_RADIUS, child.Name .. " sits within the pond radius")
	end
end

-- ===== Island =====

local island, spawnPoints = PondBuilder.buildIsland(mock.Vector3.new(0, 0, 0))
T.assertEqual(island.ClassName, "Model", "buildIsland returns a Model")
T.assertEqual(island:GetAttribute("TreeCount"), 4, "4 trees")
T.assertEqual(island:GetAttribute("ReedCount"), 12, "12 reeds (3 clumps of 4)")
T.assertEqual(island:GetAttribute("RockCount"), 6, "6 rocks")

T.assertEqual(#spawnPoints, PondBuilder.NUM_FROG_SPAWNS, "20 frog spawn points returned")

local seenOrders = {}
local coveredCount, openCount = 0, 0
for i, marker in ipairs(spawnPoints) do
	T.assertEqual(marker.Name, "FrogSpawnPoint", "spawn point " .. i .. " is named FrogSpawnPoint")
	T.assertEqual(marker.CanCollide, false, "spawn point marker is non-solid")
	local order = marker:GetAttribute("Order")
	T.assertTrue(order ~= nil, "spawn point has an Order attribute")
	seenOrders[order] = true

	local hasCover = marker:GetAttribute("HasCover")
	if hasCover then
		coveredCount = coveredCount + 1
	else
		openCount = openCount + 1
	end

	local distance = math.sqrt(marker.CFrame.X ^ 2 + marker.CFrame.Z ^ 2)
	T.assertTrue(distance < PondBuilder.ISLAND_RADIUS, "spawn point " .. i .. " sits within the island radius")
end
for i = 1, PondBuilder.NUM_FROG_SPAWNS do
	T.assertTrue(seenOrders[i] == true, "spawn point order " .. i .. " is present exactly once")
end
T.assertEqual(coveredCount, 10, "10 spawn points have cover (hide/reveal candidates)")
T.assertEqual(openCount, 10, "10 spawn points are in the open")

-- ===== Island lock barrier =====

local parentFolder = mock.Instance.new("Folder")
local barrier = PondBuilder.buildIslandBarrier(parentFolder, mock.Vector3.new(0, 0, 0))
T.assertEqual(barrier.Parent, parentFolder, "barrier is parented where told")
T.assertEqual(barrier.CanCollide, true, "barrier starts locked (solid)")
T.assertEqual(barrier.Shape, mock.Enum.PartType.Cylinder, "barrier is a cylinder")

PondBuilder.setBarrierLocked(barrier, false)
T.assertEqual(barrier.CanCollide, false, "unlocking clears CanCollide")
T.assertEqual(barrier.Transparency, 1, "unlocked barrier is fully invisible")

PondBuilder.setBarrierLocked(barrier, true)
T.assertEqual(barrier.CanCollide, true, "re-locking sets CanCollide")
T.assertTrue(barrier.Transparency < 1, "locked barrier is visible (a shimmering shield, not fully invisible)")

-- ===== Docks =====

local docksModel, docks = PondBuilder.buildDocks(mock.Vector3.new(0, 0, 0))
T.assertEqual(docksModel.ClassName, "Folder", "buildDocks returns a Folder")
T.assertEqual(#docks, PondBuilder.NUM_DOCKS, "6 docks returned")

for i, dock in ipairs(docks) do
	T.assertEqual(dock.platform.Parent, docksModel, "dock " .. i .. " platform is parented under the docks folder")
	local radius = math.sqrt(dock.spawnCFrame.X ^ 2 + dock.spawnCFrame.Z ^ 2)
	T.assertNear(radius, PondBuilder.DOCK_RING_RADIUS, 0.5, "dock " .. i .. " spawn sits on the dock ring")

	-- Built via CFrame.new(pos, center), so the mock's LookVector actually
	-- reflects real "facing the pond center" direction math.
	local toCenter = { x = -dock.spawnCFrame.X, z = -dock.spawnCFrame.Z }
	local toCenterLen = math.sqrt(toCenter.x ^ 2 + toCenter.z ^ 2)
	local expectedLookX, expectedLookZ = toCenter.x / toCenterLen, toCenter.z / toCenterLen
	T.assertNear(dock.spawnCFrame.LookVector.X, expectedLookX, 0.01, "dock " .. i .. " faces the pond center (X)")
	T.assertNear(dock.spawnCFrame.LookVector.Z, expectedLookZ, 0.01, "dock " .. i .. " faces the pond center (Z)")
end

-- No two docks should land on the same spot.
for i = 1, #docks do
	for j = i + 1, #docks do
		local dx = docks[i].spawnCFrame.X - docks[j].spawnCFrame.X
		local dz = docks[i].spawnCFrame.Z - docks[j].spawnCFrame.Z
		T.assertTrue(math.sqrt(dx ^ 2 + dz ^ 2) > 1, "dock " .. i .. " and dock " .. j .. " are in different spots")
	end
end

T.report()
