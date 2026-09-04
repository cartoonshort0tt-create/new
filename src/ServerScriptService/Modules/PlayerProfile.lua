-- Minimal DataStore-backed player profile: just Cash for now.
--
-- Known simplification: this has no cross-server session locking (unlike
-- e.g. ProfileService), so a player joining two servers at once could lose
-- data on save. Fine for a single-server prototype; revisit before this
-- ever runs on more than one server at a time.
--
-- DataStore calls will fail silently (falling back to a fresh 0-Cash
-- profile) in Studio unless "Enable Studio Access to API Services" is on
-- under Game Settings > Security.

local DataStoreService = game:GetService("DataStoreService")

local profileStore = DataStoreService:GetDataStore("Brikyard_PlayerProfiles_v1")

local DEFAULT_PROFILE = { Cash = 0 }

local PlayerProfile = {}
local cache = {} -- Player -> profile table

local function keyFor(player)
	return "Player_" .. player.UserId
end

function PlayerProfile.load(player)
	local data
	local ok, err = pcall(function()
		data = profileStore:GetAsync(keyFor(player))
	end)
	if not ok then
		warn("Brikyard: failed to load profile for " .. player.Name .. ": " .. tostring(err))
	end
	data = data or {}

	local profile = {
		Cash = data.Cash or DEFAULT_PROFILE.Cash,
	}
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

return PlayerProfile
