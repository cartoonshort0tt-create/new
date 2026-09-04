-- Upgrade panel: one row per branch (Engine, Tires, Nitro, Handling,
-- Chassis), showing level out of 8 and the Cash cost for the next level.
-- The cost formula mirrors UpgradeCatalog.costForNextLevel purely for
-- display -- the server re-validates and is the only one that actually
-- spends Cash or grants a level.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local getInitialStateFunction = ReplicatedStorage:WaitForChild("GetInitialState")
local purchaseUpgradeEvent = ReplicatedStorage:WaitForChild("PurchaseUpgrade")

local BRANCHES = { "Engine", "Tires", "Nitro", "Handling", "Chassis" }
local MAX_LEVEL = 8
local BASE_COST = 50

local function costForNextLevel(currentLevel)
	if currentLevel >= MAX_LEVEL then
		return nil
	end
	local costTier = math.floor(currentLevel / 2)
	return BASE_COST * (2 ^ costTier)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpgradeUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "UpgradesToggle"
toggleButton.Size = UDim2.new(0, 140, 0, 40)
toggleButton.Position = UDim2.new(0, 170, 0, 150)
toggleButton.BackgroundColor3 = Color3.fromRGB(120, 70, 20)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 18
toggleButton.Text = "UPGRADES"
toggleButton.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "UpgradePanel"
panel.Size = UDim2.new(0, 360, 0, 300)
panel.Position = UDim2.new(0, 400, 0, 200)
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

local upgrades = {}
local rows = {} -- branch -> { nameLabel, actionButton }

local function refreshRow(branch)
	local row = rows[branch]
	if not row then
		return
	end
	local level = upgrades[branch] or 0
	row.nameLabel.Text = string.format("  %s  Lv %d/%d", branch, level, MAX_LEVEL)

	local cost = costForNextLevel(level)
	if cost then
		row.actionButton.Text = "+1  (" .. cost .. ")"
		row.actionButton.BackgroundColor3 = Color3.fromRGB(30, 90, 190)
		row.actionButton.Active = true
	else
		row.actionButton.Text = "MAXED"
		row.actionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		row.actionButton.Active = false
	end
end

local function buildRow(branch)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundColor3 = Color3.fromRGB(22, 36, 64)
	row.Parent = panel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
	nameLabel.Font = Enum.Font.Code
	nameLabel.TextSize = 15
	nameLabel.Parent = row

	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(0.35, -10, 0.7, 0)
	actionButton.Position = UDim2.new(0.65, 0, 0.15, 0)
	actionButton.Font = Enum.Font.SourceSansBold
	actionButton.TextSize = 14
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Parent = row

	actionButton.MouseButton1Click:Connect(function()
		purchaseUpgradeEvent:FireServer(branch)
	end)

	rows[branch] = { nameLabel = nameLabel, actionButton = actionButton }
	refreshRow(branch)
end

for _, branch in ipairs(BRANCHES) do
	buildRow(branch)
end

local ok, initialState = pcall(function()
	return getInitialStateFunction:InvokeServer()
end)
if ok and initialState and initialState.upgrades then
	upgrades = initialState.upgrades
	for _, branch in ipairs(BRANCHES) do
		refreshRow(branch)
	end
end

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "upgradeSuccess" then
		upgrades[data.branch] = data.newLevel
		refreshRow(data.branch)
	end
end)
