-- Minimal HUD for Phase 0: shows lap count, last lap time, and best lap time.
-- Driven entirely by the server's LapUpdate RemoteEvent -- the client never
-- computes or claims a lap time itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")

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
label.Size = UDim2.new(0, 320, 0, 96)
label.Position = UDim2.new(0, 20, 0, 20)
label.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
label.BackgroundTransparency = 0.15
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(238, 243, 255)
label.Font = Enum.Font.Code
label.TextSize = 20
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Text = "LAP 0\nLAST --\nBEST --"
label.Parent = screenGui

local lapsCompleted = 0
local lastLap = nil
local bestLap = nil

local function refresh()
	label.Text = string.format("LAP %d\nLAST %s\nBEST %s", lapsCompleted, formatSeconds(lastLap), formatSeconds(bestLap))
end

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "lap" then
		lapsCompleted = data.laps
		lastLap = data.lapTime
		bestLap = data.bestLap
		refresh()
	end
end)
