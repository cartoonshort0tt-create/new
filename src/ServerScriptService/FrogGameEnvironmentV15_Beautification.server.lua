-- Frog Game Environment V15
-- BEAUTIFICATION PASS
-- Adds layered scenery, Japanese garden details, lanterns, arches,
-- benches, rock gardens, mushrooms, flower beds, bamboo, fountains,
-- extra lily pads, shoreline accents, decorative bridges and atmosphere.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local frogGame = Workspace:WaitForChild("FrogGame", 20)
if not frogGame then
    warn("V15: FrogGame was not created by V13")
    return
end
local map = frogGame:WaitForChild("ReferenceLayoutV13", 20)
if not map then
    warn("V15: ReferenceLayoutV13 was not created")
    return
end

local function folder(name)
    local f = map:FindFirstChild(name)
    if not f then
        f = Instance.new("Folder")
        f.Name = name
        f.Parent = map
    end
    return f
end

local Island = folder("CentralIsland")
local Lobby = folder("Lobby")
local Pond = folder("Pond")
local Docks = folder("Docks")
local Decor = folder("BeautyDecor")

local C = {
    stone = Color3.fromRGB(126,130,124),
    stoneLight = Color3.fromRGB(198,193,171),
    stoneDark = Color3.fromRGB(65,72,66),
    grass = Color3.fromRGB(68,132,61),
    grassLight = Color3.fromRGB(105,169,77),
    grassDark = Color3.fromRGB(35,96,43),
    wood = Color3.fromRGB(104,68,39),
    woodDark = Color3.fromRGB(58,40,27),
    pink = Color3.fromRGB(247,150,195),
    pinkLight = Color3.fromRGB(255,198,220),
    cream = Color3.fromRGB(255,239,194),
    gold = Color3.fromRGB(255,196,79),
    water = Color3.fromRGB(30,145,190),
    teal = Color3.fromRGB(44,126,125),
    frog = Color3.fromRGB(72,145,70),
    white = Color3.fromRGB(245,244,226),
}

local function part(name,size,cf,material,color,parent,collide)
    local p=Instance.new("Part")
    p.Name=name p.Size=size p.CFrame=cf p.Anchored=true
    p.Material=material or Enum.Material.SmoothPlastic
    p.Color=color or C.stone
    p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
    p.CanCollide=collide ~= false p.CanTouch=false p.CanQuery=collide ~= false
    p.Parent=parent or Decor
    return p
end

local function ball(name,pos,size,color,material,parent,collide)
    local p=part(name,size,CFrame.new(pos),material or Enum.Material.SmoothPlastic,color,parent,collide)
    p.Shape=Enum.PartType.Ball
    return p
end

local function cyl(name,pos,size,color,material,parent,collide,yaw)
    local p=part(name,size,CFrame.new(pos)*CFrame.Angles(0,yaw or 0,math.rad(90)),material or Enum.Material.SmoothPlastic,color,parent,collide)
    p.Shape=Enum.PartType.Cylinder
    return p
end

-- Prevent duplicate decoration if Studio runs the script more than once.
local old=Decor:FindFirstChild("V15Generated")
if old then old:Destroy() end
local Root=Instance.new("Folder") Root.Name="V15Generated" Root.Parent=Decor

-- =========================
-- ISLAND GARDEN RING
-- =========================
for i=1,44 do
    local a=(i-1)/44*math.pi*2
    local rx,rz=690,455
    local x,z=math.cos(a)*rx,math.sin(a)*rz
    local s=0.65+(i%4)*0.08
    if i%3==0 then
        ball("GardenRock",Vector3.new(x,61,z),Vector3.new(32,20,25)*s,C.stone,Enum.Material.Slate,Root,false)
        ball("GardenMoss",Vector3.new(x+4,71,z-3),Vector3.new(20,8,17)*s,C.grass,Enum.Material.Grass,Root,false)
    elseif i%3==1 then
        for j=1,3 do
            ball("GardenFlower",Vector3.new(x+(j-2)*9*s,66+(j%2)*4,z+math.sin(j)*7*s),Vector3.new(12,9,12)*s,(j%2==0) and C.pinkLight or C.cream,Enum.Material.SmoothPlastic,Root,false)
        end
    else
        for j=1,4 do
            part("GardenGrass",Vector3.new(2,20+((i+j)%4)*5,2),CFrame.new(x+(j-2.5)*5,70,z+(j%2)*3)*CFrame.Angles(0,0,math.rad((j-2.5)*8)),Enum.Material.Grass,C.grassDark,Root,false)
        end
    end
end

-- Decorative stone ring path, using normal-sized slabs.
for i=1,36 do
    local a=(i-0.5)/36*math.pi*2
    local x,z=math.cos(a)*770,math.sin(a)*530
    local yaw=a+math.pi/2
    part("GardenPathSlab",Vector3.new(52,5,34),CFrame.new(x,59,z)*CFrame.Angles(0,yaw,0),Enum.Material.Slate,C.stoneLight,Root,true)
end

-- =========================
-- FOUNTAIN / FROG SHRINE
-- =========================
cyl("FountainBase",Vector3.new(0,64,250),Vector3.new(210,16,210),C.stone,Enum.Material.Slate,Root,true)
cyl("FountainBasin",Vector3.new(0,75,250),Vector3.new(145,10,145),C.water,Enum.Material.Glass,Root,false)
cyl("FountainPedestal",Vector3.new(0,94,250),Vector3.new(48,48,48),C.stoneLight,Enum.Material.Slate,Root,true)
ball("FountainFrog",Vector3.new(0,123,250),Vector3.new(58,45,58),C.frog,Enum.Material.SmoothPlastic,Root,false)
ball("FountainEyeL",Vector3.new(-19,140,232),Vector3.new(17,17,17),C.white,Enum.Material.SmoothPlastic,Root,false)
ball("FountainEyeR",Vector3.new(19,140,232),Vector3.new(17,17,17),C.white,Enum.Material.SmoothPlastic,Root,false)

for i=1,8 do
    local a=i*math.pi/4
    ball("WaterDrop",Vector3.new(math.cos(a)*60,93+((i%2)*8),250+math.sin(a)*60),Vector3.new(9,18,9),C.water,Enum.Material.Glass,Root,false)
end

-- =========================
-- TORII GATE AT BRIDGE ENTRANCE
-- =========================
local function torii(z,scale)
    local x=0
    part("ToriiPostL",Vector3.new(24,180,24),CFrame.new(x-115,98,z),Enum.Material.Wood,C.wood,Root,true)
    part("ToriiPostR",Vector3.new(24,180,24),CFrame.new(x+115,98,z),Enum.Material.Wood,C.wood,Root,true)
    part("ToriiBeam",Vector3.new(310,28,30),CFrame.new(x,182,z),Enum.Material.Wood,C.woodDark,Root,true)
    part("ToriiTop",Vector3.new(355,22,35),CFrame.new(x,207,z),Enum.Material.Wood,C.pink,Root,true)
    part("ToriiCenter",Vector3.new(26,48,26),CFrame.new(x,158,z),Enum.Material.Wood,C.woodDark,Root,true)
end
torii(2010,1)

-- =========================
-- LANTERNS THROUGHOUT ISLAND AND LOBBY
-- =========================
local function lantern(x,y,z,parent,scale)
    scale=scale or 1
    part("LanternPost",Vector3.new(7,62,7)*scale,CFrame.new(x,y+31*scale,z),Enum.Material.Wood,C.woodDark,parent,true)
    part("LanternRoof",Vector3.new(34,7,34)*scale,CFrame.new(x,y+67*scale,z),Enum.Material.Wood,C.woodDark,parent,false)
    ball("LanternGlow",Vector3.new(x,y+55*scale,z),Vector3.new(22,26,22)*scale,C.gold,Enum.Material.Neon,parent,false)
    local light=Instance.new("PointLight")
    light.Brightness=1.2 light.Range=18*scale light.Color=C.gold
    light.Parent=parent:FindFirstChild("LanternGlow")
end

for i=1,18 do
    local a=i*math.pi*2/18
    lantern(math.cos(a)*620,58,math.sin(a)*420,Root,0.72)
end
for i=-5,5 do lantern(i*500,7,2670,Root,0.72) end
for _,x in ipairs({-2950,-2350,-1750,1750,2350,2950}) do lantern(x,5,2190,Root,0.85) end

-- =========================
-- BENCHES + PICNIC CORNERS
-- =========================
local function bench(x,y,z,yaw)
    local m=Instance.new("Model") m.Name="GardenBench" m.Parent=Root
    local cf=CFrame.new(x,y,z)*CFrame.Angles(0,yaw or 0,0)
    part("Seat",Vector3.new(100,12,28),cf,Enum.Material.Wood,C.wood,m,true)
    part("Back",Vector3.new(100,45,10),cf*CFrame.new(0,30,-12),Enum.Material.Wood,C.wood,m,true)
    part("LegL",Vector3.new(10,38,10),cf*CFrame.new(-38,-25,0),Enum.Material.Wood,C.woodDark,m,true)
    part("LegR",Vector3.new(10,38,10),cf*CFrame.new(38,-25,0),Enum.Material.Wood,C.woodDark,m,true)
end
bench(-430,72,220,math.rad(25))
bench(430,72,220,math.rad(-25))
bench(-500,8,2580,0)
bench(500,8,2580,math.pi)

-- Picnic rugs and low tables in lobby.
for _,x in ipairs({-1120,1120}) do
    part("PicnicRug",Vector3.new(260,4,180),CFrame.new(x,17,2700),Enum.Material.Fabric,(x<0) and C.pinkLight or C.cream,Root,false)
    cyl("PicnicTable",Vector3.new(x,32,2700),Vector3.new(65,7,65),C.wood,Enum.Material.Wood,Root,true)
end

-- =========================
-- MUSHROOMS / MINI ROCK GARDENS
-- =========================
for i=1,42 do
    local a=i*2.71
    local r=500+(i%5)*95
    local x,z=math.cos(a)*r,math.sin(a)*r*0.68
    local s=0.55+(i%4)*0.12
    part("MushroomStem",Vector3.new(10,25,10)*s,CFrame.new(x,66,z),Enum.Material.SmoothPlastic,C.cream,Root,false)
    ball("MushroomCap",Vector3.new(x,81*s+30,z),Vector3.new(38,20,38)*s,(i%2==0) and C.pink or C.gold,Enum.Material.SmoothPlastic,Root,false)
end

-- =========================
-- BAMBOO / GARDEN CLUSTERS
-- =========================
for i=1,28 do
    local side=(i%2==0) and 1 or -1
    local x=side*(1200+(i%5)*90)
    local z=-450+(i*173)%900
    for j=1,3 do
        local h=90+(j%3)*20
        part("Bamboo",Vector3.new(9,h,9),CFrame.new(x+(j-2)*18,42+h/2,z+math.sin(j)*12),Enum.Material.Wood,C.grassDark,Root,false)
        for k=1,3 do
            part("BambooNode",Vector3.new(12,4,12),CFrame.new(x+(j-2)*18,42+k*h/4,z+math.sin(j)*12),Enum.Material.Grass,C.grass,Root,false)
        end
    end
end

-- =========================
-- LOBBY FLOWER BEDS / SHRUB MASSES
-- =========================
for bed=-4,4 do
    local x=bed*680
    if math.abs(x)>150 then
        part("FlowerBed",Vector3.new(360,5,105),CFrame.new(x,16,2150),Enum.Material.Grass,C.grassLight,Root,false)
        for j=1,9 do
            local fx=x-150+(j-1)*38
            local col=(j%3==0) and C.pink or ((j%3==1) and C.cream or C.gold)
            ball("FlowerCluster",Vector3.new(fx,35,2150+(j%2)*25),Vector3.new(24,18,24),col,Enum.Material.SmoothPlastic,Root,false)
        end
    end
end

-- Decorative stepping stones from lobby toward docks.
for side=-1,1,2 do
    for i=1,10 do
        local x=side*(2600-i*120)
        local z=2050-i*95
        part("DockStep",Vector3.new(60,7,45),CFrame.new(x,12,z)*CFrame.Angles(0,math.rad(side*12),0),Enum.Material.Slate,C.stoneLight,Root,true)
    end
end

-- =========================
-- POND EDGE DETAILS
-- =========================
for i=1,60 do
    local a=i*1.91
    local x=math.cos(a)*2950
    local z=math.sin(a)*2050
    ball("WaterEdgeRock",Vector3.new(x,3,z),Vector3.new(45+(i%4)*8,25,35+(i%3)*7),C.stone,Enum.Material.Slate,Root,false)
end

-- Floating flower clusters to make the pond feel alive.
for i=1,28 do
    local a=i*2.41
    local x=math.cos(a)*(1050+(i%6)*260)
    local z=math.sin(a)*(720+(i%5)*180)
    cyl("FloatingLotus",Vector3.new(x,4,z),Vector3.new(50,3,50),C.grass,Enum.Material.Grass,Root,false)
    for j=1,5 do
        local b=j*math.pi*2/5
        ball("FloatingPetal",Vector3.new(x+math.cos(b)*15,10,z+math.sin(b)*15),Vector3.new(18,6,24),C.pinkLight,Enum.Material.SmoothPlastic,Root,false)
    end
end

-- =========================
-- DECORATIVE DOCK ARCHES
-- =========================
for side=-1,1,2 do
    for k=1,2 do
        local x=side*2890
        local z=-700+k*650
        part("DockArchL",Vector3.new(14,95,14),CFrame.new(x,55,z-80),Enum.Material.Wood,C.wood,Root,true)
        part("DockArchR",Vector3.new(14,95,14),CFrame.new(x,55,z+80),Enum.Material.Wood,C.wood,Root,true)
        part("DockArchTop",Vector3.new(14,14,175),CFrame.new(x,101,z),Enum.Material.Wood,C.pink,Root,true)
    end
end

-- =========================
-- ATMOSPHERE / LIGHTING
-- =========================
Lighting.ClockTime=16.2
Lighting.Brightness=2.8
Lighting.EnvironmentDiffuseScale=0.9
Lighting.EnvironmentSpecularScale=0.65
Lighting.OutdoorAmbient=Color3.fromRGB(190,198,194)
Lighting.FogColor=Color3.fromRGB(177,210,220)
Lighting.FogStart=800
Lighting.FogEnd=9000

local atmosphere=Lighting:FindFirstChild("FrogGameAtmosphere")
if not atmosphere then
    atmosphere=Instance.new("Atmosphere")
    atmosphere.Name="FrogGameAtmosphere"
    atmosphere.Parent=Lighting
end
atmosphere.Density=0.18
atmosphere.Offset=0.15
atmosphere.Color=Color3.fromRGB(199,225,230)
atmosphere.Decay=Color3.fromRGB(120,180,175)
atmosphere.Glare=0.12
atmosphere.Haze=1.1

frogGame:SetAttribute("BeautyPass","V15")
frogGame:SetAttribute("ExtraDecoration",true)
frogGame:SetAttribute("GardenLanterns",40)
frogGame:SetAttribute("GardenBenches",4)
frogGame:SetAttribute("BeautyFlowerBeds",9)

print("FrogGame V15 beauty pass loaded: gardens, lanterns, fountain, torii, benches, mushrooms, bamboo, flower beds, rocks, lotus clusters and atmosphere")
