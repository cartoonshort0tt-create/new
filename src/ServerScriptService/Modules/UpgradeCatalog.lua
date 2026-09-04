-- Five upgrade branches, 8 levels each, Cash-only for now. Cost doubles
-- every two levels. Each branch contributes up to 4% to a combined
-- performance bonus, so maxing every branch caps out at +20% -- matching
-- the blueprint's stat-ceiling philosophy (rarity/tier gaps stay small
-- enough that skill and grind still decide races).
--
-- Not yet implemented: the upgrade-failure chance + Robux "Guarantee
-- Token" bypass described in the blueprint for levels 7-8. That needs a
-- real MarketplaceService developer product configured in the Creator
-- Dashboard first, which can't be done from this repo -- follow-up once
-- that product exists.

local UpgradeCatalog = {}

UpgradeCatalog.BRANCHES = { "Engine", "Tires", "Nitro", "Handling", "Chassis" }
UpgradeCatalog.MAX_LEVEL = 8

local MAX_BONUS_PER_BRANCH = 0.04 -- 5 branches * 4% = +20% at full upgrade
local BASE_COST = 50

-- Cost in Cash to go from currentLevel to currentLevel + 1. Returns nil
-- once a branch is already at MAX_LEVEL.
function UpgradeCatalog.costForNextLevel(currentLevel)
	if currentLevel >= UpgradeCatalog.MAX_LEVEL then
		return nil
	end
	local costTier = math.floor(currentLevel / 2) -- levels 0-1 -> tier 0, 2-3 -> tier 1, ...
	return BASE_COST * (2 ^ costTier)
end

function UpgradeCatalog.bonusForLevel(level)
	return (level / UpgradeCatalog.MAX_LEVEL) * MAX_BONUS_PER_BRANCH
end

-- upgrades: { Engine = n, Tires = n, ... } -> combined bonus, 0..0.20
function UpgradeCatalog.totalBonus(upgrades)
	local total = 0
	for _, branch in ipairs(UpgradeCatalog.BRANCHES) do
		total += UpgradeCatalog.bonusForLevel((upgrades and upgrades[branch]) or 0)
	end
	return total
end

function UpgradeCatalog.isValidBranch(branch)
	for _, name in ipairs(UpgradeCatalog.BRANCHES) do
		if name == branch then
			return true
		end
	end
	return false
end

return UpgradeCatalog
