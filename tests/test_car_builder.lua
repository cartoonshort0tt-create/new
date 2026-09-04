-- Exercises CarBuilder.new against the mock Roblox environment.

local mock = require("tests.mock_roblox")
local T = require("tests.helpers")
T.suite("CarBuilder")

local moduleInstance = mock.newModuleScript(nil, "CarBuilder", "src/ServerScriptService/Modules/CarBuilder.lua")
local CarBuilder = mock.load(moduleInstance)

local catalogEntry = {
	name = "Test Car",
	color = mock.Color3.fromRGB(10, 20, 30),
	speedMultiplier = 1.15,
	turnMultiplier = 0.9,
}

local car = CarBuilder.new("TestCar", catalogEntry)

T.assertEqual(car.ClassName, "Model", "CarBuilder.new returns a Model")
T.assertTrue(car.PrimaryPart ~= nil, "car has a PrimaryPart set")
T.assertEqual(car.PrimaryPart.Name, "Chassis", "PrimaryPart is the chassis")
T.assertEqual(car.PrimaryPart.Anchored, false, "chassis is unanchored (it needs to be driveable)")

-- Attributes are how GameInit reads a spawned car's effective stats every
-- Heartbeat -- if these aren't set correctly, every car drives identically
-- regardless of catalog entry or upgrades.
T.assertEqual(car:GetAttribute("SpeedMultiplier"), 1.15, "SpeedMultiplier attribute matches catalog entry")
T.assertEqual(car:GetAttribute("TurnMultiplier"), 0.9, "TurnMultiplier attribute matches catalog entry")

-- Exactly one drive seat, and it must actually be part of the model (a
-- typo in seat.Parent would silently produce an undriveable car).
local seat = car:FindFirstChild("DriveSeat")
T.assertTrue(seat ~= nil, "car has a DriveSeat")
T.assertEqual(seat.ClassName, "VehicleSeat", "DriveSeat is a VehicleSeat")

-- Exactly 4 wheels.
local wheelCount = 0
for _, child in ipairs(car:GetChildren()) do
	if child.Name:match("^Wheel%d$") then
		wheelCount = wheelCount + 1
	end
end
T.assertEqual(wheelCount, 4, "car has exactly 4 wheels")

-- Missing catalog fields shouldn't error -- CarBuilder.new is called with
-- whatever CarCatalog.get() returns, which should never be nil in
-- practice, but a defensive default keeps a bad car ID from crashing the
-- server instead of just spawning a default-look car.
local ok, fallbackCar = pcall(CarBuilder.new, "Fallback", nil)
T.assertTrue(ok, "CarBuilder.new(name, nil) does not error")
if ok then
	T.assertEqual(fallbackCar:GetAttribute("SpeedMultiplier"), 1.0, "missing catalog entry falls back to 1.0x speed")
end

T.report()
