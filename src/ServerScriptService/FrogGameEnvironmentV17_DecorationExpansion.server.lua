-- Frog Game Environment V17
-- DECORATION EXPANSION PASS
-- Adds a richer frog/japanese garden identity without changing the pond footprint.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local frogGame = Workspace:WaitForChild("FrogGame", 30)
if not frogGame then return end
local map = frogGame:WaitForChild("ReferenceLayoutV13", 30)
if not map then return end
local decor = map:FindFirstChild("BeautyDecor")
if not decor then
    decor = Instance.new("Folder")
    decor.Name = "BeautyDecor"
    decor.Parent = map
end

local old = decor:FindFirstChild("V17Generated")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "V17Generated"
root.Parent = decor

local C = {
    stone = Color3.fromRGB(110,116,108),
    stoneLight = Color3.fromRGB(196,190,164),
    stoneDark = Color3.fromRGB(55,64,58),
    grass = Color3.fromRGB(62,137,61),
    grassDark = Color3.fromRGB(34,93,42),
    leaf = Color3.fromRGB(78,155,68),
    wood = Color3.fromRGB(105,68,38),
    woodDark = Color3.fromRGB(55,38,26),
    pink = Color3.fromRGB(246,142,190),
    pink2 = Color3.fromRGB(255,194,219),
    cream = Color3.fromRGB(255,239,192),
    gold = Color3.fromRGB(255,190,70),
    frog = Color3.fromRGB(72,148,72),
    frogDark = Color3.fromRGB(38,103,48),
    water = Color3.fromRGB(30,145,190),
    red = Color3.fromRGB(174,54,55),
}

local function part(name,size,cf,material,color,parent,collide)
    local p=Instance.new("Part")
    p.Name=name
    p.Size=size
    p.CFrame=cf
    p.Anchored=true
    p.Material=material or Enum.Material.SmoothPlastic
    p.Color=color or C.stone
    p.TopSurface=Enum.SurfaceType.Smooth
    p.BottomSurface=Enum.SurfaceType.Smooth
    p.CanCollide=collide == true
    p.CanTouch=false
    p.CanQuery=collide == true
    p.Parent=parent or root
    return p
end

local function ball(name,pos,size,color,material,parent,collide)
    local p=part(name,size,CFrame.new(pos),material,color,parent,collide)
    p.Shape=Enum.PartType.Ball
    return p
end

local function cyl(name,pos,size,color,material,parent,collide,yaw)
    local p=part(name,size,CFrame.new(pos)*CFrame.Angles(0,yaw or 0,math.rad(90)),material,color,parent,collide)
    p.Shape=Enum.PartType.Cylinder
    return p
end

local function beamBetween(name,a,b,width,color,material,parent)
    local mid=(a+b)/2
    local len=(b-a).Magnitude
    return part(name,Vector3.new(width,width,len),CFrame.lookAt(mid,b),material,color,parent,false)
end

-- =========================
-- GRAND FROG STATUE PLAZA
-- =========================
-- A second, larger landmark gives the island a memorable center without blocking play.
cyl("FrogPlazaBase",Vector3.new(0,18,-160),Vector3.new(310,14,310),C.stone,Enum.Material.Slate,root,false)
cyl("FrogPlazaInset",Vector3.new(0,26,-160),Vector3.new(245,5,245),C.stoneLight,Enum.Material.Slate,root,false)

ball("FrogStatueBody",Vector3.new(0,92,-160),Vector3.new(150,105,135),C.frog,Enum.Material.SmoothPlastic,root,false)
ball("FrogStatueHead",Vector3.new(0,145,-160),Vector3.new(145,90,125),C.frog,Enum.Material.SmoothPlastic,root,false)
ball("FrogEyeL",Vector3.new(-43,190,-184),Vector3.new(38,38,38),C.cream,Enum.Material.SmoothPlastic,root,false)
ball("FrogEyeR",Vector3.new(43,190,-184),Vector3.new(38,38,38),C.cream,Enum.Material.SmoothPlastic,root,false)
ball("FrogPupilL",Vector3.new(-43,192,-203),Vector3.new(17,22,17),C.stoneDark,Enum.Material.SmoothPlastic,root,false)
ball("FrogPupilR",Vector3.new(43,192,-203),Vector3.new(17,22,17),C.stoneDark,Enum.Material.SmoothPlastic,root,false)
ball("FrogCheekL",Vector3.new(-55,150,-221),Vector3.new(27,18,27),C.pink,Enum.Material.SmoothPlastic,root,false)
ball("FrogCheekR",Vector3.new(55,150,-221),Vector3.new(27,18,27),C.pink,Enum.Material.SmoothPlastic,root,false)
part("FrogMouth",Vector3.new(72,7,7),CFrame.new(0,145,-226),Enum.Material.SmoothPlastic,C.frogDark,root,false)

-- Small stone lamps around the plaza.
local function stoneLamp(x,z)
    cyl("StoneLampBase",Vector3.new(x,34,z),Vector3.new(48,9,48),C.stoneDark,Enum.Material.Slate,root,false)
    part("StoneLampColumn",Vector3.new(14,58,14),CFrame.new(x,65,z),Enum.Material.Slate,C.stone,root,false)
    part("StoneLampCap",Vector3.new(48,10,48),CFrame.new(x,96,z),Enum.Material.Slate,C.stoneLight,root,false)
    ball("StoneLampGlow",Vector3.new(x,86,z),Vector3.new(20,20,20),C.gold,Enum.Material.Neon,root,false)
end
for _,p in ipairs({{-150,-160},{150,-160},{-125,-330},{125,-330}}) do stoneLamp(p[1],p[2]) end

-- =========================
-- SAKURA ARCH WALK
-- =========================
-- Curved decorative arches frame the main garden routes.
local function sakuraArch(x,z,yaw)
    local cf=CFrame.new(x,0,z)*CFrame.Angles(0,yaw,0)
    part("ArchPostL",Vector3.new(18,130,18),cf*CFrame.new(-105,75,0),Enum.Material.Wood,C.wood,true)
    part("ArchPostR",Vector3.new(18,130,18),cf*CFrame.new(105,75,0),Enum.Material.Wood,C.wood,true)
    part("ArchBeam",Vector3.new(250,20,20),cf*CFrame.new(0,138,0),Enum.Material.Wood,C.red,true)
    part("ArchBeamTop",Vector3.new(285,12,22),cf*CFrame.new(0,160,0),Enum.Material.Wood,C.woodDark,true)
    for _,sx in ipairs({-82,-48,48,82}) do
        ball("CherryBloom",(cf*CFrame.new(sx,168,0)).Position,Vector3.new(28,22,28),C.pink2,Enum.Material.SmoothPlastic,root,false)
    end
end
sakuraArch(0,520,0)
sakuraArch(-650,-180,math.rad(90))
sakuraArch(650,-180,math.rad(-90))

-- =========================
-- MINI PAGODA GAZEBO
-- =========================
local gazebo=Instance.new("Model")
gazebo.Name="GardenGazebo"
gazebo.Parent=root
for i=1,6 do
    local a=(i-1)*math.pi/3
    local x,z=math.cos(a)*230,520+math.sin(a)*230
    part("GazeboPost",Vector3.new(16,145,16),CFrame.new(x,80,z),Enum.Material.Wood,C.wood,gazebo,false)
end
cyl("GazeboFloor",Vector3.new(0,18,520),Vector3.new(470,10,470),C.woodDark,Enum.Material.Wood,gazebo,false)
cyl("GazeboRoof",Vector3.new(0,174,520),Vector3.new(510,22,510),C.red,Enum.Material.Wood,gazebo,false)
cyl("GazeboRoofTop",Vector3.new(0,194,520),Vector3.new(360,14,360),C.woodDark,Enum.Material.Wood,gazebo,false)
part("GazeboFinial",Vector3.new(14,55,14),CFrame.new(0,224,520),Enum.Material.Wood,C.gold,gazebo,false)

-- =========================
-- WATER GARDEN EXPANSION
-- =========================
-- More normal-size lily pads and tiny flower clusters, spread widely so the huge pond feels alive.
for i=1,55 do
    local a=i*2.399
    local rx=900+(i%8)*220
    local rz=580+(i%7)*185
    local x=math.cos(a)*rx
    local z=math.sin(a)*rz
    cyl("ExtraLilyPad",Vector3.new(x,3.5,z),Vector3.new(58+(i%4)*8,4,58+(i%4)*8),C.grass,Enum.Material.Grass,root,false)
    ball("LilyFlower",Vector3.new(x+math.cos(a)*9,10,z+math.sin(a)*9),Vector3.new(18,7,18),(i%2==0) and C.pink2 or C.cream,Enum.Material.SmoothPlastic,root,false)
end

-- Cattail clusters around the shoreline.
for i=1,38 do
    local a=i*2.73
    local x=math.cos(a)*2850
    local z=math.sin(a)*1980
    for j=1,3 do
        local dx=(j-2)*12
        part("CattailLeaf",Vector3.new(5,80+(j%2)*20,5),CFrame.new(x+dx,42,z+math.sin(j)*10)*CFrame.Angles(0,0,math.rad((j-2)*7)),Enum.Material.Grass,C.grassDark,root,false)
        cyl("CattailHead",Vector3.new(x+dx,91+(j%2)*20,z+math.sin(j)*10),Vector3.new(12,5,12),C.woodDark,Enum.Material.SmoothPlastic,root,false)
    end
end

-- Decorative koi/fish silhouettes close to the water surface.
local function fish(x,z,scale,flip)
    local y=4.8
    local yaw=flip and math.pi or 0
    ball("KoiBody",Vector3.new(x,y,z),Vector3.new(62*scale,11*scale,24*scale),C.gold,Enum.Material.SmoothPlastic,root,false)
    ball("KoiHead",Vector3.new(x+(flip and -28 or 28)*scale,y,z),Vector3.new(27*scale,15*scale,25*scale),C.cream,Enum.Material.SmoothPlastic,root,false)
    local tailX=x+(flip and 45 or -45)*scale
    local tail=part("KoiTail",Vector3.new(34*scale,5*scale,40*scale),CFrame.new(tailX,y,z)*CFrame.Angles(0,yaw,math.rad(28)),Enum.Material.SmoothPlastic,C.pink,root,false)
    tail.Shape=Enum.PartType.Wedge
end
for i=1,18 do
    local a=i*3.14
    fish(math.cos(a)*(1250+(i%4)*350),math.sin(a)*(850+(i%5)*160),0.65+(i%3)*0.12,i%2==0)
end

-- =========================
-- GARDEN STONE BORDERS
-- =========================
local function borderLine(x,z,count,dx,dz)
    for i=1,count do
        local px=x+(i-1)*dx
        local pz=z+(i-1)*dz
        ball("BorderStone",Vector3.new(px,22,pz),Vector3.new(38,18,30),C.stone,Enum.Material.Slate,root,false)
        if i%2==0 then
            ball("BorderMoss",Vector3.new(px+4,30,pz-2),Vector3.new(22,7,18),C.grass,Enum.Material.Grass,root,false)
        end
    end
end
borderLine(-820,650,17,100,0)
borderLine(-820,-720,17,100,0)
borderLine(-820,650,12,0,100)
borderLine(780,-720,12,0,100)

-- =========================
-- PAPER LANTERN STRING LIGHTS
-- =========================
local function paperLantern(x,y,z,parent)
    ball("PaperLantern",Vector3.new(x,y,z),Vector3.new(22,30,22),C.cream,Enum.Material.Neon,parent,false)
    local light=Instance.new("PointLight")
    light.Brightness=0.65
    light.Range=12
    light.Color=C.gold
    light.Parent=parent:FindFirstChild("PaperLantern")
end
for row=-2,2 do
    local z=520+row*28
    for i=-7,7 do
        local x=i*105
        if math.abs(i)%2==0 then paperLantern(x,112+math.abs(i%3)*8,z,root) end
    end
end

-- =========================
-- FROG GARDEN SIGNPOSTS
-- =========================
local function signpost(x,z,text)
    local m=Instance.new("Model")
    m.Name="GardenSign"
    m.Parent=root
    part("SignPost",Vector3.new(10,72,10),CFrame.new(x,48,z),Enum.Material.Wood,C.wood,m,false)
    part("SignBoard",Vector3.new(100,38,8),CFrame.new(x,82,z),Enum.Material.Wood,C.woodDark,m,false)
    local gui=Instance.new("SurfaceGui")
    gui.Face=Enum.NormalId.Front
    gui.CanvasSize=Vector2.new(400,150)
    gui.Parent=m.SignBoard
    local label=Instance.new("TextLabel")
    label.Size=UDim2.fromScale(1,1)
    label.BackgroundTransparency=1
    label.Text=text
    label.TextScaled=true
    label.Font=Enum.Font.GothamBold
    label.TextColor3=C.cream
    label.Parent=gui
end
signpost(-500,720,"FROG GARDEN")
signpost(500,720,"LOTUS POND")
signpost(-1050,-400,"SAKURA GROVE")
signpost(1050,-400,"DOCKS")

-- =========================
-- FIREFLY / AMBIENT GLOW FIELD
-- =========================
for i=1,70 do
    local a=i*4.17
    local r=450+(i%9)*100
    local x=math.cos(a)*r
    local z=math.sin(a)*r*0.72
    local y=45+(i%7)*11
    ball("Firefly",Vector3.new(x,y,z),Vector3.new(5,5,5),C.gold,Enum.Material.Neon,root,false)
end

-- =========================
-- EXTRA ROCK + FLOWER MICRO-DETAILS
-- =========================
for i=1,80 do
    local a=i*1.71
    local r=900+(i%10)*80
    local x=math.cos(a)*r
    local z=math.sin(a)*r*0.66
    ball("MicroRock",Vector3.new(x,20,z),Vector3.new(18+(i%3)*8,10+(i%4)*4,15+(i%3)*6),C.stone,Enum.Material.Slate,root,false)
    for j=1,2 do
        ball("MicroFlower",Vector3.new(x+(j*11-16),30+(j%2)*5,z+9),Vector3.new(11,9,11),(j+i)%2==0 and C.pink or C.cream,Enum.Material.SmoothPlastic,root,false)
    end
end

-- Slightly richer atmosphere while keeping gameplay readable.
Lighting.Brightness = math.max(Lighting.Brightness, 2)
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.55

map:SetAttribute("DecorationExpansionV17", true)
map:SetAttribute("DecorationTheme", "FrogGardenJapanese")
print("FrogGame V17 decoration expansion loaded")
