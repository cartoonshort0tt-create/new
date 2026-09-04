-- Brikyard server bootstrap.
--
-- Builds six personal practice plots plus the three shared competitive
-- tracks (Speed Oval, Technical Circuit, Stunt Yard), spawns each
-- player's active car at their assigned plot, validates lap
-- completion per-track server-side (checkpoints must be hit in order),
-- awards Cash, and handles car shop purchases/selection. Everything lives
-- in this one Script because plot assignment, car spawning, and the shop
-- all need to share the same in-memory player state -- splitting them into
-- separate Script instances would mean threading that state through a
-- ModuleScript for no real benefit at this size.
--
-- Known limitations, expected to be checked once this is first tested in
-- Studio rather than guessed here: steering direction and the speed/turn
-- constants may need a sign flip or retune. No wrong-way detection. If
-- more than 6 players join one server, players beyond the 6th share plot 1
-- instead of the server rejecting them (Studio's Max Players setting is
-- expected to be set to 6 in practice).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarBuilder = require(script.Parent.Modules.CarBuilder)
local TrackBuilder = require(script.Parent.Modules.TrackBuilder)
local PlayerProfile = require(script.Parent.Modules.PlayerProfile)
local CarCatalog = require(script.Parent.Modules.CarCatalog)
local UpgradeCatalog = require(script.Parent.Modules.UpgradeCatalog)
local CrateService = require(script.Parent.Modules.CrateService)

local MAX_FORWARD_SPEED = 90 -- studs/sec, before a car's SpeedMultiplier
local MAX_REVERSE_SPEED = 30 -- studs/sec, before a car's SpeedMultiplier
local MAX_TURN_RATE = 3 -- radians/sec at full speed, before TurnMultiplier
local PRACTICE_CASH_PER_LAP = 25
local COMPETITIVE_CRYSTALS_PER_LAP = 1 -- placeholder trickle; real Crystal packs need Dashboard-configured dev products
local GARAGE_SLOT_CAP = 30
local GARAGE_SLOT_START = 4 -- matches PlayerProfile's default GarageSlots
local GARAGE_SLOT_BASE_COST = 200 -- Cash; Robux instant-unlock needs a Dashboard-configured gamepass, not done here

-- The three track archetypes from the blueprint. Terrain differentiation
-- (real chicanes, jumps) is deferred until there's actual level art --
-- these are placeholder loops that currently differ only in footprint,
-- freeform Cash rate, and the race payout multiplier, same as the single
-- placeholder loop this replaced.
local COMPETITIVE_TRACK_DEFS = {
	{
		id = "speed_oval",
		displayName = "SpeedOval",
		center = Vector3.new(3000, 0, 0),
		halfSpanX = 40,
		halfLengthZ = 70,
		cashPerLap = 60,
		raceMultiplier = 4.5,
	},
	{
		id = "technical_circuit",
		displayName = "TechnicalCircuit",
		center = Vector3.new(3400, 0, 0),
		halfSpanX = 30,
		halfLengthZ = 40,
		cashPerLap = 55,
		raceMultiplier = 4.0,
	},
	{
		id = "stunt_yard",
		displayName = "StuntYard",
		center = Vector3.new(3800, 0, 0),
		halfSpanX = 35,
		halfLengthZ = 50,
		cashPerLap = 70,
		raceMultiplier = 6.0,
	},
}
local AUTOSAVE_INTERVAL_SECONDS = 300
local MAX_PLOTS = 6
local PLOT_SPACING = 300 -- studs between plot centers, wide enough to clear each loop's footprint

-- ===== Remotes =====

local lapUpdateEvent = Instance.new("RemoteEvent")
lapUpdateEvent.Name = "LapUpdate"
lapUpdateEvent.Parent = ReplicatedStorage

local getInitialStateFunction = Instance.new("RemoteFunction")
getInitialStateFunction.Name = "GetInitialState"
getInitialStateFunction.Parent = ReplicatedStorage

local getCarCatalogFunction = Instance.new("RemoteFunction")
getCarCatalogFunction.Name = "GetCarCatalog"
getCarCatalogFunction.Parent = ReplicatedStorage

local purchaseCarEvent = Instance.new("RemoteEvent")
purchaseCarEvent.Name = "PurchaseCar"
purchaseCarEvent.Parent = ReplicatedStorage

local selectCarEvent = Instance.new("RemoteEvent")
selectCarEvent.Name = "SelectCar"
selectCarEvent.Parent = ReplicatedStorage

local purchaseUpgradeEvent = Instance.new("RemoteEvent")
purchaseUpgradeEvent.Name = "PurchaseUpgrade"
purchaseUpgradeEvent.Parent = ReplicatedStorage

local openCrateEvent = Instance.new("RemoteEvent")
openCrateEvent.Name = "OpenCrate"
openCrateEvent.Parent = ReplicatedStorage

local getCrateInfoFunction = Instance.new("RemoteFunction")
getCrateInfoFunction.Name = "GetCrateInfo"
getCrateInfoFunction.Parent = ReplicatedStorage

local queueForRaceEvent = Instance.new("RemoteEvent")
queueForRaceEvent.Name = "QueueForRace"
queueForRaceEvent.Parent = ReplicatedStorage

local purchaseGarageSlotEvent = Instance.new("RemoteEvent")
purchaseGarageSlotEvent.Name = "PurchaseGarageSlot"
purchaseGarageSlotEvent.Parent = ReplicatedStorage

-- ===== Track building =====
-- tracks[trackId] = { cashPerLap, checkpointCount, isCompetitive, raceMultiplier }
-- (isCompetitive/raceMultiplier are only set for the three competitive tracks, below)
local tracks = {}
local plotSpawns = {} -- plotIndex -> spawnCFrame

local function registerTrack(trackId, checkpoints, cashPerLap)
	for _, checkpoint in ipairs(checkpoints) do
		checkpoint:SetAttribute("TrackId", trackId)
	end
	tracks[trackId] = { cashPerLap = cashPerLap, checkpointCount = #checkpoints }
	return checkpoints
end

local allCheckpoints = {}
local competitiveSpawns = {} -- trackId -> spawnCFrame
local competitiveTrackIds = {} -- trackId -> true, for quick membership checks

for _, def in ipairs(COMPETITIVE_TRACK_DEFS) do
	local model, checkpoints, spawnCFrame = TrackBuilder.buildLoop(def.center, def.halfSpanX, def.halfLengthZ)
	model.Name = def.displayName
	model.Parent = workspace

	registerTrack(def.id, checkpoints, def.cashPerLap)
	tracks[def.id].isCompetitive = true
	tracks[def.id].raceMultiplier = def.raceMultiplier

	competitiveSpawns[def.id] = spawnCFrame
	competitiveTrackIds[def.id] = true

	for _, cp in ipairs(checkpoints) do
		table.insert(allCheckpoints, cp)
	end
end

for i = 1, MAX_PLOTS do
	local center = Vector3.new((i - 1) * PLOT_SPACING, 0, 0)
	local plotModel, plotCheckpoints, spawnCFrame = TrackBuilder.buildLoop(center)
	plotModel.Name = "Plot" .. i .. "Practice"
	plotModel.Parent = workspace
	local trackId = "practice_" .. i
	registerTrack(trackId, plotCheckpoints, PRACTICE_CASH_PER_LAP)
	plotSpawns[i] = spawnCFrame
	for _, cp in ipairs(plotCheckpoints) do
		table.insert(allCheckpoints, cp)
	end
end

-- ===== Plot assignment =====

local freePlotSlots = {}
for i = 1, MAX_PLOTS do
	freePlotSlots[i] = true
end
local plotAssignment = {} -- Player -> plot index

local function assignPlot(player)
	for i = 1, MAX_PLOTS do
		if freePlotSlots[i] then
			freePlotSlots[i] = nil
			plotAssignment[player] = i
			return i
		end
	end
	return 1 -- fallback if the server somehow holds more than 6 players
end

local function releasePlot(player)
	local index = plotAssignment[player]
	if index then
		freePlotSlots[index] = true
		plotAssignment[player] = nil
	end
end

-- ===== Player + car lifecycle =====

-- player -> { car, plotIndex, trackProgress = { [trackId] = { nextCheckpoint, lapStartTime, lapsCompleted, bestLap } } }
local playerData = {}

-- Applies catalog base stats * upgrade-tree bonus to a player's current car.
-- Called on spawn and again immediately after any upgrade purchase so the
-- effect is live without needing a respawn.
local function applyEffectiveStats(player)
	local data = playerData[player]
	local profile = PlayerProfile.get(player)
	if not data or not data.car or not profile then
		return
	end

	local catalogEntry = CarCatalog.get(profile.ActiveCarId) or CarCatalog.get(CarCatalog.STARTER_CAR_ID)
	local bonus = UpgradeCatalog.totalBonus(profile.Upgrades)

	data.car:SetAttribute("SpeedMultiplier", catalogEntry.speedMultiplier * (1 + bonus))
	data.car:SetAttribute("TurnMultiplier", catalogEntry.turnMultiplier * (1 + bonus))
end

local function spawnCarForPlayer(player)
	local data = playerData[player]
	if not data then
		return
	end

	if data.car then
		data.car:Destroy()
	end

	local profile = PlayerProfile.get(player)
	local catalogEntry = (profile and CarCatalog.get(profile.ActiveCarId)) or CarCatalog.get(CarCatalog.STARTER_CAR_ID)

	local car = CarBuilder.new(player.Name .. "_Car", catalogEntry)
	car.Parent = workspace
	car:PivotTo(plotSpawns[data.plotIndex] or plotSpawns[1])
	data.car = car
	applyEffectiveStats(player)

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = car:FindFirstChild("DriveSeat")
	if humanoid and seat then
		seat:Sit(humanoid)
	end
end

Players.PlayerAdded:Connect(function(player)
	PlayerProfile.load(player)
	local plotIndex = assignPlot(player)
	playerData[player] = { car = nil, plotIndex = plotIndex, trackProgress = {} }

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
	releasePlot(player)
	PlayerProfile.release(player)
end)

-- ===== Matchmaking (same-server simplification) =====
--
-- The blueprint's production design is cross-server, Rating-band
-- matchmaking via TeleportService into dedicated race servers (see the
-- blueprint's Technical Architecture section). That needs a second Roblox
-- Place configured in the Creator Dashboard, which can't be set up from
-- this repo. This is a same-server placeholder that proves the mechanic:
-- players queue per track, a heat of up to 6 forms on that track, and
-- finish order decides a placement payout (scaled by that track's
-- raceMultiplier -- Stunt Yard pays more than Technical Circuit, etc).

local RACE_MIN_RACERS = 2
local RACE_MAX_RACERS = 6
local RACE_QUEUE_GRACE_SECONDS = 20
local RACE_TIMEOUT_SECONDS = 180
local RACE_BASE_REWARD = 200
local PLACEMENT_SHARE = { 1.00, 0.75, 0.55, 0.40, 0.28, 0.18 }

local raceQueue = {} -- trackId -> ordered list of Players waiting
for trackId in pairs(competitiveTrackIds) do
	raceQueue[trackId] = {}
end
local activeRaceByPlayer = {} -- Player -> session
local queueWaitStart = {} -- trackId -> os.clock() timestamp or nil

local function closeSession(session)
	session.closed = true
	for _, racer in ipairs(session.racers) do
		activeRaceByPlayer[racer] = nil
	end
end

local function recordFinish(player, session)
	if session.closed or session.finished[player] then
		return
	end
	session.finished[player] = true
	table.insert(session.finishOrder, player)

	local rank = #session.finishOrder
	local share = PLACEMENT_SHARE[rank] or PLACEMENT_SHARE[#PLACEMENT_SHARE]
	local reward = math.floor(RACE_BASE_REWARD * session.raceMultiplier * share)

	local profile = PlayerProfile.get(player)
	if profile then
		profile.Cash += reward
	end

	lapUpdateEvent:FireClient(player, {
		type = "raceFinish",
		trackId = session.trackId,
		rank = rank,
		reward = reward,
		cash = profile and profile.Cash or nil,
	})

	if #session.finishOrder >= #session.racers then
		closeSession(session)
	end
end

-- Called after RACE_TIMEOUT_SECONDS: anyone who hasn't finished is marked
-- DNF and still gets the lowest placement share, so queuing never risks
-- walking away with nothing.
local function finishRaceIfActive(session)
	if session.closed then
		return
	end
	for _, racer in ipairs(session.racers) do
		if not session.finished[racer] then
			session.finished[racer] = true
			table.insert(session.finishOrder, racer)
			local reward = math.floor(RACE_BASE_REWARD * session.raceMultiplier * PLACEMENT_SHARE[#PLACEMENT_SHARE])
			local profile = PlayerProfile.get(racer)
			if profile then
				profile.Cash += reward
			end
			lapUpdateEvent:FireClient(racer, {
				type = "raceFinish",
				trackId = session.trackId,
				dnf = true,
				reward = reward,
				cash = profile and profile.Cash or nil,
			})
		end
	end
	closeSession(session)
end

local function startRace(trackId, racers)
	local queue = raceQueue[trackId]
	for _, racer in ipairs(racers) do
		local idx = table.find(queue, racer)
		if idx then
			table.remove(queue, idx)
		end
	end

	local session = {
		trackId = trackId,
		raceMultiplier = tracks[trackId].raceMultiplier,
		racers = racers,
		finished = {},
		finishOrder = {},
		closed = false,
	}

	for i, racer in ipairs(racers) do
		activeRaceByPlayer[racer] = session

		local data = playerData[racer]
		if data then
			local previous = data.trackProgress[trackId]
			data.trackProgress[trackId] = {
				nextCheckpoint = 1,
				lapStartTime = os.clock(),
				lapsCompleted = previous and previous.lapsCompleted or 0,
				bestLap = previous and previous.bestLap or nil,
			}

			if data.car and data.car.PrimaryPart then
				local lateralOffset = (i - (#racers + 1) / 2) * 6
				data.car:PivotTo(competitiveSpawns[trackId] * CFrame.new(lateralOffset, 0, 0))
				data.car.PrimaryPart.AssemblyLinearVelocity = Vector3.new()
				data.car.PrimaryPart.AssemblyAngularVelocity = Vector3.new()
			end
		end

		lapUpdateEvent:FireClient(racer, { type = "raceStart", trackId = trackId, racerCount = #racers })
	end

	task.delay(RACE_TIMEOUT_SECONDS, function()
		finishRaceIfActive(session)
	end)
end

queueForRaceEvent.OnServerEvent:Connect(function(player, trackId)
	if type(trackId) ~= "string" or not competitiveTrackIds[trackId] then
		return
	end
	if activeRaceByPlayer[player] then
		return -- already mid-race, ignore
	end

	local queue = raceQueue[trackId]
	local idx = table.find(queue, player)
	if idx then
		table.remove(queue, idx)
		lapUpdateEvent:FireClient(player, { type = "queueLeft", trackId = trackId })
	else
		-- A player can only wait in one track's queue at a time.
		for otherTrackId, otherQueue in pairs(raceQueue) do
			if otherTrackId ~= trackId then
				local otherIdx = table.find(otherQueue, player)
				if otherIdx then
					table.remove(otherQueue, otherIdx)
				end
			end
		end
		table.insert(queue, player)
		lapUpdateEvent:FireClient(player, { type = "queueJoined", trackId = trackId, position = #queue })
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, queue in pairs(raceQueue) do
		local idx = table.find(queue, player)
		if idx then
			table.remove(queue, idx)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(2)

		for trackId, queue in pairs(raceQueue) do
			if #queue >= RACE_MAX_RACERS then
				local racers = {}
				for i = 1, RACE_MAX_RACERS do
					table.insert(racers, queue[i])
				end
				queueWaitStart[trackId] = nil
				startRace(trackId, racers)
			elseif #queue >= RACE_MIN_RACERS then
				queueWaitStart[trackId] = queueWaitStart[trackId] or os.clock()
				if os.clock() - queueWaitStart[trackId] >= RACE_QUEUE_GRACE_SECONDS then
					local racers = {}
					for _, racer in ipairs(queue) do
						table.insert(racers, racer)
					end
					queueWaitStart[trackId] = nil
					startRace(trackId, racers)
				end
			else
				queueWaitStart[trackId] = nil
			end
		end
	end
end)

-- ===== Lap / checkpoint handling =====

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

	local trackId = checkpoint:GetAttribute("TrackId")
	local track = trackId and tracks[trackId]
	local orderValue = checkpoint:FindFirstChild("Order")
	if not track or not orderValue then
		return
	end

	local progress = data.trackProgress[trackId]
	if not progress then
		progress = { nextCheckpoint = 1, lapStartTime = os.clock(), lapsCompleted = 0, bestLap = nil }
		data.trackProgress[trackId] = progress
	end

	if orderValue.Value ~= progress.nextCheckpoint then
		return -- wrong checkpoint, or already passed -- ignore, no penalty in this phase
	end

	progress.nextCheckpoint += 1

	if progress.nextCheckpoint > track.checkpointCount then
		progress.nextCheckpoint = 1
		local lapTime = os.clock() - progress.lapStartTime
		progress.lapStartTime = os.clock()
		progress.lapsCompleted += 1
		if not progress.bestLap or lapTime < progress.bestLap then
			progress.bestLap = lapTime
		end

		local session = track.isCompetitive and activeRaceByPlayer[player]
		if session and session.trackId == trackId and not session.closed and not session.finished[player] then
			-- Matched race: this lap is the finish line, not a per-lap reward.
			-- recordFinish sends its own "raceFinish" event with the payout.
			recordFinish(player, session)
			lapUpdateEvent:FireClient(player, {
				type = "lap",
				trackId = trackId,
				lapTime = lapTime,
				bestLap = progress.bestLap,
				laps = progress.lapsCompleted,
				cashEarned = 0,
				crystalsEarned = 0,
			})
		else
			local profile = PlayerProfile.get(player)
			local crystalsEarned = 0
			if profile then
				profile.Cash += track.cashPerLap
				if track.isCompetitive then
					crystalsEarned = COMPETITIVE_CRYSTALS_PER_LAP
					profile.Crystals += crystalsEarned
				end
			end

			lapUpdateEvent:FireClient(player, {
				type = "lap",
				trackId = trackId,
				lapTime = lapTime,
				bestLap = progress.bestLap,
				laps = progress.lapsCompleted,
				cashEarned = track.cashPerLap,
				cash = profile and profile.Cash or nil,
				crystalsEarned = crystalsEarned,
				crystals = profile and profile.Crystals or nil,
			})
		end
	else
		lapUpdateEvent:FireClient(player, {
			type = "checkpoint",
			trackId = trackId,
			checkpoint = orderValue.Value,
		})
	end
end

for _, checkpoint in ipairs(allCheckpoints) do
	checkpoint.Touched:Connect(function(hit)
		handleCheckpointTouched(checkpoint, hit)
	end)
end

-- ===== Shop =====

local function countOwnedCars(profile)
	local count = 0
	for _ in pairs(profile.OwnedCars) do
		count += 1
	end
	return count
end

local function hasGarageRoom(profile)
	return countOwnedCars(profile) < profile.GarageSlots
end

-- Cash cost to go from currentSlots to currentSlots + 1, doubling every 4
-- slots. Returns nil once currentSlots is already at GARAGE_SLOT_CAP.
local function costForNextGarageSlot(currentSlots)
	if currentSlots >= GARAGE_SLOT_CAP then
		return nil
	end
	local costTier = math.floor((currentSlots - GARAGE_SLOT_START) / 4)
	return GARAGE_SLOT_BASE_COST * (2 ^ costTier)
end

getCarCatalogFunction.OnServerInvoke = function()
	return CarCatalog.Cars
end

getInitialStateFunction.OnServerInvoke = function(player)
	local profile = PlayerProfile.get(player)
	local data = playerData[player]
	local progress = data and data.trackProgress["practice_" .. tostring(data.plotIndex or 1)]
	return {
		cash = profile and profile.Cash or 0,
		crystals = profile and profile.Crystals or 0,
		ownedCars = profile and profile.OwnedCars or {},
		activeCarId = profile and profile.ActiveCarId or CarCatalog.STARTER_CAR_ID,
		garageSlots = profile and profile.GarageSlots or 0,
		ownedCarCount = profile and countOwnedCars(profile) or 0,
		upgrades = profile and profile.Upgrades or {},
		laps = progress and progress.lapsCompleted or 0,
		bestLap = progress and progress.bestLap or nil,
	}
end

purchaseCarEvent.OnServerEvent:Connect(function(player, carId)
	local entry = type(carId) == "string" and CarCatalog.get(carId)
	local profile = PlayerProfile.get(player)
	if not entry or not profile then
		return
	end
	if profile.OwnedCars[carId] then
		return
	end
	if not hasGarageRoom(profile) then
		lapUpdateEvent:FireClient(player, { type = "purchaseFailed", reason = "garage_full", carId = carId })
		return
	end
	if profile.Cash < entry.price then
		lapUpdateEvent:FireClient(player, { type = "purchaseFailed", reason = "insufficient_cash", carId = carId })
		return
	end

	profile.Cash -= entry.price
	profile.OwnedCars[carId] = true
	lapUpdateEvent:FireClient(player, { type = "purchaseSuccess", carId = carId, cash = profile.Cash })
end)

purchaseGarageSlotEvent.OnServerEvent:Connect(function(player)
	local profile = PlayerProfile.get(player)
	if not profile then
		return
	end
	local cost = costForNextGarageSlot(profile.GarageSlots)
	if not cost then
		return -- already at cap
	end
	if profile.Cash < cost then
		lapUpdateEvent:FireClient(player, { type = "garageSlotFailed", reason = "insufficient_cash" })
		return
	end

	profile.Cash -= cost
	profile.GarageSlots += 1
	lapUpdateEvent:FireClient(player, {
		type = "garageSlotPurchased",
		garageSlots = profile.GarageSlots,
		cash = profile.Cash,
	})
end)

selectCarEvent.OnServerEvent:Connect(function(player, carId)
	local profile = PlayerProfile.get(player)
	if not profile or type(carId) ~= "string" or not profile.OwnedCars[carId] then
		return
	end
	profile.ActiveCarId = carId
	spawnCarForPlayer(player)
	lapUpdateEvent:FireClient(player, { type = "carSelected", carId = carId })
end)

purchaseUpgradeEvent.OnServerEvent:Connect(function(player, branch)
	local profile = PlayerProfile.get(player)
	if not profile or type(branch) ~= "string" or not UpgradeCatalog.isValidBranch(branch) then
		return
	end

	local currentLevel = profile.Upgrades[branch] or 0
	local cost = UpgradeCatalog.costForNextLevel(currentLevel)
	if not cost then
		return -- already at max level
	end
	if profile.Cash < cost then
		lapUpdateEvent:FireClient(player, { type = "upgradeFailed", reason = "insufficient_cash", branch = branch })
		return
	end

	profile.Cash -= cost
	profile.Upgrades[branch] = currentLevel + 1
	applyEffectiveStats(player)

	lapUpdateEvent:FireClient(player, {
		type = "upgradeSuccess",
		branch = branch,
		newLevel = profile.Upgrades[branch],
		cash = profile.Cash,
	})
end)

getCrateInfoFunction.OnServerInvoke = function()
	return {
		cost = CrateService.CRATE_COST_CRYSTALS,
		odds = CrateService.ODDS,
		pityEpicThreshold = CrateService.PITY_EPIC_THRESHOLD,
	}
end

openCrateEvent.OnServerEvent:Connect(function(player)
	local profile = PlayerProfile.get(player)
	if not profile then
		return
	end
	if profile.Crystals < CrateService.CRATE_COST_CRYSTALS then
		lapUpdateEvent:FireClient(player, { type = "crateFailed", reason = "insufficient_crystals" })
		return
	end

	profile.Crystals -= CrateService.CRATE_COST_CRYSTALS
	profile.PityPulls += 1

	local tier = CrateService.rollTier(profile.PitySinceEpicPlus)
	if CrateService.tierIsEpicPlus(tier) then
		profile.PitySinceEpicPlus = 0
	else
		profile.PitySinceEpicPlus += 1
	end

	local result = { type = "crateResult", tier = tier }

	if tier == "Common" then
		profile.Cash += CrateService.COMMON_CASH_REWARD
		result.reward = "cash"
		result.amount = CrateService.COMMON_CASH_REWARD
	else
		local pool = CrateService.poolForTier(CarCatalog.Cars, tier)
		local entry = pool[math.random(1, math.max(#pool, 1))]
		if entry and not profile.OwnedCars[entry.id] and hasGarageRoom(profile) then
			profile.OwnedCars[entry.id] = true
			result.reward = "car"
			result.carId = entry.id
			result.carName = entry.name
		else
			profile.Cash += CrateService.DUPLICATE_CASH_COMPENSATION
			result.reward = (entry and profile.OwnedCars[entry.id]) and "duplicate_cash" or "garage_full_cash"
			result.amount = CrateService.DUPLICATE_CASH_COMPENSATION
			result.carName = entry and entry.name or nil
		end
	end

	result.cash = profile.Cash
	result.crystals = profile.Crystals
	lapUpdateEvent:FireClient(player, result)
end)

-- ===== Drive loop =====

RunService.Heartbeat:Connect(function()
	for _, data in pairs(playerData) do
		local car = data.car
		if car and car.PrimaryPart then
			local seat = car:FindFirstChild("DriveSeat")
			if seat and seat.Occupant then
				local throttle = seat.Throttle
				local steer = seat.Steer
				local chassis = car.PrimaryPart
				local speedMultiplier = car:GetAttribute("SpeedMultiplier") or 1
				local turnMultiplier = car:GetAttribute("TurnMultiplier") or 1

				local forwardSpeed = throttle >= 0 and (throttle * MAX_FORWARD_SPEED * speedMultiplier)
					or (throttle * MAX_REVERSE_SPEED * speedMultiplier)
				local lookVector = chassis.CFrame.LookVector
				local currentVelocity = chassis.AssemblyLinearVelocity

				chassis.AssemblyLinearVelocity = Vector3.new(
					lookVector.X * forwardSpeed,
					currentVelocity.Y,
					lookVector.Z * forwardSpeed
				)

				local speedFactor = math.abs(forwardSpeed) / (MAX_FORWARD_SPEED * math.max(speedMultiplier, 0.01))
				local turnRate = steer * MAX_TURN_RATE * turnMultiplier * speedFactor
				if forwardSpeed < 0 then
					turnRate = -turnRate
				end
				chassis.AssemblyAngularVelocity = Vector3.new(0, -turnRate, 0)
			end
		end
	end
end)

-- ===== Autosave =====

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerProfile.save(player)
		end
	end
end)
