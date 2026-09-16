-- Frog Game Environment V13
-- COMPLETE REFERENCE LAYOUT
-- Large swimmable pond, central frog island, full lobby landscaping,
-- outer stone promenade, Sakura trees, bushes, flowers, lily pads,
-- reeds, fish, bridge, frog statue/emblem, docks, boats and six bases.

local Workspace = game:GetService("Workspace")
local Terrain = Workspace:FindFirstChildOfClass("Terrain") or Instance.new("Terrain", Workspace)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local old = Workspace:FindFirstChild("FrogGame")
if old then old:Destroy() end
Terrain:Clear()

local world = Instance.new("Folder")
world.Name = "FrogGame"
world.Parent = Workspace

local map = Instance.new("Folder")
map.Name = "ReferenceLayoutV13"
map.Parent = world

local folders = {}
for _, name in ipairs({"Foundation","Pond","CentralIsland","Lobby","Sakura","Vegetation","WaterLife","Docks","GameplayRegions"}) do
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	folders[name] = f
end

local Foundation, Pond, Island, Lobby, Sakura, Vegetation, WaterLife, Docks, Regions =
	folders.Foundation, folders.Pond, folders.CentralIsland, folders.Lobby, folders.Sakura,
	folders.Vegetation, folders.WaterLife, folders.Docks, folders.GameplayRegions

local C = {
	stone = Color3.fromRGB(145,148,143), stone2 = Color3.fromRGB(188,187,174), stoneDark = Color3.fromRGB(82,86,82),
	grass = Color3.fromRGB(80,145,67), grassDark = Color3.fromRGB(42,105,48), grassLight = Color3.fromRGB(111,171,75),
	wood = Color3.fromRGB(105,70,42), woodDark = Color3.fromRGB(72,48,31),
	pink = Color3.fromRGB(244,151,193), pink2 = Color3.fromRGB(255,188,211),
	flowerWhite = Color3.fromRGB(244,239,216), flowerYellow = Color3.fromRGB(246,213,80),
	water = Color3.fromRGB(35,155,194), lotus = Color3.fromRGB(242,132,174),
	frog = Color3.fromRGB(76,143,67), eye = Color3.fromRGB(245,240,200),
}

local function part(name, size, cf, material, color, parent, collide)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color or C.stone
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	p.CanTouch = false
	p.CanQuery = collide ~= false
	p.Parent = parent
	return p
end

local function ball(name, pos, size, color, material, parent, collide)
	local p = part(name, size, CFrame.new(pos), material or Enum.Material.SmoothPlastic, color, parent, collide)
	p.Shape = Enum.PartType.Ball
	return p
end

local function cyl(name, pos, size, color, material, parent, collide, yaw)
	local p = part(name, size, CFrame.new(pos) * CFrame.Angles(0, yaw or 0, math.rad(90)), material or Enum.Material.SmoothPlastic, color, parent, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- =========================
-- MASTER SCALE
-- =========================
local WORLD_X, WORLD_Z = 6600, 5400
local POND_X, POND_Z = 6200, 4300
local WATER_TOP, WATER_BOTTOM = 0, -22
local ISLAND_X, ISLAND_Z = 1700, 1200
local LOBBY_Z = 2380

-- =========================
-- TERRAIN: HUGE REAL SWIMMING POND + LAND
-- =========================
Terrain:FillBlock(CFrame.new(0, (WATER_TOP + WATER_BOTTOM)/2, 0), Vector3.new(POND_X, WATER_TOP-WATER_BOTTOM, POND_Z), Enum.Material.Water)
-- Lobby land strip is outside the pond.
Terrain:FillBlock(CFrame.new(0, -2, 2420), Vector3.new(WORLD_X-100, 10, 600), Enum.Material.Grass)
-- Small grassy land strips beyond the pond's other edges, giving the promenade a natural setting.
Terrain:FillBlock(CFrame.new(0, -2, -2450), Vector3.new(WORLD_X-100, 10, 400), Enum.Material.Grass)

-- =========================
-- OUTER STONE PROMENADE / FOUNDATION
-- =========================
local PATH_W = 18
local slabLen = 24
local hx, hz = WORLD_X/2 - 360, WORLD_Z/2 - 320

local function stoneSlab(name, size, cf, i)
	local p = part(name, size, cf, Enum.Material.Slate, (i % 6 == 0) and C.stone2 or C.stone, Foundation, true)
	p.CFrame = cf * CFrame.new(0, ((i % 3)-1)*0.04, 0)
	return p
end

local function straightH(z, x0, x1, label)
	local x, i = x0, 0
	while x < x1 - 0.1 do
		i += 1
		local len = math.min(slabLen, x1-x)
		stoneSlab(label..string.format("_%03d",i), Vector3.new(math.max(4,len-1.0),1.5,PATH_W), CFrame.new(x+len/2,8,z), i)
		x += len
	end
end
local function straightV(x, z0, z1, label)
	local z, i = z0, 0
	while z < z1 - 0.1 do
		i += 1
		local len = math.min(slabLen,z1-z)
		stoneSlab(label..string.format("_%03d",i), Vector3.new(PATH_W,1.5,math.max(4,len-1.0)), CFrame.new(x,8,z+len/2), i)
		z += len
	end
end
straightH(-WORLD_Z/2, -hx, hx, "NorthStone")
straightH(WORLD_Z/2, -hx, hx, "SouthStone")
straightV(-WORLD_X/2, -hz, hz, "WestStone")
straightV(WORLD_X/2, -hz, hz, "EastStone")

local function corner(cx,cz,start,label,phase)
	local count=28
	for i=1,count do
		local a=start+(i-0.5)*(math.pi/2)/count
		local x=cx+math.cos(a)*360
		local z=cz+math.sin(a)*320
		local tx=-math.sin(a)*360
		local tz=math.cos(a)*320
		local yaw=math.atan2(tz,tx)
		stoneSlab(label..string.format("_%03d",i),Vector3.new(25,1.5,PATH_W),CFrame.new(x,8,z)*CFrame.Angles(0,yaw,0),i+phase)
	end
end
corner(-hx,-hz,math.pi,"NW",1)
corner(hx,-hz,-math.pi/2,"NE",2)
corner(-hx,hz,math.pi/2,"SW",3)
corner(hx,hz,0,"SE",4)

-- Low inner curb separating the path from the future playable water edge.
part("InnerNorthCurb",Vector3.new(WORLD_X-720,1,2),CFrame.new(0,8.8,-POND_Z/2-45),Enum.Material.Slate,C.stoneDark,Foundation,true)
part("InnerSouthCurb",Vector3.new(WORLD_X-720,1,2),CFrame.new(0,8.8,POND_Z/2+45),Enum.Material.Slate,C.stoneDark,Foundation,true)
part("InnerWestCurb",Vector3.new(2,1,WORLD_Z-640),CFrame.new(-POND_X/2-45,8.8,0),Enum.Material.Slate,C.stoneDark,Foundation,true)
part("InnerEastCurb",Vector3.new(2,1,WORLD_Z-640),CFrame.new(POND_X/2+45,8.8,0),Enum.Material.Slate,C.stoneDark,Foundation,true)

-- =========================
-- CENTRAL ISLAND
-- =========================
local islandBase = cyl("IslandBase",Vector3.new(0,25,0),Vector3.new(ISLAND_X,50,ISLAND_Z),C.grass,Enum.Material.Grass,Island,true)
local crown = cyl("IslandGrassCrown",Vector3.new(0,51,0),Vector3.new(ISLAND_X-60,9,ISLAND_Z-60),C.grassLight,Enum.Material.Grass,Island,true)

for i=1,84 do
	local a=(i-1)/84*math.pi*2
	local rx=ISLAND_X/2+28
	local rz=ISLAND_Z/2+28
	local x,z=math.cos(a)*rx,math.sin(a)*rz
	local s=13+(i%5)*2
	ball("IslandShoreRock",Vector3.new(x,16,z),Vector3.new(s,s*0.72,s*0.9),C.stone,Enum.Material.Slate,Island,true)
end

-- Natural stone paths over the island.
for i=-7,7 do
	local z=i*70
	part("IslandPath",Vector3.new(105,4,58),CFrame.new(i*45,58,z)*CFrame.Angles(0,math.rad((i%3)*10),0),Enum.Material.Slate,C.stone2,Island,true)
end
for i=-5,5 do
	local x=i*105
	part("IslandCrossPath",Vector3.new(60,4,105),CFrame.new(x,58,0),Enum.Material.Slate,C.stone2,Island,true)
end

-- =========================
-- VEGETATION HELPERS
-- =========================
local function grassTuft(x,y,z,s,parent)
	for j=1,5 do
		local h=(16+((j*7)%14))*s
		part("GrassBlade",Vector3.new(2.2*s,h,2.2*s),CFrame.new(x+(j-3)*2*s,y+h/2,z+math.sin(j)*2*s)*CFrame.Angles(0,0,math.rad((j-3)*7)),Enum.Material.Grass,C.grassDark,parent,false)
	end
end
local function bush(x,y,z,s,parent)
	for j=1,5 do
		ball("Bush",Vector3.new(x+(j-3)*13*s,y+17*s,z+math.sin(j*1.7)*9*s),Vector3.new(45,34,45)*s,C.grassDark,Enum.Material.Grass,parent,false)
	end
end
local function flower(x,y,z,s,parent)
	for j=1,5 do
		local a=j*math.pi*2/5
		ball("FlowerPetal",Vector3.new(x+math.cos(a)*7*s,y+10*s,z+math.sin(a)*7*s),Vector3.new(10,5,10)*s,(j%2==0) and C.pink2 or C.flowerWhite,Enum.Material.SmoothPlastic,parent,false)
	end
	ball("FlowerCenter",Vector3.new(x,y+10*s,z),Vector3.new(7,5,7)*s,C.flowerYellow,Enum.Material.SmoothPlastic,parent,false)
end

-- =========================
-- SAKURA TREES
-- =========================
local function sakuraTree(x,y,z,s,parent)
	part("SakuraTrunk",Vector3.new(17*s,85*s,17*s),CFrame.new(x,y+42*s,z),Enum.Material.Wood,C.wood,parent,true)
	for j=1,7 do
		local a=j*0.9
		local ox,oz=math.cos(a)*35*s,math.sin(a)*35*s
		ball("SakuraBloom",Vector3.new(x+ox,y+90*s+math.sin(j)*8*s,z+oz),Vector3.new(64,55,64)*s,C.pink,Enum.Material.SmoothPlastic,parent,false)
	end
end

local islandTrees={{-590,-330},{-300,330},{-40,-380},{300,340},{590,-180},{430,100},{-470,110},{90,300},{-90,-80},{600,310}}
for _,p in ipairs(islandTrees) do sakuraTree(p[1],58,p[2],0.72,Island) end
local lobbyTrees={{-3000,2280},{-2550,2590},{-2050,2260},{-1550,2600},{1550,2600},{2050,2260},{2550,2590},{3000,2280},{-3200,2480},{3200,2480}}
for _,p in ipairs(lobbyTrees) do sakuraTree(p[1],4,p[2],0.65,Sakura) end

-- =========================
-- ISLAND + LOBBY DENSE GRASS / BUSHES / FLOWERS
-- =========================
for i=1,70 do
	local a=i*2.31
	local r=180+(i%7)*85
	bush(math.cos(a)*r,58,math.sin(a)*r,0.45+(i%3)*0.08,Vegetation)
end
for i=1,130 do
	local a=i*1.91
	local r=180+(i%9)*115
	flower(math.cos(a)*r,58,math.sin(a)*r,0.45+(i%4)*0.08,Vegetation)
end

-- Lobby grass is deliberately distributed across every non-paved section.
for x=-3150,3150,95 do
	for z=2170,2700,75 do
		local paved = (math.abs(x)<1600 and z>2240 and z<2545)
		if not paved or (x%285==0) then grassTuft(x,5,z,0.9,Lobby) end
	end
end
for i=1,75 do
	local x=-3050+(i*419)%6100
	local z=2180+(i*97)%500
	bush(x,5,z,0.45+(i%3)*0.08,Lobby)
end
for i=1,110 do
	local x=-3050+(i*283)%6100
	local z=2180+(i*131)%500
	flower(x,5,z,0.42+(i%3)*0.08,Lobby)
end

-- =========================
-- LOBBY / SIX PLAYER BASES
-- =========================
part("LobbyPlaza",Vector3.new(3100,10,330),CFrame.new(0,10,2380),Enum.Material.Slate,C.stone2,Lobby,true)
part("LobbyFrontWalk",Vector3.new(5800,8,80),CFrame.new(0,8,2630),Enum.Material.Slate,C.stone,Lobby,true)
part("LobbyCenterWalk",Vector3.new(100,8,420),CFrame.new(0,9,2380),Enum.Material.Slate,C.stone,Lobby,true)

local baseColors={Color3.fromRGB(215,70,70),Color3.fromRGB(235,150,45),Color3.fromRGB(65,175,90),Color3.fromRGB(55,130,220),Color3.fromRGB(145,85,215),Color3.fromRGB(235,105,170)}
for i=1,6 do
	local x=-1375+(i-1)*550
	part("PlayerBase_"..i,Vector3.new(390,12,175),CFrame.new(x,20,2350),Enum.Material.Wood,baseColors[i],Lobby,true)
	part("PlayerMat_"..i,Vector3.new(300,4,110),CFrame.new(x,29,2350),Enum.Material.SmoothPlastic,baseColors[i],Lobby,true)
	part("PlayerBack_"..i,Vector3.new(380,52,12),CFrame.new(x,49,2260),Enum.Material.Wood,C.wood,Lobby,true)
	part("PlayerCanopy_"..i,Vector3.new(380,10,130),CFrame.new(x,78,2350),Enum.Material.Fabric,baseColors[i],Lobby,true)
	for s=1,5 do part("DollSlot_"..i.."_"..s,Vector3.new(45,4,30),CFrame.new(x-108+(s-1)*54,35,2350),Enum.Material.Slate,C.flowerWhite,Lobby,true) end
	local spawn=Instance.new("SpawnLocation")
	spawn.Name="Spawn_"..i spawn.Size=Vector3.new(54,2,54) spawn.CFrame=CFrame.new(x,36,2505)
	spawn.Anchored=true spawn.Neutral=true spawn.Color=baseColors[i] spawn.Parent=Lobby
end

-- Central frog emblem plaza.
cyl("FrogEmblemBase",Vector3.new(0,25,2730),Vector3.new(330,6,330),Color3.fromRGB(125,130,123),Enum.Material.Slate,Lobby,true)
ball("FrogEyeLeft",Vector3.new(-72,33,2690),Vector3.new(58,22,58),C.frog,Enum.Material.Grass,Lobby,false)
ball("FrogEyeRight",Vector3.new(72,33,2690),Vector3.new(58,22,58),C.frog,Enum.Material.Grass,Lobby,false)
ball("FrogEyeWhiteL",Vector3.new(-72,43,2680),Vector3.new(18,10,18),C.eye,Enum.Material.SmoothPlastic,Lobby,false)
ball("FrogEyeWhiteR",Vector3.new(72,43,2680),Vector3.new(18,10,18),C.eye,Enum.Material.SmoothPlastic,Lobby,false)
part("FrogMouth",Vector3.new(120,8,12),CFrame.new(0,34,2760),Enum.Material.SmoothPlastic,C.frog,Lobby,false)

-- =========================
-- MAIN BRIDGE: LOBBY -> ISLAND
-- =========================
local bridge = Instance.new("Folder") bridge.Name="MainBridge" bridge.Parent=map
for i=1,31 do
	local z=2140-(i-1)*51
	local y=14+(i-1)*(44/30)
	part("BridgeStone_"..i,Vector3.new(105,8,43),CFrame.new(0,y,z),Enum.Material.Slate,C.stone2,bridge,true)
end
for side=-1,1,2 do
	part("BridgeRail_"..side,Vector3.new(8,42,1550),CFrame.new(side*68,35,1380),Enum.Material.Wood,C.wood,bridge,true)
	for i=1,16 do
		local z=2110-(i-1)*100
		part("BridgePost_"..side.."_"..i,Vector3.new(9,50,9),CFrame.new(side*68,35,z),Enum.Material.Wood,C.woodDark,bridge,true)
	end
end

-- =========================
-- LOTUS / LILY PADS / REEDS
-- =========================
local function lily(x,z,s)
	local p=cyl("LilyPad",Vector3.new(x,2,z),Vector3.new(38*s,2,38*s),Color3.fromRGB(70,155,78),Enum.Material.Grass,Pond,false,0)
	return p
end
local function lotus(x,z,s)
	lily(x,z,s)
	for j=1,6 do
		local a=j*math.pi/3
		ball("LotusPetal",Vector3.new(x+math.cos(a)*9*s,8*s,z+math.sin(a)*9*s),Vector3.new(12*s,5*s,20*s),C.lotus,Enum.Material.SmoothPlastic,Pond,false)
	end
	ball("LotusCenter",Vector3.new(x,10*s,z),Vector3.new(8*s,6*s,8*s),C.flowerYellow,Enum.Material.SmoothPlastic,Pond,false)
end
for i=1,95 do
	local a=i*2.17
	local rx=900+(i%12)*210
	local rz=700+(i%10)*150
	lily(math.cos(a)*rx,math.sin(a)*rz,0.75+(i%4)*0.13)
end
for i=1,24 do
	local a=i*2.63
	local rx=1000+(i%5)*380
	local rz=800+(i%4)*260
	lotus(math.cos(a)*rx,math.sin(a)*rz,0.65+(i%3)*0.12)
end
for i=1,150 do
	local a=i*2.399
	local edgeX=POND_X/2-30
	local edgeZ=POND_Z/2-30
	local x,z
	if i%2==0 then x=math.cos(a)*edgeX; z=math.sin(a)*1200 else x=math.cos(a)*1200; z=math.sin(a)*edgeZ end
	grassTuft(x,3,z,0.85+(i%3)*0.1,Pond)
end

-- =========================
-- FISH: SIMPLE ANIMATED WATER LIFE
-- =========================
local fish={} 
for i=1,26 do
	local a=i*1.73
	local rX=500+(i%9)*270
	local rZ=450+(i%8)*210
	local x,z=math.cos(a)*rX,math.sin(a)*rZ
	local body=ball("FishBody",Vector3.new(x,-2,z),Vector3.new(22,10,40),Color3.fromRGB(240,145+(i%3)*30,90+(i%4)*20),Enum.Material.SmoothPlastic,WaterLife,false)
	local tail=part("FishTail",Vector3.new(3,13,18),CFrame.new(x,-2,z+24),Enum.Material.SmoothPlastic,C.flowerWhite,WaterLife,false)
	tail.Shape=Enum.PartType.Wedge
	table.insert(fish,{body=body,tail=tail,base=Vector3.new(x,-2,z),phase=a})
end
RunService.Heartbeat:Connect(function(t)
	for _,f in ipairs(fish) do
		if f.body.Parent then
			local x=f.base.X+math.cos(t*0.32+f.phase)*90
			local z=f.base.Z+math.sin(t*0.27+f.phase)*70
			local y=-3+math.sin(t*1.8+f.phase)*2
			f.body.CFrame=CFrame.new(x,y,z)*CFrame.Angles(0,math.sin(t*0.3+f.phase),0)
			f.tail.CFrame=CFrame.new(x,y,z+24)*CFrame.Angles(0,math.sin(t*0.3+f.phase),0)
		end
	end
end)

-- =========================
-- DOCKS / BOATS
-- =========================
for side=-1,1,2 do
	for k=1,2 do
		local x=side*(POND_X/2-190)
		local z=-700+k*650
		part("Dock_"..side.."_"..k,Vector3.new(190,10,58),CFrame.new(x,8,z),Enum.Material.Wood,C.wood,Docks,true)
		for j=-2,2 do part("DockPost",Vector3.new(10,48,10),CFrame.new(x+j*38,24,z-25),Enum.Material.Wood,C.woodDark,Docks,true) end
		local boat=part("Boat_"..side.."_"..k,Vector3.new(125,20,48),CFrame.new(x-side*82,2,z),Enum.Material.Wood,C.wood,Docks,true)
		boat.Shape=Enum.PartType.Wedge
		part("BoatMast",Vector3.new(6,70,6),CFrame.new(x-side*82,37,z),Enum.Material.Wood,C.woodDark,Docks,true)
		part("BoatSail",Vector3.new(4,48,45),CFrame.new(x-side*82,50,z),Enum.Material.Fabric,C.flowerWhite,Docks,false)
	end
end

-- =========================
-- FROG STATUE ON ISLAND
-- =========================
local statue=Instance.new("Model") statue.Name="FrogStatue" statue.Parent=Island
ball("StatueBody",Vector3.new(0,82,-40),Vector3.new(150,125,125),C.frog,Enum.Material.SmoothPlastic,statue,true)
ball("StatueEyeL",Vector3.new(-55,145,-70),Vector3.new(48,48,48),C.frog,Enum.Material.SmoothPlastic,statue,true)
ball("StatueEyeR",Vector3.new(55,145,-70),Vector3.new(48,48,48),C.frog,Enum.Material.SmoothPlastic,statue,true)
ball("StatuePupilL",Vector3.new(-55,151,-92),Vector3.new(17,17,17),C.eye,Enum.Material.SmoothPlastic,statue,false)
ball("StatuePupilR",Vector3.new(55,151,-92),Vector3.new(17,17,17),C.eye,Enum.Material.SmoothPlastic,statue,false)
part("StatueMouth",Vector3.new(75,10,10),CFrame.new(0,92,-105),Enum.Material.SmoothPlastic,C.grassDark,statue,false)

-- =========================
-- LIGHTS / FLAGS / LANDSCAPE DETAIL
-- =========================
local function lamp(x,z,parent)
	part("LampPost",Vector3.new(7,55,7),CFrame.new(x,30,z),Enum.Material.Wood,C.woodDark,parent,true)
	ball("LampGlow",Vector3.new(x,59,z),Vector3.new(18,18,18),Color3.fromRGB(255,220,130),Enum.Material.Neon,parent,false)
end
for x=-2900,2900,580 do lamp(x,2565,Lobby) end
for _,x in ipairs({-1500,-900,900,1500}) do lamp(x,2150,Lobby) end

for i=1,28 do
	local x=-3000+(i*431)%6000
	local z=2170+(i*173)%500
	part("BannerPole",Vector3.new(5,70,5),CFrame.new(x,35,z),Enum.Material.Wood,C.woodDark,Lobby,true)
	part("Banner",Vector3.new(5,38,26),CFrame.new(x+10,52,z),Enum.Material.Fabric,baseColors[(i-1)%6+1],Lobby,false)
end

-- Gameplay region markers for future systems.
local function region(name,size,cf)
	local p=part(name,size,cf,Enum.Material.ForceField,Color3.fromRGB(255,210,70),Regions,false)
	p.Transparency=1
	return p
end
region("FrogSpawnRegion",Vector3.new(ISLAND_X-220,20,ISLAND_Z-220),CFrame.new(0,70,0))
region("SwimRegion",Vector3.new(POND_X-120,20,POND_Z-120),CFrame.new(0,-1,0))
region("LobbyRegion",Vector3.new(5700,20,520),CFrame.new(0,10,2440))
region("RaceStart",Vector3.new(180,20,120),CFrame.new(0,15,2070))

-- =========================
-- WORLD ATTRIBUTES
-- =========================
world:SetAttribute("MapVersion","ReferenceLayout_v13_Complete")
world:SetAttribute("WorldSizeX",WORLD_X)
world:SetAttribute("WorldSizeZ",WORLD_Z)
world:SetAttribute("PondSizeX",POND_X)
world:SetAttribute("PondSizeZ",POND_Z)
world:SetAttribute("SwimmingAreaStuds","6200x4300")
world:SetAttribute("CentralIslandSize","1700x1200")
world:SetAttribute("MaxPlayers",6)
world:SetAttribute("MaxFrogs",20)
world:SetAttribute("ActiveRoundSeconds",300)
world:SetAttribute("ResetSeconds",10)
world:SetAttribute("SakuraTrees",20)
world:SetAttribute("LobbyGrassDense",true)
world:SetAttribute("LilyPads",95)
world:SetAttribute("LotusFlowers",24)
world:SetAttribute("Fish",26)
world:SetAttribute("Docks",4)

Lighting.ClockTime=14
Lighting.Brightness=2.2
Lighting.EnvironmentDiffuseScale=0.75
Lighting.EnvironmentSpecularScale=0.4
Lighting.OutdoorAmbient=Color3.fromRGB(175,185,180)

print("FrogGame V13 complete reference layout loaded: huge pond, island, lobby, Sakura, grass, flowers, fish, lotus, bridge, statue, docks and six bases")
