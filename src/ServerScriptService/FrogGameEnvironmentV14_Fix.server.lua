-- Frog Game Environment V18
-- WATER / FLOOR / VERTICAL ALIGNMENT REPAIR
-- Removes legacy yellow floor even when nested in a model, keeps the real
-- terrain pond blue, and aligns V15/V17 scenery with the lowered island.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

local function isInFrogGame(instance)
    return instance:FindFirstAncestor("FrogGame") ~= nil
end

-- Remove legacy map floors/spawns recursively. The previous repair only checked
-- direct Workspace children, so a yellow floor inside a Model could survive.
local function removeLegacyGeometry()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not isInFrogGame(obj) then
            if obj:IsA("SpawnLocation") then
                obj:Destroy()
            elseif obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                if n == "baseplate" or n == "base" or n == "ground" or n == "floor"
                    or obj.Size.X > 1800 or obj.Size.Z > 1800 then
                    obj:Destroy()
                end
            end
        end
    end
end

removeLegacyGeometry()

if Terrain then
    Terrain.WaterColor = Color3.fromRGB(24, 125, 170)
    Terrain.WaterTransparency = 0.18
    Terrain.WaterReflectance = 0.08
    Terrain.WaterWaveSize = 0.22
    Terrain.WaterWaveSpeed = 8
end

-- ===== Per-player base assignment =====
-- V13 builds 6 separate player bases (PlayerBase_1..6), each with its own
-- Spawn_N SpawnLocation. Every player getting force-moved to the SAME
-- Spawn_1 (the original behavior here) meant everyone piled up at one
-- base regardless of Roblox's own random SpawnLocation choice -- the other
-- 5 bases would sit empty no matter how many players joined. Each player
-- now gets their own base, freed when they leave so the next joiner reuses it.

local BASE_COUNT = 6
local freeBaseIndices = {}
for i = 1, BASE_COUNT do
    table.insert(freeBaseIndices, i)
end
local assignedBase = {} -- Player -> index 1..6

local function assignBase(player)
    if #freeBaseIndices == 0 then
        return nil
    end
    local index = table.remove(freeBaseIndices, 1)
    assignedBase[player] = index
    return index
end

local function releaseBase(player)
    local index = assignedBase[player]
    if index then
        table.insert(freeBaseIndices, index)
        assignedBase[player] = nil
    end
end

local function getLobby()
    local frogGame = Workspace:WaitForChild("FrogGame", 20)
    if not frogGame then return nil end
    local map = frogGame:WaitForChild("ReferenceLayoutV13", 20)
    if not map then return nil end
    return map:WaitForChild("Lobby", 20)
end

local function getSpawnForPlayer(player)
    local lobby = getLobby()
    local index = lobby and assignedBase[player]
    if not lobby or not index then
        return nil
    end
    return lobby:FindFirstChild("Spawn_" .. index)
end

local function placeCharacter(player, character)
    local spawn = getSpawnForPlayer(player)
    local root = character and character:WaitForChild("HumanoidRootPart", 5)
    if spawn and root then
        root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
    end
end

local function setupPlayer(player)
    assignBase(player)

    player.CharacterAdded:Connect(function(character)
        task.spawn(placeCharacter, player, character)
    end)
    if player.Character then
        task.spawn(placeCharacter, player, player.Character)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(releaseBase)

local function lowerParts(container, amount)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CFrame = obj.CFrame + Vector3.new(0, -amount, 0)
        end
    end
end

local function raiseNamed(container, name, amount)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == name then
            obj.CFrame = obj.CFrame + Vector3.new(0, amount, 0)
        end
    end
end

local function lowerCentralBeauty(generated, amount)
    if not generated then return end
    for _, obj in ipairs(generated:GetDescendants()) do
        if obj:IsA("BasePart") then
            local p = obj.Position
            local radial = math.sqrt(p.X*p.X + p.Z*p.Z)
            local waterObject = obj.Name == "FloatingLotus"
                or obj.Name == "FloatingPetal"
                or obj.Name == "ExtraLilyPad"
                or obj.Name == "LilyFlower"
                or obj.Name == "WaterEdgeRock"
                or obj.Name == "KoiBody"
                or obj.Name == "KoiHead"
                or obj.Name == "KoiTail"
                or obj.Name == "CattailLeaf"
                or obj.Name == "CattailHead"
            if radial <= 1100 and not waterObject then
                obj.CFrame = obj.CFrame + Vector3.new(0, -amount, 0)
            end
        end
    end
end

local function alignMapToWater()
    local frogGame = Workspace:FindFirstChild("FrogGame")
    if not frogGame then return end
    local map = frogGame:FindFirstChild("ReferenceLayoutV13")
    if not map or map:GetAttribute("VerticalAlignmentV18") then return end

    local island = map:FindFirstChild("CentralIsland")
    if island then
        lowerParts(island, 40)
        -- Shore rocks were originally centered below the island surface.
        raiseNamed(island, "IslandShoreRock", 26)
    end

    local beauty = map:FindFirstChild("BeautyDecor")
    if beauty then
        local v15 = beauty:FindFirstChild("V15Generated")
        if not v15 then v15 = beauty:WaitForChild("V15Generated", 20) end
        lowerCentralBeauty(v15, 45)

        local v17 = beauty:FindFirstChild("V17Generated")
        if not v17 then v17 = beauty:WaitForChild("V17Generated", 20) end
        lowerCentralBeauty(v17, 45)
    end

    map:SetAttribute("VerticalAlignmentV18", true)
    map:SetAttribute("WaterSurfaceY", 0)
    map:SetAttribute("IslandVerticalOffset", -40)
    map:SetAttribute("LegacyFloorRemovedV18", true)
    print("FrogGame V18 repair: yellow floor removed, water restored, decorations aligned")
end

task.spawn(function()
    local frogGame = Workspace:WaitForChild("FrogGame", 30)
    if frogGame then
        frogGame:WaitForChild("ReferenceLayoutV13", 30)
        task.wait(2)
        alignMapToWater()
    end
end)

-- V13/V15/V17 can finish at slightly different times under Rojo/Studio.
-- Re-check briefly so late-created scenery cannot remain floating.
task.delay(5, function()
    alignMapToWater()
end)

task.spawn(function()
    for _ = 1, 12 do
        task.wait(1)
        removeLegacyGeometry()
    end
end)

task.delay(1, function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            task.spawn(placeCharacter, player, player.Character)
        end
    end
end)

print("FrogGame V18 repair loaded")
