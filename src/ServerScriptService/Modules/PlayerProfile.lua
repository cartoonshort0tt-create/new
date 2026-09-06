-- DataStore-backed player profile: currencies, owned cars, upgrades, and
-- gacha pity state.
--
-- Known simplification: this has no cross-server session locking (unlike
-- e.g. ProfileService), so a player joining two servers at once could lose
-- data on save. Fine for a single-server prototype; revisit before this
-- ever runs on more than one server at a time.
--
-- DataStore reads/writes will fail (falling back to a fresh default
-- profile) in Studio unless "Enable Studio Access to API Services" is on
-- under Game Settings > Security. GetDataStore itself can also throw --
-- e.g. "You must publish this place to the web to access DataStore" for a
-- place that's never been published -- which would otherwise crash this
-- whole module (and everything that requires it) before a single player
-- ever joins. Guarded below with an in-memory fallback so the rest of the
-- game still works that session; Cash/Crystals just won't persist.

local DataStoreService = game:GetService("DataStoreService")

local CarCatalog = require(script.Parent.CarCatalog)

local profileStore
do
	local ok, storeOrError = pcall(function()
		return DataStoreService:GetDataStore("Brikyard_PlayerProfiles_v1")
	end)
	if ok then
		profileStore = storeOrError
	else
		warn(
			"Brikyard: DataStore unavailable ("
				.. tostring(storeOrError)
				.. ") -- Cash/Crystals will not persist this session. "
				.. "Publish this place to Roblox and enable Studio API access to fix."
		)
		local memory = {}
		profileStore = {
			GetAsync = function(_, key)
				return memory[key]
			end,
			SetAsync = function(_, key, value)
				memory[key] = value
			end,
		}
	end
end

local UPGRADE_BRANCHES = { "Engine", "Tires", "Nitro", "Handling", "Chassis" }

local function freshProfile()
	local ownedCars = {}
	ownedCars[CarCatalog.STARTER_CAR_ID] = true

	local upgrades = {}
	for _, branch in ipairs(UPGRADE_BRANCHES) do
		upgrades[branch] = 0
	end

	return {
		Cash = 0,
		Crystals = 0,
		OwnedCars = ownedCars,
		ActiveCarId = CarCatalog.STARTER_CAR_ID,
		GarageSlots = 4,
		Upgrades = upgrades,
		PityPulls = 0,
		PitySinceEpicPlus = 0,
		BlueprintShards = 0,
	}
end

local PlayerProfile = {}
local cache = {} -- Player -> profile table

local function keyFor(player)
	return "Player_" .. player.UserId
end

-- Merges saved data over a fresh default profile so new fields introduced
-- after a player's first save still get sane defaults.
local function hydrate(saved)
	local profile = freshProfile()
	if type(saved) ~= "table" then
		return profile
	end

	profile.Cash = saved.Cash or profile.Cash
	profile.Crystals = saved.Crystals or profile.Crystals
	profile.ActiveCarId = saved.ActiveCarId or profile.ActiveCarId
	profile.GarageSlots = saved.GarageSlots or profile.GarageSlots
	profile.PityPulls = saved.PityPulls or profile.PityPulls
	profile.PitySinceEpicPlus = saved.PitySinceEpicPlus or profile.PitySinceEpicPlus
	profile.BlueprintShards = saved.BlueprintShards or profile.BlueprintShards

	if type(saved.OwnedCars) == "table" then
		for carId, owned in pairs(saved.OwnedCars) do
			if owned then
				profile.OwnedCars[carId] = true
			end
		end
	end

	if type(saved.Upgrades) == "table" then
		for _, branch in ipairs(UPGRADE_BRANCHES) do
			if type(saved.Upgrades[branch]) == "number" then
				profile.Upgrades[branch] = saved.Upgrades[branch]
			end
		end
	end

	return profile
end

function PlayerProfile.load(player)
	local data
	local ok, err = pcall(function()
		data = profileStore:GetAsync(keyFor(player))
	end)
	if not ok then
		warn("Brikyard: failed to load profile for " .. player.Name .. ": " .. tostring(err))
	end

	local profile = hydrate(data)
	cache[player] = profile
	return profile
end

function PlayerProfile.get(player)
	return cache[player]
end

function PlayerProfile.save(player)
	local profile = cache[player]
	if not profile then
		return
	end
	local ok, err = pcall(function()
		profileStore:SetAsync(keyFor(player), profile)
	end)
	if not ok then
		warn("Brikyard: failed to save profile for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerProfile.release(player)
	PlayerProfile.save(player)
	cache[player] = nil
end

PlayerProfile.UPGRADE_BRANCHES = UPGRADE_BRANCHES

return PlayerProfile
