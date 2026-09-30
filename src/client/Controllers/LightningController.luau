--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local LightningMath = require(ReplicatedStorage.Weather.Math.LightningMath)

type PendingStrike = {
	Strike: SimulationTypes.Strike,
	Model: Model?,
	SoundPart: Part?,
	Arrival: number?,
	Played: boolean,
	Shown: boolean,
}

local LightningController = {}
LightningController.__index = LightningController

local function release(pending: PendingStrike)
	if pending.Model then
		pending.Model:Destroy()
		pending.Model = nil
	end
	if pending.SoundPart then
		pending.SoundPart:Destroy()
		pending.SoundPart = nil
	end
end

function LightningController.new(config: SimulationTypes.LightningConfig)
	return setmetatable({
		_config = config,
		_channel = nil :: StringValue?,
		_changed = nil :: RBXScriptConnection?,
		_connections = {} :: { RBXScriptConnection },
		_pending = {} :: { PendingStrike },
		_flash = nil :: ColorCorrectionEffect?,
		_lastId = 0,
		_warnedSound = false,
	}, LightningController)
end

function LightningController._unbind(self: LightningController)
	if self._changed then
		self._changed:Disconnect()
		self._changed = nil
	end
	for _, pending in self._pending do
		release(pending)
	end
	table.clear(self._pending)
	if self._flash then
		self._flash:Destroy()
		self._flash = nil
	end
	self._channel = nil
	self._lastId = 0
end

function LightningController._bind(self: LightningController, channel: Instance)
	if channel.Name ~= "WeatherLightning" or not channel:IsA("StringValue") or self._channel == channel then
		return
	end
	self:_unbind()
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "WeatherLightningFlash"
	flash.Parent = Lighting
	self._flash = flash
	self._channel = channel
	local function receive()
		if channel.Value == "" then
			return
		end
		local ok, value = pcall(HttpService.JSONDecode, HttpService, channel.Value)
		if not ok or not LightningMath.IsValid(value) then
			warn("Weather: ignored an invalid lightning strike")
			return
		end
		local strike = value :: SimulationTypes.Strike
		if strike.Id <= self._lastId then
			return
		end
		self._lastId = strike.Id
		if Workspace:GetServerTimeNow() > strike.Timestamp + self._config.FlashDuration then
			return
		end
		if #self._pending >= 8 then
			local oldest = table.remove(self._pending, 1)
			if oldest then
				release(oldest)
			end
		end
		table.insert(self._pending, { Strike = strike, Played = false, Shown = false })
	end
	self._changed = channel:GetPropertyChangedSignal("Value"):Connect(receive)
	receive()
end

function LightningController.Start(self: LightningController)
	if not self._config.Enabled then
		return
	end
	assert(#self._connections == 0, "LightningController already started")
	if self._config.ThunderSoundId == "" and not self._warnedSound then
		self._warnedSound = true
		warn("Weather: Lightning.ThunderSoundId is empty; lightning will run without thunder audio")
	end
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
	local channel = ReplicatedStorage:FindFirstChild("WeatherLightning")
	if channel then
		self:_bind(channel)
	end
end

function LightningController._show(self: LightningController, strike: SimulationTypes.Strike): Model
	local model = Instance.new("Model")
	model.Name = "WeatherLightningBolt"
	for index = 1, #strike.Points - 1 do
		local a = LightningMath.Vector(strike.Points[index])
		local b = LightningMath.Vector(strike.Points[index + 1])
		local part = Instance.new("Part")
		part.Name = "Segment"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(225, 235, 255)
		part.Size = Vector3.new(self._config.Width, self._config.Width, (b - a).Magnitude)
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Parent = model
	end
	model.Parent = Workspace
	return model
end

function LightningController._play(self: LightningController, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "WeatherThunder"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	local sound = Instance.new("Sound")
	sound.SoundId = self._config.ThunderSoundId
	sound.Volume = self._config.Volume
	sound.RollOffMinDistance = math.min(20, self._config.MaxSoundDistance / 2)
	sound.RollOffMaxDistance = self._config.MaxSoundDistance
	sound.Parent = part
	part.Parent = Workspace
	sound:Play()
	return part
end

function LightningController.Update(self: LightningController, now: number)
	local brightness = 0
	for index = #self._pending, 1, -1 do
		local pending = self._pending[index]
		local strike = pending.Strike
		local age = now - strike.Timestamp
		local position = LightningMath.Position(strike)
		local camera = Workspace.CurrentCamera
		if not pending.Arrival and camera then
			local distance = (position - camera.CFrame.Position).Magnitude
			pending.Arrival = LightningMath.Arrival(
				position,
				camera.CFrame.Position,
				strike.Timestamp,
				self._config.SoundSpeed
			)
			pending.Played = distance > self._config.MaxSoundDistance or self._config.ThunderSoundId == ""
		end
		if age >= 0 and age < self._config.FlashDuration then
			if not pending.Shown then
				pending.Model = self:_show(strike)
				pending.Shown = true
			end
			brightness =
				math.max(brightness, self._config.FlashBrightness * (1 - age / self._config.FlashDuration))
		elseif age >= self._config.FlashDuration and pending.Model then
			pending.Model:Destroy()
			pending.Model = nil
		end
		local arrival = pending.Arrival
		if arrival and now >= arrival and not pending.Played then
			pending.Played = true
			if now - arrival < 1 then
				pending.SoundPart = self:_play(position)
			end
		end
		local expires = if arrival then arrival + self._config.SoundLifetime else strike.Timestamp + 2
		if
			now > expires or (pending.Played and not pending.SoundPart and age > self._config.FlashDuration)
		then
			release(pending)
			table.remove(self._pending, index)
		end
	end
	if self._flash then
		self._flash.Brightness = brightness
	end
end

function LightningController.Destroy(self: LightningController)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_unbind()
end

export type LightningController = typeof(LightningController.new({} :: SimulationTypes.LightningConfig))

return LightningController
