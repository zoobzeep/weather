--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SnowMath = require(ReplicatedStorage.Weather.Math.SnowMath)

type View = {
	Channel: StringValue,
	Changed: RBXScriptConnection?,
	State: SimulationTypes.SnowState?,
	Parts: { [number]: Part },
	Heights: { [number]: number },
	Dirty: boolean,
	Source: BasePart?,
}

local SnowController = {}
SnowController.__index = SnowController

function SnowController.new(config: SimulationTypes.SnowConfig)
	return setmetatable({
		_config = config,
		_folder = nil :: Folder?,
		_channel = nil :: Folder?,
		_connections = {} :: { RBXScriptConnection },
		_folderConnections = {} :: { RBXScriptConnection },
		_views = {} :: { [Instance]: View },
		_pool = {} :: { Part },
		_lastRender = -math.huge,
	}, SnowController)
end

function SnowController._release(self: SnowController, view: View)
	for _, part in view.Parts do
		part.Parent = nil
		table.insert(self._pool, part)
	end
	table.clear(view.Parts)
	table.clear(view.Heights)
	view.Source = nil
	view.Dirty = true
end

function SnowController._remove(self: SnowController, channel: Instance)
	local view = self._views[channel]
	if view then
		if view.Changed then
			view.Changed:Disconnect()
		end
		self:_release(view)
		self._views[channel] = nil
	end
end

function SnowController._track(self: SnowController, channel: Instance)
	if not channel:IsA("StringValue") or self._views[channel] then
		return
	end
	local view: View = { Channel = channel, Parts = {}, Heights = {}, Dirty = true }
	self._views[channel] = view
	local function receive()
		local ok, value = pcall(HttpService.JSONDecode, HttpService, channel.Value)
		if
			not ok
			or not SnowMath.IsValid(value, self._config.MaxCellsPerSurface)
			or value.Id ~= channel.Name
		then
			warn("Weather: ignored an invalid snow snapshot")
			return
		end
		local state = value :: SimulationTypes.SnowState
		if view.State and state.Revision <= view.State.Revision then
			return
		end
		if view.State and (state.Columns ~= view.State.Columns or state.Rows ~= view.State.Rows) then
			self:_release(view)
		end
		view.State = state
		view.Dirty = true
	end
	view.Changed = channel:GetPropertyChangedSignal("Value"):Connect(receive)
	receive()
end

function SnowController._unbind(self: SnowController)
	for _, connection in self._folderConnections do
		connection:Disconnect()
	end
	table.clear(self._folderConnections)
	for channel in self._views do
		self:_remove(channel)
	end
	for _, part in self._pool do
		part:Destroy()
	end
	table.clear(self._pool)
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._channel = nil
end

function SnowController._bind(self: SnowController, folder: Instance)
	if folder.Name ~= "WeatherSnow" or not folder:IsA("Folder") or folder == self._channel then
		return
	end
	self:_unbind()
	local overlays = Instance.new("Folder")
	overlays.Name = "WeatherSnowOverlays"
	overlays.Parent = Workspace
	self._folder = overlays
	self._channel = folder
	table.insert(
		self._folderConnections,
		folder.ChildAdded:Connect(function(child)
			self:_track(child)
		end)
	)
	table.insert(
		self._folderConnections,
		folder.ChildRemoved:Connect(function(child)
			self:_remove(child)
		end)
	)
	for _, child in folder:GetChildren() do
		self:_track(child)
	end
end

function SnowController.Start(self: SnowController)
	if not self._config.Enabled then
		return
	end
	assert(#self._connections == 0, "SnowController already started")
	table.insert(
		self._connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			self:_bind(child)
		end)
	)
	table.insert(
		self._connections,
		ReplicatedStorage.ChildRemoved:Connect(function(child)
			if child == self._channel then
				self:_unbind()
			end
		end)
	)
	local channel = ReplicatedStorage:FindFirstChild("WeatherSnow")
	if channel then
		self:_bind(channel)
	end
end

function SnowController._acquire(self: SnowController): Part
	local pooled = table.remove(self._pool)
	if pooled then
		return pooled
	end
	local part = Instance.new("Part")
	part.Name = "SnowCell"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Snow
	part.Color = Color3.fromRGB(245, 248, 255)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function SnowController._render(self: SnowController, view: View, part: BasePart)
	local state = view.State
	if not state or not view.Dirty then
		return
	end
	local sizeX = part.Size.X / state.Columns
	local sizeZ = part.Size.Z / state.Rows
	for index, units in state.Depths do
		local depth = units * state.Quantum
		local overlay = view.Parts[index]
		if depth < 0.005 then
			if overlay then
				overlay.Parent = nil
				table.insert(self._pool, overlay)
				view.Parts[index] = nil
				view.Heights[index] = nil
			end
		elseif view.Heights[index] ~= depth then
			if not overlay then
				overlay = self:_acquire()
				view.Parts[index] = overlay
			end
			local x = ((index - 1) % state.Columns + 0.5) * sizeX - part.Size.X / 2
			local z = (math.floor((index - 1) / state.Columns) + 0.5) * sizeZ - part.Size.Z / 2
			overlay.Size = Vector3.new(sizeX, math.max(0.05, depth), sizeZ)
			overlay.CFrame = part.CFrame * CFrame.new(x, part.Size.Y / 2 + depth - overlay.Size.Y / 2, z)
			overlay.Parent = self._folder
			view.Heights[index] = depth
		end
	end
	view.Dirty = false
end

function SnowController.Update(self: SnowController, now: number)
	if not self._folder or now - self._lastRender < 0.05 then
		return
	end
	self._lastRender = now
	local camera = Workspace.CurrentCamera
	for _, view in self._views do
		local reference = view.Channel:FindFirstChild("Surface")
		local source = if reference and reference:IsA("ObjectValue") then reference.Value else nil
		local part = if source and source:IsA("BasePart") then source else nil
		local visible = part
			and part:IsDescendantOf(Workspace)
			and camera
			and (part.Position - camera.CFrame.Position).Magnitude
				<= self._config.DrawDistance + part.Size.Magnitude / 2
		if not visible or not part then
			if next(view.Parts) then
				self:_release(view)
			end
		else
			if view.Source ~= part then
				self:_release(view)
				view.Source = part
			end
			self:_render(view, part)
		end
	end
end

function SnowController.Destroy(self: SnowController)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_unbind()
	self._lastRender = -math.huge
end

export type SnowController = typeof(SnowController.new({} :: SimulationTypes.SnowConfig))

return SnowController
