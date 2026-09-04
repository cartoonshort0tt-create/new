-- Exercises PlayerProfile.lua against the mock DataStoreService, including
-- a real save/load round trip and the hydrate() schema-migration path.

local mock = require("tests.mock_roblox")
local T = require("tests.helpers")
T.suite("PlayerProfile")

local modulesFolder = mock.newInstance("Folder")
modulesFolder.Name = "Modules"
local carCatalogInstance = mock.newModuleScript(modulesFolder, "CarCatalog", "src/ServerScriptService/Modules/CarCatalog.lua")
local playerProfileInstance =
	mock.newModuleScript(modulesFolder, "PlayerProfile", "src/ServerScriptService/Modules/PlayerProfile.lua")

local CarCatalog = mock.load(carCatalogInstance)
local PlayerProfile = mock.load(playerProfileInstance)

local player = mock.newPlayer("Rex", 1001)

-- Fresh profile: correct defaults, starter car owned, everything else zeroed.
local profile = PlayerProfile.load(player)
T.assertEqual(profile.Cash, 0, "fresh profile starts with 0 Cash")
T.assertEqual(profile.Crystals, 0, "fresh profile starts with 0 Crystals")
T.assertEqual(profile.GarageSlots, 4, "fresh profile starts with 4 garage slots")
T.assertEqual(profile.ActiveCarId, CarCatalog.STARTER_CAR_ID, "fresh profile's active car is the starter")
T.assertTrue(profile.OwnedCars[CarCatalog.STARTER_CAR_ID] == true, "starter car is owned from the start")
for _, branch in ipairs(PlayerProfile.UPGRADE_BRANCHES) do
	T.assertEqual(profile.Upgrades[branch], 0, branch .. " upgrade level starts at 0")
end

T.assertEqual(PlayerProfile.get(player), profile, "get() returns the same profile that was loaded")

-- Mutate, save, and load a second time (simulating a rejoin) -- this is
-- the actual persistence path, exercised for real against the mock
-- DataStore, not just asserted on the in-memory table.
profile.Cash = 500
profile.Crystals = 12
profile.GarageSlots = 7
profile.OwnedCars["muscle_v8"] = true
profile.Upgrades.Engine = 3
profile.ActiveCarId = "muscle_v8"
PlayerProfile.save(player)
PlayerProfile.release(player)

T.assertNil(PlayerProfile.get(player), "release() clears the in-memory cache")

local reloaded = PlayerProfile.load(player)
T.assertEqual(reloaded.Cash, 500, "Cash survives a save/release/load round trip")
T.assertEqual(reloaded.Crystals, 12, "Crystals survives the round trip")
T.assertEqual(reloaded.GarageSlots, 7, "GarageSlots survives the round trip")
T.assertEqual(reloaded.ActiveCarId, "muscle_v8", "ActiveCarId survives the round trip")
T.assertTrue(reloaded.OwnedCars["muscle_v8"] == true, "newly-owned car survives the round trip")
T.assertTrue(reloaded.OwnedCars[CarCatalog.STARTER_CAR_ID] == true, "starter car ownership is preserved too")
T.assertEqual(reloaded.Upgrades.Engine, 3, "upgrade level survives the round trip")
T.assertEqual(reloaded.Upgrades.Tires, 0, "an untouched branch is still 0, not nil")

-- hydrate() must tolerate a saved record from before a field existed
-- (e.g. before GarageSlots was added) without erroring or wiping
-- everything else -- this is the actual forward-compatibility path a
-- live game depends on when new fields are added later.
local partialPlayer = mock.newPlayer("Old", 2002)
local partialStore = PlayerProfile
-- Simulate an old save written before GarageSlots/Upgrades existed by
-- writing directly into the same DataStore the module uses.
local DataStoreService = mock.game:GetService("DataStoreService")
local rawStore = DataStoreService:GetDataStore("Brikyard_PlayerProfiles_v1")
rawStore:SetAsync("Player_2002", { Cash = 250 })

local migrated = partialStore.load(partialPlayer)
T.assertEqual(migrated.Cash, 250, "old field (Cash) is preserved")
T.assertEqual(migrated.GarageSlots, 4, "missing field (GarageSlots) gets the current default")
T.assertTrue(migrated.OwnedCars[CarCatalog.STARTER_CAR_ID] == true, "starter car is granted even to a migrated profile")
for _, branch in ipairs(PlayerProfile.UPGRADE_BRANCHES) do
	T.assertEqual(migrated.Upgrades[branch], 0, "migrated profile gets a full zeroed Upgrades table for " .. branch)
end

T.report()
