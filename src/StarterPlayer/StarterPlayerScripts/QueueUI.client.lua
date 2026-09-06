-- Race queue panel: one join/leave button per competitive track (Speed
-- Oval, Technical Circuit, Stunt Yard), plus shared status text for queue
-- position, race start, and finish placement. A player can only wait in
-- one track's queue at a time -- the server enforces that and this UI just
-- reflects whichever "queueJoined" event it's told about.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local lapUpdateEvent = ReplicatedStorage:WaitForChild("LapUpdate")
local queueForRaceEvent = ReplicatedStorage:WaitForChild("QueueForRace")
local returnToShowroomEvent = ReplicatedStorage:WaitForChild("ReturnToShowroom")

local TRACKS = {
	{ id = "speed_oval", label = "SPEED OVAL" },
	{ id = "technical_circuit", label = "TECHNICAL CIRCUIT" },
	{ id = "stunt_yard", label = "STUNT YARD" },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QueueUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.Size = UDim2.new(0, 260, 0, 190)
panel.Position = UDim2.new(0, 20, 0, 500)
panel.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
panel.BackgroundTransparency = 0.15
panel.Parent = screenGui

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 300, 0, 60)
statusLabel.Position = UDim2.new(0, 20, 0, 700)
statusLabel.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
statusLabel.BackgroundTransparency = 0.15
statusLabel.TextColor3 = Color3.fromRGB(238, 243, 255)
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 15
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Not queued."
statusLabel.Parent = screenGui

local buttons = {} -- trackId -> TextButton
local queuedTrackId = nil

local function refreshButtons()
	for trackId, button in pairs(buttons) do
		if trackId == queuedTrackId then
			button.Text = "LEAVE QUEUE"
			button.BackgroundColor3 = Color3.fromRGB(160, 50, 40)
		else
			local def
			for _, t in ipairs(TRACKS) do
				if t.id == trackId then
					def = t
				end
			end
			button.Text = "QUEUE: " .. (def and def.label or trackId)
			button.BackgroundColor3 = Color3.fromRGB(20, 90, 160)
		end
	end
end

for _, def in ipairs(TRACKS) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 44)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = Color3.fromRGB(20, 90, 160)
	button.Text = "QUEUE: " .. def.label
	button.Parent = panel

	button.MouseButton1Click:Connect(function()
		queueForRaceEvent:FireServer(def.id)
	end)

	buttons[def.id] = button
end

local returnButton = Instance.new("TextButton")
returnButton.Name = "ReturnToShowroomButton"
returnButton.Size = UDim2.new(1, 0, 0, 40)
returnButton.Font = Enum.Font.SourceSansBold
returnButton.TextSize = 15
returnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
returnButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
returnButton.Text = "RETURN TO SHOWROOM"
returnButton.Parent = panel

returnButton.MouseButton1Click:Connect(function()
	returnToShowroomEvent:FireServer()
end)

lapUpdateEvent.OnClientEvent:Connect(function(data)
	if data.type == "queueJoined" then
		queuedTrackId = data.trackId
		refreshButtons()
		statusLabel.Text = string.format(
			"In queue for %s (position %d).\nA heat starts at 6, or after a short wait with 2+.",
			data.trackId,
			data.position
		)
	elseif data.type == "queueLeft" then
		if queuedTrackId == data.trackId then
			queuedTrackId = nil
		end
		refreshButtons()
		statusLabel.Text = "Left the queue."
	elseif data.type == "raceStart" then
		queuedTrackId = nil
		refreshButtons()
		statusLabel.Text = string.format("Race started on %s! %d racers -- go!", data.trackId, data.racerCount)
	elseif data.type == "raceFinish" then
		if data.dnf then
			statusLabel.Text = string.format("Race timed out before you finished. +%d Cash consolation.", data.reward)
		else
			statusLabel.Text = string.format("Finished #%d on %s! +%d Cash.", data.rank, data.trackId, data.reward)
		end
	end
end)
