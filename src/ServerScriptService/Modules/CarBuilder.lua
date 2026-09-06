-- Builds a brick-built car from a CarCatalog entry: a chassis, a glass
-- cabin, four wheels, decorative roof studs (the brick-theme signature),
-- and a VehicleSeat. Speed/turn multipliers are stored as attributes on
-- the model so the drive loop can read them without needing the catalog.

local CarBuilder = {}

local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)
local CABIN_COLOR = Color3.fromRGB(225, 232, 245)

local function weld(part0, part1)
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = part1
end

-- catalogEntry: { name, color, speedMultiplier, turnMultiplier, ... }
function CarBuilder.new(name, catalogEntry)
	catalogEntry = catalogEntry or {}
	local bodyColor = catalogEntry.color or Color3.fromRGB(200, 45, 45)

	local model = Instance.new("Model")
	model.Name = name or "BrikCar"
	model:SetAttribute("SpeedMultiplier", catalogEntry.speedMultiplier or 1.0)
	model:SetAttribute("TurnMultiplier", catalogEntry.turnMultiplier or 1.0)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 1, 8)
	chassis.Color = bodyColor
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(3, 1.2, 4)
	cabin.Color = CABIN_COLOR
	cabin.Material = Enum.Material.Glass
	cabin.Transparency = 0.35
	cabin.CFrame = chassis.CFrame * CFrame.new(0, 1.1, -0.5)
	cabin.Parent = model
	weld(chassis, cabin)

	-- Roof studs: cosmetic only, signals the brick-toy theme.
	for i = -1, 1, 2 do
		for j = -3, 3, 2 do
			local stud = Instance.new("Part")
			stud.Name = "Stud"
			stud.Shape = Enum.PartType.Cylinder
			stud.Size = Vector3.new(0.4, 0.6, 0.6)
			stud.CFrame = chassis.CFrame * CFrame.new(i * 1.3, 0.7, j) * CFrame.Angles(0, 0, math.rad(90))
			stud.Color = bodyColor
			stud.Material = chassis.Material
			stud.CanCollide = false
			stud.Parent = model
			weld(chassis, stud)
		end
	end

	local wheelOffsets = {
		Vector3.new(2.2, -0.5, 2.7),
		Vector3.new(-2.2, -0.5, 2.7),
		Vector3.new(2.2, -0.5, -2.7),
		Vector3.new(-2.2, -0.5, -2.7),
	}
	for i, offset in ipairs(wheelOffsets) do
		local wheelPart = Instance.new("Part")
		wheelPart.Name = "Wheel" .. i
		wheelPart.Shape = Enum.PartType.Cylinder
		wheelPart.Size = Vector3.new(1, 2, 2)
		-- No extra rotation: a Cylinder's round faces already sit
		-- perpendicular to its local X-axis, which is exactly the axis
		-- these wheels need since they're offset sideways (+/-X) from the
		-- chassis center. Rotating here (as an earlier version did) moves
		-- that axis onto Y instead, making the wheel lie flat like a coin.
		wheelPart.CFrame = chassis.CFrame * CFrame.new(offset)
		wheelPart.Color = WHEEL_COLOR
		wheelPart.Material = Enum.Material.SmoothPlastic
		wheelPart.Parent = model
		weld(chassis, wheelPart)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2, 1, 3)
	seat.CFrame = chassis.CFrame * CFrame.new(0, 1, 0)
	seat.Parent = model
	weld(chassis, seat)

	model.PrimaryPart = chassis
	chassis.Anchored = false

	return model
end

return CarBuilder
