-- Brikyard - Phase 0 prototype.
-- Builds one track, gives every player a car on spawn, validates lap
-- completion server-side (checkpoints must be hit in order), and drives
-- each car from its VehicleSeat's Throttle/Steer input every physics step.
--
-- Known limitations, expected to be fixed once this is first tested in
-- Studio rather than guessed here: steering direction and the speed/turn
-- constants below may need a sign flip or retune to feel right.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarBuilder = require(script.Parent.Modules.CarBuilder)
local TrackBuilder = require(script.Parent.Modules.TrackBuilder)
local PlayerProfile = require(script.Parent.Modules.PlayerProfile)

local MAX_FORWARD_SPEED = 90 -- studs/sec
local MAX_REVERSE_SPEED = 30 -- studs/sec
local MAX_TURN_RATE = 3 -- radians/sec, scaled by current speed
local CASH_PER_LAP = 25
local AUTOSAVE_INTERVAL_SECONDS = 300

local lapUpdateEvent = Instance.new("RemoteEvent")
lapUpdateEvent.Name = "LapUpdate"
lapUpdateEvent.Parent = ReplicatedStorage

local getInitialStateFunction = Instance.new("RemoteFunction")
getInitialStateFunction.Name = "GetInitialState"
getInitialStateFunction.Parent = ReplicatedStorage

local trackModel, checkpoints, spawnCFrame = TrackBuilder.buildLoop()
trackModel.Parent = workspace

-- player -> { car, nextCheckpoint, lapStartTime, bestLap, lapsCompleted }
local playerData = {}

local function spawnCarForPlayer(player)
	local oldData = playerData[player]
	if oldData and oldData.car then
		oldData.car:Destroy()
	end

	local car = CarBuilder.new(player.Name .. "_Car")
	car.Parent = workspace
	car:PivotTo(spawnCFrame)

	playerData[player] = {
		car = car,
		nextCheckpoint = 1,
		lapStartTime = os.clock(),
		bestLap = nil,
		lapsCompleted = 0,
	}

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = car:FindFirstChild("DriveSeat")
	if humanoid and seat then
		seat:Sit(humanoid)
	end
end

Players.PlayerAdded:Connect(function(player)
	PlayerProfile.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(1) -- let the character finish loading before seating it
		spawnCarForPlayer(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local data = playerData[player]
	if data and data.car then
		data.car:Destroy()
	end
	playerData[player] = nil
	PlayerProfile.release(player)
end)

getInitialStateFunction.OnServerInvoke = function(player)
	local profile = PlayerProfile.get(player)
	local data = playerData[player]
	return {
		cash = profile and profile.Cash or 0,
		laps = data and data.lapsCompleted or 0,
		bestLap = data and data.bestLap or nil,
	}
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerProfile.save(player)
		end
	end
end)

local function findDriver(carModel)
	for player, data in pairs(playerData) do
		if data.car == carModel then
			return player, data
		end
	end
	return nil, nil
end

local function handleCheckpointTouched(checkpoint, hit)
	local carModel = hit:FindFirstAncestorOfClass("Model")
	if not carModel then
		return
	end

	local player, data = findDriver(carModel)
	if not player then
		return
	end

	local orderValue = checkpoint:FindFirstChild("Order")
	if not orderValue or orderValue.Value ~= data.nextCheckpoint then
		return -- wrong checkpoint, or already passed -- ignore, no penalty in Phase 0
	end

	data.nextCheckpoint += 1

	if data.nextCheckpoint > #checkpoints then
		data.nextCheckpoint = 1
		local lapTime = os.clock() - data.lapStartTime
		data.lapStartTime = os.clock()
		data.lapsCompleted += 1
		if not data.bestLap or lapTime < data.bestLap then
			data.bestLap = lapTime
		end

		local profile = PlayerProfile.get(player)
		if profile then
			profile.Cash += CASH_PER_LAP
		end

		lapUpdateEvent:FireClient(player, {
			type = "lap",
			lapTime = lapTime,
			bestLap = data.bestLap,
			laps = data.lapsCompleted,
			cashEarned = CASH_PER_LAP,
			cash = profile and profile.Cash or nil,
		})
	else
		lapUpdateEvent:FireClient(player, {
			type = "checkpoint",
			checkpoint = orderValue.Value,
		})
	end
end

for _, checkpoint in ipairs(checkpoints) do
	checkpoint.Touched:Connect(function(hit)
		handleCheckpointTouched(checkpoint, hit)
	end)
end

RunService.Heartbeat:Connect(function()
	for _, data in pairs(playerData) do
		local car = data.car
		if car and car.PrimaryPart then
			local seat = car:FindFirstChild("DriveSeat")
			if seat and seat.Occupant then
				local throttle = seat.Throttle
				local steer = seat.Steer
				local chassis = car.PrimaryPart

				local forwardSpeed = throttle >= 0 and (throttle * MAX_FORWARD_SPEED) or (throttle * MAX_REVERSE_SPEED)
				local lookVector = chassis.CFrame.LookVector
				local currentVelocity = chassis.AssemblyLinearVelocity

				chassis.AssemblyLinearVelocity = Vector3.new(
					lookVector.X * forwardSpeed,
					currentVelocity.Y,
					lookVector.Z * forwardSpeed
				)

				local speedFactor = math.abs(forwardSpeed) / MAX_FORWARD_SPEED
				local turnRate = steer * MAX_TURN_RATE * speedFactor
				if forwardSpeed < 0 then
					turnRate = -turnRate
				end
				chassis.AssemblyAngularVelocity = Vector3.new(0, -turnRate, 0)
			end
		end
	end
end)
