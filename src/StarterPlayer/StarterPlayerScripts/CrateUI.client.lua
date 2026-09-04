-- Blueprint Crate panel: shows the published odds table (Common through
-- Legendary), the current Crystal balance, and an Open button. Every
-- number here comes from the server via GetCrateInfo/GetInitialState --
-- nothing about odds or currency is decided or trusted client-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local getCrateInfoFunction = ReplicatedStorage:WaitForChild("GetCrateInfo")
local openCrateEvent = ReplicatedStorage:WaitForChild("OpenCrate")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrateUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "CratesToggle"
toggleButton.Size = UDim2.new(0, 140, 0, 40)
toggleButton.Position = UDim2.new(0, 320, 0, 150)
toggleButton.BackgroundColor3 = Color3.fromRGB(120, 30, 140)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 18
toggleButton.Text = "CRATES"
toggleButton.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "CratePanel"
panel.Size = UDim2.new(0, 320, 0, 280)
panel.Position = UDim2.new(0, 780, 0, 200)
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
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = panel

toggleButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 26)
titleLabel.BackgroundTransparency = 1
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 18
titleLabel.Text = "BLUEPRINT CRATE"
titleLabel.Parent = panel

local oddsLabel = Instance.new("TextLabel")
oddsLabel.Size = UDim2.new(1, 0, 0, 100)
oddsLabel.BackgroundTransparency = 1
oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
oddsLabel.TextYAlignment = Enum.TextYAlignment.Top
oddsLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
oddsLabel.Font = Enum.Font.Code
oddsLabel.TextSize = 14
oddsLabel.Text = "Loading odds..."
oddsLabel.Parent = panel

local pityLabel = Instance.new("TextLabel")
pityLabel.Size = UDim2.new(1, 0, 0, 18)
pityLabel.BackgroundTransparency = 1
pityLabel.TextXAlignment = Enum.TextXAlignment.Left
pityLabel.TextColor3 = Color3.fromRGB(160, 220, 190)
pityLabel.Font = Enum.Font.Code
pityLabel.TextSize = 13
pityLabel.Text = ""
pityLabel.Parent = panel

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.new(1, 0, 0, 40)
openButton.Font = Enum.Font.SourceSansBold
openButton.TextSize = 16
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.BackgroundColor3 = Color3.fromRGB(150, 40, 170)
openButton.Text = "OPEN CRATE"
openButton.Parent = panel

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, 0, 0, 60)
resultLabel.BackgroundTransparency = 1
resultLabel.TextWrapped = true
resultLabel.TextXAlignment = Enum.TextXAlignment.Left
resultLabel.TextColor3 = Color3.fromRGB(255, 225, 140)
resultLabel.Font = Enum.Font.SourceSansBold
resultLabel.TextSize = 15
resultLabel.Text = ""
resultLabel.Parent = panel

local crateCost = 50

openButton.MouseButton1Click:Connect(function()
	openCrateEvent:FireServer()
end)

local infoOk, crateInfo = pcall(function()
	return getCrateInfoFunction:InvokeServer()
end)
if infoOk and crateInfo then
	crateCost = crateInfo.cost or crateCost
	openButton.Text = string.format("OPEN CRATE (%d Crystals)", crateCost)

	local lines = {}
	for _, entry in ipairs(crateInfo.odds) do
		table.insert(lines, string.format("%-10s %.1f%%", entry.tier, entry.chance * 100))
	end
	oddsLabel.Text = table.concat(lines, "\n")

	if crateInfo.pityEpicThreshold then
		pityLabel.Text = string.format("Pity: guaranteed Epic+ within %d pulls", crateInfo.pityEpicThreshold)
	end
end

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "crateResult" then
		if data.reward == "car" then
			resultLabel.Text = string.format("%s pull -- got %s!", data.tier, data.carName or "a new car")
		elseif data.reward == "duplicate_cash" then
			resultLabel.Text = string.format("%s pull -- already owned, +%d Cash", data.tier, data.amount or 0)
		elseif data.reward == "garage_full_cash" then
			resultLabel.Text =
				string.format("%s pull -- garage full, +%d Cash instead", data.tier, data.amount or 0)
		else
			resultLabel.Text = string.format("Common pull -- +%d Cash", data.amount or 0)
		end
	elseif data.type == "crateFailed" and data.reason == "insufficient_crystals" then
		resultLabel.Text = "Not enough Crystals."
	end
end)
