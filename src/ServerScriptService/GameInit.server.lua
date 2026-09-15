-- Bootstraps the shared pond arena: builds the world (pond, island,
-- decoration, 6 player display houses), seats up to 6 players at their
-- own house's spawn point, and runs the round timer that opens the
-- island for 5 minutes then locks it for a 10-second reset gap, forever.
-- Frog spawning, catching, kissing, dolls, and the economy are later
-- phases -- see README.md's phase list. This is deliberately just the
-- arena and the round clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PondBuilder = require(script.Parent.Modules.PondBuilder)

local world = PondBuilder.build()

local barrier = PondBuilder.buildIslandBarrier(world.island, PondBuilder.CONFIG.IslandCenter, PondBuilder.CONFIG.IslandRadius)

local roundStateEvent = Instance.new("RemoteEvent")
roundStateEvent.Name = "RoundState"
roundStateEvent.Parent = ReplicatedStorage

-- ===== Player area assignment: one of the 6 houses per player, freed on leave =====

local freeAreaIndices = {}
for i = 1, #world.playerAreas do
	table.insert(freeAreaIndices, i)
end

local playerAreaIndex = {} -- Player -> index into world.playerAreas

local function assignArea(player)
	if #freeAreaIndices == 0 then
		return nil
	end
	local index = table.remove(freeAreaIndices, 1)
	playerAreaIndex[player] = index
	return index
end

local function releaseArea(player)
	local index = playerAreaIndex[player]
	if index then
		table.insert(freeAreaIndices, index)
		playerAreaIndex[player] = nil
	end
end

local function spawnPlayerAtArea(player)
	local index = playerAreaIndex[player]
	if not index then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(world.playerAreas[index].spawnCFrame)
end

Players.PlayerAdded:Connect(function(player)
	assignArea(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		spawnPlayerAtArea(player)
	end)

	-- A player's Character can already exist by the time PlayerAdded runs
	-- (Studio solo Play mode) -- CharacterAdded never fires again for an
	-- already-existing character, so spawn directly in that case too.
	if player.Character then
		task.wait(0.5)
		spawnPlayerAtArea(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	releaseArea(player)
end)

-- ===== Round timer: 5 minutes open, then a 10-second locked reset =====

local function recallAllPlayersToTheirArea()
	for _, player in ipairs(Players:GetPlayers()) do
		spawnPlayerAtArea(player)
	end
end

task.spawn(function()
	while true do
		PondBuilder.setBarrierLocked(barrier, false)
		roundStateEvent:FireAllClients({ type = "roundOpen" })
		task.wait(PondBuilder.CONFIG.ActiveRoundSeconds)

		recallAllPlayersToTheirArea()
		PondBuilder.setBarrierLocked(barrier, true)
		roundStateEvent:FireAllClients({ type = "roundLocked" })
		task.wait(PondBuilder.CONFIG.ResetSeconds)
	end
end)
