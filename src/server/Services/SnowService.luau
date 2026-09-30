--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SnowSurface = require(script.Parent.Parent.Simulation.Snow.SnowSurface)
local SnowGrid = require(script.Parent.Parent.Simulation.Snow.SnowGrid)
local FootstepTracker = require(script.Parent.Parent.Simulation.Snow.FootstepTracker)

type Entry = { Grid: SnowGrid.SnowGrid, Channel: StringValue }
type Walker = { Character: Model, Tracker: FootstepTracker.FootstepTracker }

local SnowService = {}
SnowService.__index = SnowService

function SnowService.new(config: SimulationTypes.SnowConfig)
	return setmetatable({
		_config = config,
		_folder = nil :: Folder?,
		_entries = {} :: { [BasePart]: Entry },
		_walkers = {} :: { [Player]: Walker },
		_connections = {} :: { RBXScriptConnection },
		_nextId = 0,
		_cellCount = 0,
		_lastSimulation = 0,
		_lastPublish = 0,
		_lastSteps = 0,
	}, SnowService)
end

function SnowService._remove(self: SnowService, part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local entry = self._entries[part]
	if entry then
		self._cellCount -= entry.Grid.Surface.Columns * entry.Grid.Surface.Rows
		entry.Channel:Destroy()
		self._entries[part] = nil
	end
end

function SnowService._add(self: SnowService, instance: Instance)
	if not self._folder or (instance:IsA("BasePart") and self._entries[instance]) then
		return
	end
	self._nextId += 1
	local ok, result = pcall(SnowSurface.Read, instance, tostring(self._nextId), self._config)
	if not ok then
		warn(`Weather: ignoring SnowSurface {instance:GetFullName()}: {result}`)
		return
	end
	local surface = result :: SimulationTypes.Surface
	local count = surface.Columns * surface.Rows
	if self._cellCount + count > self._config.MaxTotalCells then
		warn(`Weather: ignoring SnowSurface {instance:GetFullName()}: MaxTotalCells exceeded`)
		return
	end
	local part = instance :: BasePart
	local grid = SnowGrid.new(surface, self._config)
	local channel = Instance.new("StringValue")
	channel.Name = surface.Id
	channel.Value = HttpService:JSONEncode(grid:Snapshot(true))
	local reference = Instance.new("ObjectValue")
	reference.Name = "Surface"
	reference.Value = part
	reference.Parent = channel
	self._entries[part] = { Grid = grid, Channel = channel }
	self._cellCount += count
	channel.Parent = self._folder
end

function SnowService.Start(self: SnowService, startedAt: number?)
	if not self._config.Enabled then
		return
	end
	assert(
		not self._folder and not ReplicatedStorage:FindFirstChild("WeatherSnow"),
		"WeatherSnow already exists"
	)
	local folder = Instance.new("Folder")
	folder.Name = "WeatherSnow"
	self._folder = folder
	folder.Parent = ReplicatedStorage
	local now = startedAt or Workspace:GetServerTimeNow()
	self._lastSimulation = now
	self._lastPublish = now
	self._lastSteps = now
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal("SnowSurface"):Connect(function(part)
			self:_add(part)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal("SnowSurface"):Connect(function(part)
			self:_remove(part)
		end)
	)
	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player)
			self._walkers[player] = nil
		end)
	)
	local surfaces = CollectionService:GetTagged("SnowSurface")
	table.sort(surfaces, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	for _, part in surfaces do
		self:_add(part)
	end
end

function SnowService._steps(self: SnowService, now: number): boolean
	local footprintChanged = false
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			self._walkers[player] = nil
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			continue
		end
		local walker = self._walkers[player]
		if not walker or walker.Character ~= character then
			local nextWalker: Walker = { Character = character, Tracker = FootstepTracker.new(self._config) }
			self._walkers[player] = nextWalker
			walker = nextWalker
		end
		local state = humanoid:GetState()
		local grounded = humanoid.Health > 0
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics)
		local direction, side = walker.Tracker:Observe(root.Position, now, grounded)
		if not direction then
			continue
		end
		local right = direction:Cross(Vector3.yAxis)
		local origin = root.Position + right * self._config.StepOffset * side
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		local reach = math.min(8, humanoid.HipHeight + root.Size.Y / 2 + 2)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -reach, 0), parameters)
		local entry = if hit and hit.Instance:IsA("BasePart") then self._entries[hit.Instance] else nil
		if hit and entry and hit.Normal:Dot(Vector3.yAxis) > 0.999 then
			footprintChanged = entry.Grid:Footprint(hit.Position, direction) > 0 or footprintChanged
		end
	end
	return footprintChanged
end

function SnowService.Update(
	self: SnowService,
	now: number,
	sample: (number) -> SimulationTypes.SnowForcing
): boolean
	if not self._folder then
		return true
	end
	local elapsed = self._config.SimulationInterval
	for _index = 1, 128 do
		if self._lastSimulation + elapsed > now then
			break
		end
		self._lastSimulation += elapsed
		local forcing = sample(self._lastSimulation)
		for part, entry in self._entries do
			local surface = entry.Grid.Surface
			if
				not part:IsA("Part")
				or part.Shape ~= Enum.PartType.Block
				or not part:IsDescendantOf(Workspace)
				or not part.Anchored
				or part.CFrame ~= surface.Frame
				or part.Size ~= surface.Size
				or not part.CanQuery
				or not part.CanCollide
			then
				self:_remove(part)
				warn(`Weather: removed changed SnowSurface {part.Name}; re-tag it after editing`)
			else
				entry.Grid:Advance(elapsed, forcing)
			end
		end
	end
	if self._lastSimulation + elapsed <= now then
		return false
	end
	local footprintChanged = false
	if now - self._lastSteps >= 0.05 then
		self._lastSteps = now
		footprintChanged = self:_steps(now)
	end
	if footprintChanged or now - self._lastPublish >= self._config.ReplicationInterval then
		self._lastPublish = now
		for _, entry in self._entries do
			local snapshot = entry.Grid:Snapshot()
			if snapshot then
				entry.Channel.Value = HttpService:JSONEncode(snapshot)
			end
		end
	end
	return true
end

function SnowService.Destroy(self: SnowService)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._entries)
	table.clear(self._walkers)
	self._cellCount = 0
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
end

export type SnowService = typeof(SnowService.new({} :: SimulationTypes.SnowConfig))

return SnowService
