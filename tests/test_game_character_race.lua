-- Regression test for a real bug found during an actual Studio playtest:
-- in Studio's solo Play mode (and sometimes live), a player's Character
-- can already exist by the time GameInit's PlayerAdded handler runs and
-- connects to CharacterAdded -- which then never fires for that already-
-- existing character, so the car never spawns. GameInit.server.lua now
-- checks for an already-existing Character directly; this locks that fix
-- in. The other tests never exercised this path because
-- mock.spawnCharacter always fires CharacterAdded strictly after
-- mock.joinPlayer, which is the ordering that was already working.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: character-already-exists race condition")

local game = harness.boot()

local player = mock.newPlayer("Early", 5)

-- Character exists BEFORE the player ever "joins" (before PlayerAdded
-- fires), unlike every other test's join order.
mock.newCharacterFor(player)
mock.joinPlayer(player) -- fires PlayerAdded; must notice player.Character is already set

local car
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Early_Car" then
		car = child
	end
end
T.assertTrue(car ~= nil, "car spawns even when Character already existed before PlayerAdded ran")

T.report()
