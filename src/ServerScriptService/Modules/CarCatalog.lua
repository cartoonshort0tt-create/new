-- The full car list: three Cash-shop Commons (Phase 1) plus one
-- crate-exclusive car each for Rare/Epic/Legendary (Phase 2). Ultimate and
-- Limited tiers are Phase 3 scope per the roadmap, not here yet.
--
-- `source` controls where a car can be obtained: "shop" cars are Cash-
-- purchasable and listed in the Garage panel; "crate" cars are only ever
-- granted by CrateService and never shown there.

local CarCatalog = {}

CarCatalog.STARTER_CAR_ID = "starter_hatch"

CarCatalog.Cars = {
	starter_hatch = {
		id = "starter_hatch",
		name = "Stud Hatchback",
		price = 0,
		source = "shop",
		rarity = "Common",
		color = Color3.fromRGB(200, 45, 45),
		speedMultiplier = 1.0,
		turnMultiplier = 1.0,
	},
	muscle_v8 = {
		id = "muscle_v8",
		name = "Brik Muscle V8",
		price = 300,
		source = "shop",
		rarity = "Common",
		color = Color3.fromRGB(35, 60, 200),
		speedMultiplier = 1.15,
		turnMultiplier = 0.9,
	},
	rally_gt = {
		id = "rally_gt",
		name = "Rally GT",
		price = 650,
		source = "shop",
		rarity = "Common",
		color = Color3.fromRGB(230, 180, 20),
		speedMultiplier = 1.05,
		turnMultiplier = 1.25,
	},
	rare_kei = {
		id = "rare_kei",
		name = "Kei Dash",
		source = "crate",
		rarity = "Rare",
		color = Color3.fromRGB(60, 200, 160),
		speedMultiplier = 1.03,
		turnMultiplier = 1.10,
	},
	epic_offroad = {
		id = "epic_offroad",
		name = "Ridge Crawler",
		source = "crate",
		rarity = "Epic",
		color = Color3.fromRGB(150, 90, 230),
		speedMultiplier = 1.08,
		turnMultiplier = 1.02,
	},
	legendary_hyper = {
		id = "legendary_hyper",
		name = "Vertex Hyper",
		source = "crate",
		rarity = "Legendary",
		color = Color3.fromRGB(240, 170, 30),
		speedMultiplier = 1.18,
		turnMultiplier = 1.05,
	},
}

function CarCatalog.get(carId)
	return CarCatalog.Cars[carId]
end

return CarCatalog
