-- Race queue panel: one button to join/leave the competitive-track queue,
-- and status text for queue position, race start, and finish placement.
-- The server decides everything here -- when a heat starts, who's in it,
-- and the payout; this UI only reflects what it's told.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local queueForRaceEvent = ReplicatedStorage:WaitForChild("QueueForRace")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QueueUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local queueButton = Instance.new("TextButton")
queueButton.Name = "QueueButton"
queueButton.Size = UDim2.new(0, 220, 0, 44)
queueButton.Position = UDim2.new(0, 20, 0, 500)
queueButton.BackgroundColor3 = Color3.fromRGB(20, 90, 160)
queueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
queueButton.Font = Enum.Font.SourceSansBold
queueButton.TextSize = 18
queueButton.Text = "QUEUE FOR SPEED OVAL"
queueButton.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 300, 0, 60)
statusLabel.Position = UDim2.new(0, 20, 0, 550)
statusLabel.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
statusLabel.BackgroundTransparency = 0.15
statusLabel.TextColor3 = Color3.fromRGB(238, 243, 255)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 15
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = screenGui

local inQueue = false

local function setQueued(queued)
	inQueue = queued
	queueButton.Text = queued and "LEAVE QUEUE" or "QUEUE FOR SPEED OVAL"
	queueButton.BackgroundColor3 = queued and Color3.fromRGB(160, 50, 40) or Color3.fromRGB(20, 90, 160)
end

queueButton.MouseButton1Click:Connect(function()
	queueForRaceEvent:FireServer()
end)

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "queueJoined" then
		setQueued(true)
		statusLabel.Text = string.format("In queue (position %d). A heat starts at 6 players\nor after a short wait with 2+.", data.position)
	elseif data.type == "queueLeft" then
		setQueued(false)
		statusLabel.Text = "Left the queue."
	elseif data.type == "raceStart" then
		setQueued(false)
		statusLabel.Text = string.format("Race started! %d racers on Speed Oval -- go!", data.racerCount)
	elseif data.type == "raceFinish" then
		if data.dnf then
			statusLabel.Text = string.format("Race timed out before you finished. +%d Cash consolation.", data.reward)
		else
			statusLabel.Text = string.format("Finished #%d! +%d Cash.", data.rank, data.reward)
		end
	end
end)
