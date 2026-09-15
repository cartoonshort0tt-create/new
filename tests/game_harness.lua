-- Boots GameInit.server.lua (and its ModuleScript dependencies) under the
-- mock Roblox environment, mirroring the Instance tree default.project.json
-- describes, and hands back the pieces a test needs to drive it like a
-- real client/session would.

local mock = require("tests.mock_roblox")

local M = {}

-- IMPORTANT: call this at most once per Lua process (i.e. once per test
-- file). mock_roblox's `workspace` and `ReplicatedStorage` are process-wide
-- singletons -- a second boot() would run GameInit.server.lua again into
-- the same workspace, producing duplicate-named instances, and
-- FindFirstChild would silently keep returning the first (stale) one.
-- Each test scenario gets its own file/process instead.
function M.boot()
	local serverScriptService = mock.newInstance("Folder")
	serverScriptService.Name = "ServerScriptService"

	local modulesFolder = mock.newInstance("Folder")
	modulesFolder.Name = "Modules"
	modulesFolder.Parent = serverScriptService

	local moduleNames = { "PondBuilder" }
	local moduleInstances = {}
	for _, name in ipairs(moduleNames) do
		moduleInstances[name] = mock.newModuleScript(modulesFolder, name, "src/ServerScriptService/Modules/" .. name .. ".lua")
	end

	mock.runServerScript(serverScriptService, "GameInit", "src/ServerScriptService/GameInit.server.lua")

	local remotes = {
		RoundState = mock.ReplicatedStorage:FindFirstChild("RoundState"),
	}

	return {
		serverScriptService = serverScriptService,
		remotes = remotes,
		PondBuilder = mock.load(moduleInstances.PondBuilder),
	}
end

return M
