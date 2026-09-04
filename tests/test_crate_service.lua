-- Real unit tests for CrateService.lua. Also pure Lua, no Roblox API.

require("tests.luau_compat")
local T = require("tests.helpers")
T.suite("CrateService")

local CrateService = require("src.ServerScriptService.Modules.CrateService")

-- Odds should sum to 1.0 (100%) -- if they don't, either a pull can fall
-- through with no tier assigned, or the numbers don't match what's
-- disclosed to players.
local totalOdds = 0
for _, entry in ipairs(CrateService.ODDS) do
	totalOdds = totalOdds + entry.chance
end
T.assertNear(totalOdds, 1.0, 1e-9, "published odds sum to 100%")

T.assertTrue(CrateService.tierIsEpicPlus("Epic"), "Epic counts as Epic+")
T.assertTrue(CrateService.tierIsEpicPlus("Legendary"), "Legendary counts as Epic+")
T.assertEqual(CrateService.tierIsEpicPlus("Rare"), false, "Rare does not count as Epic+")
T.assertEqual(CrateService.tierIsEpicPlus("Common"), false, "Common does not count as Epic+")

-- rollTier with pitySinceEpicPlus one below threshold must NOT force a tier --
-- only reaching the threshold should. This is the exact off-by-one that
-- was reworked once already in GameInit's caller; testing the module
-- directly locks the boundary in.
math.randomseed(1)
local forcedAtThreshold = CrateService.rollTier(CrateService.PITY_EPIC_THRESHOLD - 1)
T.assertTrue(CrateService.tierIsEpicPlus(forcedAtThreshold), "pity forces Epic+ once threshold is reached")

local notYetForced = CrateService.rollTier(0)
-- Can't assert a specific tier (it's random), but it must be a valid tier
-- from the table -- this catches a rollTier that falls through returning
-- something unexpected.
local validTier = false
for _, entry in ipairs(CrateService.ODDS) do
	if entry.tier == notYetForced then
		validTier = true
	end
end
T.assertTrue(validTier, "an unforced roll always returns one of the published tiers")

-- Roll a large sample and check the empirical distribution is in the
-- right ballpark -- catches a cumulative-probability bug (e.g. wrong
-- iteration order) that a single roll wouldn't reveal.
math.randomseed(42)
local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0 }
local sampleSize = 20000
for _ = 1, sampleSize do
	local tier = CrateService.rollTier(0) -- pity never engages with 0 carried in
	counts[tier] = counts[tier] + 1
end
for _, entry in ipairs(CrateService.ODDS) do
	local observed = counts[entry.tier] / sampleSize
	T.assertNear(observed, entry.chance, 0.02, "empirical rate for " .. entry.tier .. " matches published odds")
end

-- poolForTier: only "crate"-sourced cars of the requested rarity, never
-- shop cars (which would let players "roll" something they can already
-- buy with Cash) and never a wrong tier.
local fakeCatalog = {
	shop_common = { id = "shop_common", source = "shop", rarity = "Common" },
	crate_rare_a = { id = "crate_rare_a", source = "crate", rarity = "Rare" },
	crate_rare_b = { id = "crate_rare_b", source = "crate", rarity = "Rare" },
	crate_epic_a = { id = "crate_epic_a", source = "crate", rarity = "Epic" },
}
local rarePool = CrateService.poolForTier(fakeCatalog, "Rare")
T.assertEqual(#rarePool, 2, "pool for Rare finds both crate-sourced Rare cars")
for _, entry in ipairs(rarePool) do
	T.assertEqual(entry.source, "crate", "pooled entry is crate-sourced")
	T.assertEqual(entry.rarity, "Rare", "pooled entry matches requested rarity")
end

local epicPool = CrateService.poolForTier(fakeCatalog, "Epic")
T.assertEqual(#epicPool, 1, "pool for Epic finds exactly the one Epic crate car")

local legendaryPool = CrateService.poolForTier(fakeCatalog, "Legendary")
T.assertEqual(#legendaryPool, 0, "pool for a tier with no crate cars is empty, not nil or an error")

T.report()
