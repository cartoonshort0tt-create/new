-- Minimal HUD: Cash, Crystals, lap count, last lap, best lap. Driven
-- entirely by the server -- the client never computes or claims a lap
-- time or a currency amount itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local getInitialStateFunction = ReplicatedStorage:WaitForChild("GetInitialState")

local function formatSeconds(seconds)
	if not seconds then
		return "--"
	end
	return string.format("%.2fs", seconds)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LapHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "LapLabel"
label.Size = UDim2.new(0, 320, 0, 140)
label.Position = UDim2.new(0, 20, 0, 20)
label.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
label.BackgroundTransparency = 0.15
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(238, 243, 255)
label.Font = Enum.Font.Code
label.TextSize = 20
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Text = "CASH --\nCRYSTALS --\nLAP 0\nLAST --\nBEST --"
label.Parent = screenGui

local cash = 0
local crystals = 0
local lapsCompleted = 0
local lastLap = nil
local bestLap = nil

local function refresh()
	label.Text = string.format(
		"CASH %d\nCRYSTALS %d\nLAP %d\nLAST %s\nBEST %s",
		cash,
		crystals,
		lapsCompleted,
		formatSeconds(lastLap),
		formatSeconds(bestLap)
	)
end

local ok, initialState = pcall(function()
	return getInitialStateFunction:InvokeServer()
end)
if ok and initialState then
	cash = initialState.cash or 0
	crystals = initialState.crystals or 0
	lapsCompleted = initialState.laps or 0
	bestLap = initialState.bestLap
	refresh()
end

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "lap" then
		lapsCompleted = data.laps
		lastLap = data.lapTime
		bestLap = data.bestLap
		if data.cash then
			cash = data.cash
		end
		if data.crystals then
			crystals = data.crystals
		end
		refresh()
	elseif data.cash or data.crystals then
		-- purchaseSuccess / upgradeSuccess / crateResult all carry updated balances
		if data.cash then
			cash = data.cash
		end
		if data.crystals then
			crystals = data.crystals
		end
		refresh()
	end
end)
