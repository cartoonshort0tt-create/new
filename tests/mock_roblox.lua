-- A hand-built Roblox API surface, covering exactly what this project's
-- server-side scripts use -- enough to actually *load and execute*
-- GameInit.server.lua and its ModuleScript dependencies outside Roblox,
-- and drive a simulated multiplayer session against them.
--
-- This is NOT a full Luau/Roblox engine simulation. It does not model
-- real physics, real replication, or real rendering -- it models just
-- enough instance/event/service surface for the *game logic* (arena
-- layout, round timing, and later the frog/doll/economy logic) to run and
-- be asserted on. A passing test here means the logic is internally
-- consistent; it is not a substitute for an actual Studio playtest.

local luauCompat = require("tests.luau_compat")

local M = {}

-- ===== Coroutine-based task scheduling =====
-- Signal:Fire spawns each connected listener as its own coroutine (as
-- real Roblox does), and task.wait yields that coroutine. The test driver
-- calls M.advancePending() to resume everything past one task.wait, and
-- M.fireDelayedTasks() to run task.delay callbacks on demand instead of
-- waiting out real seconds.

local pendingCoroutines = {}
local delayedTasks = {}

local task = {}

function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("task.spawn error: " .. tostring(err), 0)
	end
	if coroutine.status(co) ~= "dead" then
		table.insert(pendingCoroutines, co)
	end
end

function task.wait(seconds)
	coroutine.yield(seconds)
	return seconds or 0
end

function task.delay(seconds, fn)
	table.insert(delayedTasks, fn)
end

function M.advancePending()
	local resuming = pendingCoroutines
	pendingCoroutines = {}
	for _, co in ipairs(resuming) do
		if coroutine.status(co) ~= "dead" then
			local ok, err = coroutine.resume(co)
			if not ok then
				error("resumed coroutine error: " .. tostring(err), 0)
			end
			if coroutine.status(co) ~= "dead" then
				table.insert(pendingCoroutines, co)
			end
		end
	end
end

function M.fireDelayedTasks()
	local firing = delayedTasks
	delayedTasks = {}
	for _, fn in ipairs(firing) do
		fn()
	end
end

-- ===== Signal (RBXScriptSignal-alike) =====

local Signal = {}
Signal.__index = Signal

local function newSignal()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(fn)
	table.insert(self._listeners, fn)
	return { Disconnect = function() end }
end

function Signal:Fire(...)
	local args = { ... }
	for _, fn in ipairs(self._listeners) do
		task.spawn(function()
			fn(table.unpack(args))
		end)
	end
end

-- ===== Vector3 =====

local Vector3 = {}
-- A function, not a plain table, so `.Magnitude` can be a computed
-- read-only property (real Roblox Vector3s have one) instead of a static
-- field every instance would otherwise need set individually.
Vector3.__index = function(t, key)
	if key == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	end
	return Vector3[key]
end

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	elseif type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__tostring = function(v)
	return string.format("Vector3(%g, %g, %g)", v.X, v.Y, v.Z)
end

-- ===== CFrame (position + a fake "LookVector" derived from a look-at target) =====

local CFrame = {}
CFrame.__index = CFrame

local function cframeNew(x, y, z, lookVector)
	return setmetatable({
		Position = Vector3.new(x, y, z),
		X = x,
		Y = y,
		Z = z,
		LookVector = lookVector or Vector3.new(0, 0, -1),
	}, CFrame)
end

function CFrame.new(a, b, c)
	if a == nil then
		return cframeNew(0, 0, 0)
	elseif type(a) == "table" and b == nil then
		-- CFrame.new(Vector3)
		return cframeNew(a.X, a.Y, a.Z)
	elseif type(a) == "table" and type(b) == "table" then
		-- CFrame.new(posVector3, lookAtVector3)
		local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local look = len > 0 and Vector3.new(dx / len, dy / len, dz / len) or Vector3.new(0, 0, -1)
		return cframeNew(a.X, a.Y, a.Z, look)
	else
		-- CFrame.new(x, y, z)
		return cframeNew(a or 0, b or 0, c or 0)
	end
end

function CFrame.lookAt(position, lookAtTarget)
	-- Real Roblox's lookAt takes an optional up-vector too; nothing this
	-- project builds needs it, so this is just CFrame.new's two-argument
	-- form under a different name.
	return CFrame.new(position, lookAtTarget)
end

function CFrame.Angles(_, _, _)
	-- Rotation isn't modeled -- nothing in this project's tested logic
	-- reads a part's rotation, only its position and LookVector (set at
	-- construction). Returns an identity-ish CFrame so `part.CFrame *
	-- CFrame.Angles(...)` chains don't error and don't perturb position.
	return cframeNew(0, 0, 0)
end

CFrame.__mul = function(a, b)
	if getmetatable(b) == Vector3 then
		return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	-- CFrame * CFrame: positions compose additively (no real rotation
	-- math -- sufficient for this project's placement logic, which only
	-- ever offsets along world axes).
	local result = cframeNew(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.LookVector)
	return result
end

CFrame.__tostring = function(c)
	return string.format("CFrame(%g, %g, %g)", c.X, c.Y, c.Z)
end

-- ===== Color3 =====

local Color3 = {}
function Color3.new(r, g, b)
	return { R = r or 0, G = g or 0, B = b or 0 }
end
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end

-- ===== UDim / UDim2 (GUI sizing -- no arithmetic needed here, just construction) =====

local UDim = {}
function UDim.new(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim2 = {}
function UDim2.new(xScale, xOffset, yScale, yOffset)
	return {
		X = { Scale = xScale or 0, Offset = xOffset or 0 },
		Y = { Scale = yScale or 0, Offset = yOffset or 0 },
	}
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end

-- ===== Enum (auto-vivifying: Enum.Anything.Anything just works) =====

local function makeEnumMember(category, name)
	return { EnumType = category, Name = name }
end

local enumCategoryMeta = {
	__index = function(t, name)
		local member = makeEnumMember(rawget(t, "_category"), name)
		rawset(t, name, member)
		return member
	end,
}

local Enum = setmetatable({}, {
	__index = function(t, category)
		local cat = setmetatable({ _category = category }, enumCategoryMeta)
		rawset(t, category, cat)
		return cat
	end,
})

-- ===== Instance =====

local instanceMeta = {}

local INSTANCE_METHODS

local function isInstance(value)
	return type(value) == "table" and getmetatable(value) == instanceMeta
end

local function findFirstChild(self, name)
	for _, child in ipairs(self._children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function findFirstChildOfClass(self, className)
	for _, child in ipairs(self._children) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

local function findFirstAncestorOfClass(self, className)
	local current = self.Parent
	while current do
		if current.ClassName == className then
			return current
		end
		current = current.Parent
	end
	return nil
end

INSTANCE_METHODS = {
	SetAttribute = function(self, name, value)
		self._attributes[name] = value
	end,
	GetAttribute = function(self, name)
		return self._attributes[name]
	end,
	FindFirstChild = findFirstChild,
	WaitForChild = findFirstChild,
	FindFirstChildOfClass = findFirstChildOfClass,
	FindFirstAncestorOfClass = findFirstAncestorOfClass,
	GetChildren = function(self)
		local copy = {}
		for _, child in ipairs(self._children) do
			table.insert(copy, child)
		end
		return copy
	end,
	Destroy = function(self)
		if self.Parent then
			self.Parent:_removeChild(self)
		end
		self.Parent = nil
	end,
	_removeChild = function(self, child)
		for i, c in ipairs(self._children) do
			if c == child then
				table.remove(self._children, i)
				break
			end
		end
	end,
	-- Model
	PivotTo = function(self, cframe)
		if self.PrimaryPart then
			self.PrimaryPart.CFrame = cframe
		end
	end,
	-- VehicleSeat / Humanoid seating, kept for later phases
	Sit = function(self, humanoid)
		self.Occupant = humanoid
	end,
	-- RemoteEvent (server side)
	FireClient = function(self, player, data)
		self._clientEvents = self._clientEvents or {}
		table.insert(self._clientEvents, { player = player, data = data })
	end,
	FireAllClients = function(self, data)
		self._broadcastEvents = self._broadcastEvents or {}
		table.insert(self._broadcastEvents, data)
	end,
	-- Test-only: simulate a client calling RemoteEvent:FireServer(...)
	_fireServer = function(self, player, ...)
		self.OnServerEvent:Fire(player, ...)
	end,
}

local SIGNAL_PROPERTIES = {
	Touched = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	OnServerEvent = true,
	Heartbeat = true,
}

instanceMeta.__index = function(self, key)
	local method = INSTANCE_METHODS[key]
	if method then
		return method
	end

	if SIGNAL_PROPERTIES[key] then
		local signals = rawget(self, "_signals")
		if not signals[key] then
			signals[key] = newSignal()
		end
		return signals[key]
	end

	local props = rawget(self, "_properties")
	local value = props[key]
	if value ~= nil then
		return value
	end

	-- Position is a real Roblox Part property derived from CFrame, not
	-- something scripts normally set directly -- compute it on read.
	if key == "Position" and props.CFrame then
		return props.CFrame.Position
	end

	return findFirstChild(self, key)
end

instanceMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		local oldParent = rawget(self, "_properties").Parent
		if oldParent then
			oldParent:_removeChild(self)
		end
		rawget(self, "_properties").Parent = value
		if value then
			table.insert(value._children, self)
		end
		return
	end
	rawget(self, "_properties")[key] = value
end

function M.newInstance(className)
	local self = setmetatable({}, instanceMeta)
	-- Real Roblox instances always have a default CFrame (identity at the
	-- origin) even before anything sets one explicitly.
	rawset(self, "_properties", { ClassName = className, Name = className, Parent = nil, CFrame = CFrame.new(0, 0, 0) })
	rawset(self, "_children", {})
	rawset(self, "_attributes", {})
	rawset(self, "_signals", {})
	return self
end

local Instance = { new = M.newInstance }

-- ===== DataStoreService (in-memory, with copy-on-read/write semantics) =====

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function newDataStore()
	local storage = {}
	return {
		GetAsync = function(_, key)
			return deepCopy(storage[key])
		end,
		SetAsync = function(_, key, value)
			storage[key] = deepCopy(value)
		end,
	}
end

-- Test-only: lets a test reproduce the real-Roblox failure mode of an
-- unpublished place (GetDataStore throws synchronously) once a later
-- phase adds DataStore-backed persistence.
local simulateUnpublishedPlace = false
function M.simulateUnpublishedPlace(enabled)
	simulateUnpublishedPlace = enabled
end

local dataStores = {}
local DataStoreService = {
	GetDataStore = function(_, name)
		if simulateUnpublishedPlace then
			error("You must publish this place to the web to access DataStore.", 0)
		end
		if not dataStores[name] then
			dataStores[name] = newDataStore()
		end
		return dataStores[name]
	end,
}

-- ===== Players / RunService / workspace =====

local playersList = {}
local Players = M.newInstance("Players")
Players.GetPlayers = function()
	local copy = {}
	for _, p in ipairs(playersList) do
		table.insert(copy, p)
	end
	return copy
end

local RunService = M.newInstance("RunService")

local workspaceInstance = M.newInstance("Workspace")
local lightingInstance = M.newInstance("Lighting")

local services = {
	Players = Players,
	RunService = RunService,
	ReplicatedStorage = M.newInstance("ReplicatedStorage"),
	DataStoreService = DataStoreService,
	Workspace = workspaceInstance, -- same instance as the bare `workspace` global, like real Roblox
	Lighting = lightingInstance,
}

local game = {
	GetService = function(_, name)
		local service = services[name]
		if not service then
			error("mock game:GetService: unknown service '" .. tostring(name) .. "'", 0)
		end
		return service
	end,
}

-- ===== Test-facing helpers: players and characters =====

function M.newPlayer(name, userId)
	local player = { Name = name, UserId = userId, _signals = { CharacterAdded = newSignal() } }
	player.CharacterAdded = player._signals.CharacterAdded
	return player
end

function M.newCharacterFor(player)
	local character = M.newInstance("Model")
	character.Name = player.Name
	local humanoid = M.newInstance("Humanoid")
	humanoid.Parent = character
	local rootPart = M.newInstance("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Parent = character
	character.PrimaryPart = rootPart
	player.Character = character
	return character
end

function M.joinPlayer(player)
	table.insert(playersList, player)
	Players.PlayerAdded:Fire(player)
	M.advancePending()
end

function M.leavePlayer(player)
	for i, p in ipairs(playersList) do
		if p == player then
			table.remove(playersList, i)
			break
		end
	end
	Players.PlayerRemoving:Fire(player)
	M.advancePending()
end

function M.spawnCharacter(player)
	local character = M.newCharacterFor(player)
	player.CharacterAdded:Fire()
	M.advancePending() -- runs the connected handler up to its task.wait
	M.advancePending() -- resumes past that wait into the spawn logic
	return character
end

function M.fireHeartbeat()
	RunService.Heartbeat:Fire()
	M.advancePending()
end

-- ===== Controllable clock =====
-- Later phases (matchmaking-style personal timers) will need os.clock()
-- to be jumpable forward on demand instead of waited out in real time.
-- The sandboxed `os` global is this fake, controllable one instead of the
-- real module.

local fakeClockValue = 0
local mockOs = setmetatable({
	clock = function()
		return fakeClockValue
	end,
}, { __index = os })

function M.advanceClock(seconds)
	fakeClockValue = fakeClockValue + seconds
end

-- ===== Sandbox construction for loading the game's own Luau files =====

local mockTable = setmetatable({
	find = function(haystack, value, init)
		for i = init or 1, #haystack do
			if haystack[i] == value then
				return i
			end
		end
		return nil
	end,
}, { __index = table })

local sharedEnv
sharedEnv = {
	game = game,
	workspace = workspaceInstance,
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	Enum = Enum,
	task = task,
	os = mockOs,
	math = math,
	string = string,
	table = mockTable,
	pairs = pairs,
	ipairs = ipairs,
	pcall = pcall,
	xpcall = xpcall,
	error = error,
	assert = assert,
	tostring = tostring,
	tonumber = tonumber,
	type = type,
	select = select,
	print = print,
	warn = print, -- real Roblox warn() logs in orange; a plain print is fine for tests
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	next = next,
	unpack = table.unpack,
}

local moduleCache = setmetatable({}, { __mode = "k" })

local function loadInstanceScript(moduleInstance)
	if moduleCache[moduleInstance] then
		return moduleCache[moduleInstance]
	end

	local file = io.open(moduleInstance._filepath, "r")
	if not file then
		error("mock require: no such file " .. tostring(moduleInstance._filepath), 0)
	end
	local source = file:read("*a")
	file:close()

	local rewritten = luauCompat.desugarCompoundAssignment(source)

	local moduleEnv = setmetatable({ script = moduleInstance }, { __index = sharedEnv })
	moduleEnv.require = function(target)
		return loadInstanceScript(target)
	end

	local chunk, loadErr = load(rewritten, "@" .. moduleInstance._filepath, "t", moduleEnv)
	if not chunk then
		error("mock require: failed to load " .. moduleInstance._filepath .. ": " .. tostring(loadErr), 0)
	end

	local result = chunk()
	moduleCache[moduleInstance] = result
	return result
end

M.instanceMeta = instanceMeta
M.isInstance = isInstance

-- Builds a ModuleScript-like handle pointing at a real file on disk, and
-- parents it under `parent` with the given name -- mirrors what Rojo does
-- when it syncs a .lua file into the Instance tree.
function M.newModuleScript(parent, name, filepath)
	local instance = M.newInstance("ModuleScript")
	instance.Name = name
	instance._filepath = filepath
	instance.Parent = parent
	return instance
end

-- Builds a Script-like handle and RUNS it immediately (as Roblox does for
-- any Script under ServerScriptService), with `script` bound to itself.
function M.runServerScript(parent, name, filepath)
	local instance = M.newInstance("Script")
	instance.Name = name
	instance._filepath = filepath
	instance.Parent = parent
	return loadInstanceScript(instance)
end

-- Loads (and caches) any ModuleScript/Script instance built via
-- newModuleScript, with `script` bound to it. Exposed directly so a test
-- can load a single module without building a full Instance tree first.
function M.load(instance)
	return loadInstanceScript(instance)
end

M.Vector3 = Vector3
M.CFrame = CFrame
M.Color3 = Color3
M.Enum = Enum
M.Instance = Instance
M.game = game
M.workspace = workspaceInstance
M.Players = Players
M.RunService = RunService
M.ReplicatedStorage = services.ReplicatedStorage
M.Lighting = lightingInstance

return M
