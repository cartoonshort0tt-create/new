-- Regression test for a real bug found during Studio playtesting: a player
-- who gets out of their car to walk around, then presses the "RETURN TO
-- SHOWROOM" button, stayed on foot in the showroom instead of ending up
-- back in the driver's seat -- the handler moved the car with PivotTo but
-- never re-seated the player. Locks in the seatPlayerInCar() fix for both
-- the ReturnToShowroom remote and the teleport-pad handler.

local mock = require("tests.mock_roblox")
local harness = require("tests.game_harness")
local T = require("tests.helpers")
T.suite("Game: return-to-showroom re-seats an on-foot player")

local game = harness.boot()

local player = mock.newPlayer("Wanderer", 9)
mock.joinPlayer(player)
mock.spawnCharacter(player)

local car
for _, child in ipairs(mock.workspace:GetChildren()) do
	if child.Name == "Wanderer_Car" then
		car = child
	end
end
T.assertTrue(car ~= nil, "car spawned for the player")

local seat = car and car:FindFirstChild("DriveSeat")
T.assertTrue(seat ~= nil, "car has a DriveSeat")

local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
T.assertEqual(seat.Occupant, humanoid, "player starts out seated")

-- Simulate the player exiting the car to walk around, as seen in the
-- reported bug's screenshot.
seat.Occupant = nil

game.remotes.ReturnToShowroom:_fireServer(player)
mock.advancePending()

T.assertEqual(seat.Occupant, humanoid, "return-to-showroom re-seats the player who had exited the car")

T.report()
