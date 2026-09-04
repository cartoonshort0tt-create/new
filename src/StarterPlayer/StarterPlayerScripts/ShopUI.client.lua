-- Minimal car shop: a toggle button opens a panel listing every catalog
-- car with a Buy/Select/Equipped button. The server is the only source of
-- truth for prices and ownership -- this UI just reflects what it's told.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local getInitialStateFunction = ReplicatedStorage:WaitForChild("GetInitialState")
local getCarCatalogFunction = ReplicatedStorage:WaitForChild("GetCarCatalog")
local purchaseCarEvent = ReplicatedStorage:WaitForChild("PurchaseCar")
local selectCarEvent = ReplicatedStorage:WaitForChild("SelectCar")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "GarageToggle"
toggleButton.Size = UDim2.new(0, 140, 0, 40)
toggleButton.Position = UDim2.new(0, 20, 0, 150)
toggleButton.BackgroundColor3 = Color3.fromRGB(20, 110, 60)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 18
toggleButton.Text = "GARAGE"
toggleButton.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "GaragePanel"
panel.Size = UDim2.new(0, 360, 0, 320)
panel.Position = UDim2.new(0, 20, 0, 200)
panel.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = panel

toggleButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

local ownedCars = {}
local activeCarId = nil
local rows = {} -- carId -> { actionButton, price }

local function refreshRowStates()
	for carId, row in pairs(rows) do
		if ownedCars[carId] then
			if carId == activeCarId then
				row.actionButton.Text = "EQUIPPED"
				row.actionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			else
				row.actionButton.Text = "SELECT"
				row.actionButton.BackgroundColor3 = Color3.fromRGB(30, 90, 190)
			end
		else
			row.actionButton.Text = "BUY " .. row.price
			row.actionButton.BackgroundColor3 = Color3.fromRGB(190, 140, 20)
		end
	end
end

local function buildRow(carEntry)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(22, 36, 64)
	row.Parent = panel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
	nameLabel.Font = Enum.Font.SourceSans
	nameLabel.TextSize = 18
	nameLabel.Text = "  " .. carEntry.name
	nameLabel.Parent = row

	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(0.4, -10, 0.7, 0)
	actionButton.Position = UDim2.new(0.6, 0, 0.15, 0)
	actionButton.Font = Enum.Font.SourceSansBold
	actionButton.TextSize = 16
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Parent = row

	actionButton.MouseButton1Click:Connect(function()
		if ownedCars[carEntry.id] then
			selectCarEvent:FireServer(carEntry.id)
		else
			purchaseCarEvent:FireServer(carEntry.id)
		end
	end)

	rows[carEntry.id] = { actionButton = actionButton, price = carEntry.price }
end

local catalogOk, catalog = pcall(function()
	return getCarCatalogFunction:InvokeServer()
end)
if catalogOk and catalog then
	local entries = {}
	for _, entry in pairs(catalog) do
		if entry.source == "shop" then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		return a.price < b.price
	end)
	for _, entry in ipairs(entries) do
		buildRow(entry)
	end
end

local stateOk, initialState = pcall(function()
	return getInitialStateFunction:InvokeServer()
end)
if stateOk and initialState then
	ownedCars = initialState.ownedCars or {}
	activeCarId = initialState.activeCarId
	refreshRowStates()
end

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "purchaseSuccess" then
		ownedCars[data.carId] = true
		refreshRowStates()
	elseif data.type == "carSelected" then
		activeCarId = data.carId
		refreshRowStates()
	end
end)
