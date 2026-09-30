--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)

type Splash = { Parts: { Part }, Hit: WeatherTypes.SurfaceHit, StartedAt: number }

local RainSplashes = {}
RainSplashes.__index = RainSplashes

function RainSplashes.new(config: WeatherTypes.Config)
	return setmetatable({
		_config = config.Precipitation.Splashes,
		_skyHeight = config.Precipitation.Height + config.Precipitation.SkyCheckHeight,
		_model = nil :: Model?,
		_pool = {} :: { Splash },
		_cursor = 0,
		_sample = 0,
		_budget = 0,
		_lastTime = nil :: number?,
	}, RainSplashes)
end

function RainSplashes.Start(self: RainSplashes, parent: Instance)
	if self._model or not self._config.Enabled then
		return
	end
	local model = Instance.new("Model")
	model.Name = "RainSplashes"
	model.Parent = parent
	self._model = model
end

function RainSplashes._spawn(self: RainSplashes, hit: WeatherTypes.SurfaceHit, now: number)
	self._cursor = self._cursor % self._config.MaxSplashes + 1
	local splash = self._pool[self._cursor]
	if splash then
		splash.Hit = hit
		splash.StartedAt = now
		return
	end
	local parts: { Part } = {}
	for _index = 1, 4 do
		local part = Instance.new("Part")
		part.Name = "SplashDroplet"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * self._config.Size
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(205, 225, 240)
		part.Transparency = 1
		part.Parent = self._model
		table.insert(parts, part)
	end
	self._pool[self._cursor] = { Parts = parts, Hit = hit, StartedAt = now }
end

function RainSplashes.Update(
	self: RainSplashes,
	rainRate: number,
	now: number,
	camera: CFrame?,
	probe: WeatherTypes.SurfaceProbe
)
	if not self._model then
		return
	end
	local config = self._config
	local delta = if self._lastTime then math.clamp(now - self._lastTime, 0, 0.1) else 0
	self._lastTime = now
	if camera and rainRate > 0 then
		self._budget += delta * config.Rate * math.clamp(rainRate / 180, 0, 1.5)
		local attempts = math.min(8, math.floor(self._budget))
		self._budget -= math.floor(self._budget)
		for _index = 1, attempts do
			self._sample += 1
			local angle = self._sample * 2.39996323
			local radius = math.sqrt((self._sample * 0.618033989) % 1) * config.Radius
			local origin = camera.Position
				+ Vector3.new(math.cos(angle) * radius, self._skyHeight, math.sin(angle) * radius)
			local hit = probe(origin, Vector3.new(0, -self._skyHeight - config.RayDepth, 0))
			if
				hit
				and hit.Normal.Y > 0.15
				and math.abs(hit.Position.Y - camera.Position.Y) <= config.RayDepth
			then
				self:_spawn(hit, now)
			end
		end
	else
		self._budget = 0
	end
	for _, splash in self._pool do
		local alpha = math.clamp((now - splash.StartedAt) / config.Lifetime, 0, 1)
		local normal = splash.Hit.Normal
		local axis = if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local tangent = normal:Cross(axis).Unit
		local bitangent = normal:Cross(tangent).Unit
		for index, part in splash.Parts do
			local angle = index * math.pi / 2
			local spread = (tangent * math.cos(angle) + bitangent * math.sin(angle)) * config.Spread * alpha
			local rise = normal * (0.035 + 4 * alpha * (1 - alpha) * config.Height)
			part.CFrame = CFrame.new(splash.Hit.Position + spread + rise)
			part.Transparency = if camera then 0.2 + 0.8 * alpha else 1
		end
	end
end

function RainSplashes.Destroy(self: RainSplashes)
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	table.clear(self._pool)
	self._cursor = 0
	self._sample = 0
	self._budget = 0
	self._lastTime = nil
end

export type RainSplashes = typeof(RainSplashes.new({} :: WeatherTypes.Config))

return RainSplashes
