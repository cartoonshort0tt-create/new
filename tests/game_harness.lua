-- Boots GameInit.server.lua (and its ModuleScript dependencies) under the
-- mock Roblox environment, mirroring the Instance tree default.project.json
-- describes, and hands back the RemoteEvents/RemoteFunctions it creates so
-- a test can drive it like a real client would.

local mock = require("tests.mock_roblox")

local M = {}

-- IMPORTANT: call this at most once per Lua process (i.e. once per test
-- file). mock_roblox's `workspace` and `ReplicatedStorage` are process-wide
-- singletons -- a second boot() would run GameInit.server.lua again into
-- the same workspace, producing duplicate-named tracks and remotes, and
-- FindFirstChild would silently keep returning the first (stale) one.
-- Each test scenario gets its own file/process instead.
function M.boot()
	local serverScriptService = mock.newInstance("Folder")
	serverScriptService.Name = "ServerScriptService"

	local modulesFolder = mock.newInstance("Folder")
	modulesFolder.Name = "Modules"
	modulesFolder.Parent = serverScriptService

	local moduleNames = { "CarBuilder", "TrackBuilder", "PlayerProfile", "CarCatalog", "UpgradeCatalog", "CrateService" }
	local moduleInstances = {}
	for _, name in ipairs(moduleNames) do
		moduleInstances[name] = mock.newModuleScript(modulesFolder, name, "src/ServerScriptService/Modules/" .. name .. ".lua")
	end

	mock.runServerScript(serverScriptService, "GameInit", "src/ServerScriptService/GameInit.server.lua")

	-- Loading these again returns the exact same (module-cached) table
	-- GameInit itself is using -- lets a test set up preconditions (e.g.
	-- granting Crystals directly) without simulating hundreds of laps,
	-- without that being a second, disconnected copy of the module.
	local playerProfile = mock.load(moduleInstances.PlayerProfile)
	local carCatalog = mock.load(moduleInstances.CarCatalog)

	local remotes = {}
	local remoteNames = {
		"LapUpdate",
		"GetInitialState",
		"GetCarCatalog",
		"PurchaseCar",
		"SelectCar",
		"PurchaseUpgrade",
		"OpenCrate",
		"GetCrateInfo",
		"QueueForRace",
		"PurchaseGarageSlot",
	}
	for _, name in ipairs(remoteNames) do
		remotes[name] = mock.ReplicatedStorage:FindFirstChild(name)
	end

	return {
		serverScriptService = serverScriptService,
		remotes = remotes,
		PlayerProfile = playerProfile,
		CarCatalog = carCatalog,
	}
end

-- The mock RemoteEvent already records every FireClient call in
-- self._clientEvents as {player, data}. This filters that log to one
-- player and clears it, so consecutive test steps don't see stale events.
function M.drainEventsFor(remoteEvent, player)
	local all = remoteEvent._clientEvents or {}
	remoteEvent._clientEvents = {}
	local mine, others = {}, {}
	for _, entry in ipairs(all) do
		if entry.player == player then
			table.insert(mine, entry.data)
		else
			table.insert(others, entry)
		end
	end
	remoteEvent._clientEvents = others
	return mine
end

-- Drives a player's car through a track's 4 checkpoints in order,
-- completing exactly one lap. `checkpointsByOrder` maps 1..4 -> the
-- checkpoint Instance for the track the player's car currently occupies.
function M.driveOneLap(checkpointsByOrder, car)
	local hitPart = car:FindFirstChild("Chassis")
	for order = 1, 4 do
		checkpointsByOrder[order].Touched:Fire(hitPart)
	end
end

return M
