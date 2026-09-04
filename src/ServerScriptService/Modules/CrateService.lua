-- Blueprint Crate gacha: Common/Rare/Epic/Legendary only (Ultimate and
-- Limited are Phase 3 scope). Odds are published here so the client UI can
-- render the same numbers players are actually getting -- see the
-- blueprint's compliance note on disclosed crate odds.
--
-- Pricing (50 Crystals/pull) and the Common-tier Cash consolation reward
-- are placeholder numbers pending real economy tuning, not final balance.

local CrateService = {}

CrateService.CRATE_COST_CRYSTALS = 50
CrateService.COMMON_CASH_REWARD = 30
CrateService.DUPLICATE_CASH_COMPENSATION = 150
CrateService.PITY_EPIC_THRESHOLD = 50

-- Order matters: this is also the cumulative-roll order.
CrateService.ODDS = {
	{ tier = "Common", chance = 0.55 },
	{ tier = "Rare", chance = 0.28 },
	{ tier = "Epic", chance = 0.13 },
	{ tier = "Legendary", chance = 0.04 },
}

local function tierIsEpicPlus(tier)
	return tier == "Epic" or tier == "Legendary"
end
CrateService.tierIsEpicPlus = tierIsEpicPlus

-- Rolls a tier, then applies hard pity: if the player has gone
-- PITY_EPIC_THRESHOLD pulls without an Epic+, this pull is forced to Epic.
function CrateService.rollTier(pitySinceEpicPlus)
	local roll = math.random()
	local cumulative = 0
	local tier = "Common"
	for _, entry in ipairs(CrateService.ODDS) do
		cumulative += entry.chance
		if roll <= cumulative then
			tier = entry.tier
			break
		end
	end

	if pitySinceEpicPlus and pitySinceEpicPlus + 1 >= CrateService.PITY_EPIC_THRESHOLD and not tierIsEpicPlus(tier) then
		tier = "Epic"
	end

	return tier
end

-- catalogCars: the CarCatalog.Cars table. Returns a list of crate-sourced
-- entries matching the given rarity.
function CrateService.poolForTier(catalogCars, tier)
	local pool = {}
	for _, entry in pairs(catalogCars) do
		if entry.source == "crate" and entry.rarity == tier then
			table.insert(pool, entry)
		end
	end
	return pool
end

return CrateService
