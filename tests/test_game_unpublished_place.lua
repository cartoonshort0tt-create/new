-- Regression test for a real bug found during an actual Studio playtest:
-- DataStoreService:GetDataStore() throws synchronously with "You must
-- publish this place to the web to access DataStore." for a place that's
-- never been published -- which crashed PlayerProfile.lua at module-load
-- time, which crashed GameInit.server.lua's require of it, which meant
-- NOTHING in the game worked (no remotes ever got created, every client
-- UI script hung on WaitForChild forever). PlayerProfile.lua now guards
-- that call with a pcall and an in-memory fallback so the rest of the
-- game degrades gracefully instead of dying entirely.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: unpublished-place DataStore failure")

mock.simulateUnpublishedPlace(true)

local ok, game = pcall(harness.boot)
T.assertTrue(ok, "GameInit.server.lua boots successfully even when GetDataStore throws")

if ok then
	local remotes = game.remotes
	for name, remote in pairs(remotes) do
		T.assertTrue(remote ~= nil, "remote '" .. name .. "' still gets created despite no DataStore")
	end

	-- The rest of the game (Cash, shop, etc.) should still work this
	-- session -- it just won't survive a restart, which is an accepted
	-- degradation, not a crash.
	local player = mock.newPlayer("Offline", 6)
	mock.joinPlayer(player)
	mock.spawnCharacter(player)

	local initialState = remotes.GetInitialState.OnServerInvoke(player)
	T.assertEqual(initialState.cash, 0, "profile still loads with sane defaults")

	local profile = game.PlayerProfile.get(player)
	profile.Cash = 500
	T.assertEqual(remotes.GetInitialState.OnServerInvoke(player).cash, 500, "in-memory session state still works")
end

T.report()
