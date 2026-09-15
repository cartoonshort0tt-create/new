-- Bootstraps the shared pond arena: builds the pond + island, seats up to
-- 6 players at their own dock, and runs the round timer that opens the
-- island for 5 minutes then locks it for a 10-second reset gap, forever.
-- Frog spawning, catching, kissing, dolls, and the economy are later
-- phases -- see README.md's phase list. This is deliberately just the
-- arena and the round clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PondBuilder = require(script.Parent.Modules.PondBuilder)

local POND_CENTER = Vector3.new(0, 0, 0)

local pond = PondBuilder.buildPond(POND_CENTER)
pond.Parent = workspace

local island, frogSpawnPoints = PondBuilder.buildIsland(POND_CENTER)
island.Parent = workspace

local barrier = PondBuilder.buildIslandBarrier(workspace, POND_CENTER)

local docksModel, docks = PondBuilder.buildDocks(POND_CENTER)
docksModel.Parent = workspace

local roundStateEvent = Instance.new("RemoteEvent")
roundStateEvent.Name = "RoundState"
roundStateEvent.Parent = ReplicatedStorage

-- ===== Dock assignment: one of the 6 docks per player, freed on leave =====

local freeDockIndices = {}
for i = 1, PondBuilder.NUM_DOCKS do
	table.insert(freeDockIndices, i)
end

local playerDockIndex = {} -- Player -> dock index

local function assignDock(player)
	if #freeDockIndices == 0 then
		return nil
	end
	local index = table.remove(freeDockIndices, 1)
	playerDockIndex[player] = index
	return index
end

local function releaseDock(player)
	local index = playerDockIndex[player]
	if index then
		table.insert(freeDockIndices, index)
		playerDockIndex[player] = nil
	end
end

local function spawnPlayerAtDock(player)
	local index = playerDockIndex[player]
	if not index then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(docks[index].spawnCFrame)
end

Players.PlayerAdded:Connect(function(player)
	assignDock(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		spawnPlayerAtDock(player)
	end)

	-- A player's Character can already exist by the time PlayerAdded runs
	-- (Studio solo Play mode) -- CharacterAdded never fires again for an
	-- already-existing character, so spawn directly in that case too.
	if player.Character then
		task.wait(0.5)
		spawnPlayerAtDock(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	releaseDock(player)
end)

-- ===== Round timer: 5 minutes open, then a 10-second locked reset =====

local function recallAllPlayersToDocks()
	for _, player in ipairs(Players:GetPlayers()) do
		spawnPlayerAtDock(player)
	end
end

task.spawn(function()
	while true do
		PondBuilder.setBarrierLocked(barrier, false)
		roundStateEvent:FireAllClients({ type = "roundOpen" })
		task.wait(PondBuilder.ROUND_ACTIVE_SECONDS)

		recallAllPlayersToDocks()
		PondBuilder.setBarrierLocked(barrier, true)
		roundStateEvent:FireAllClients({ type = "roundLocked" })
		task.wait(PondBuilder.ROUND_LOCK_SECONDS)
	end
end)
