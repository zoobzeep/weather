--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)

type Particle = {
	Part: Part,
	Floor: number,
	SampleAt: number,
	SamplePosition: Vector3,
	SpeedFrom: number,
	SpeedTo: number,
	SpeedStartedAt: number,
	CycleOffset: number,
}

local PrecipitationField = {}
PrecipitationField.__index = PrecipitationField

local function fraction(value: number): number
	return value - math.floor(value)
end

local function wrap(value: number, center: number, size: number): number
	return center + (value - center + size / 2) % size - size / 2
end

function PrecipitationField.new(config: WeatherTypes.Config)
	return setmetatable({
		_config = config.Precipitation,
		_model = nil :: Model?,
		_particles = {} :: { Particle },
	}, PrecipitationField)
end

function PrecipitationField.Start(self: PrecipitationField, parent: Instance)
	if self._model then
		return
	end
	local model = Instance.new("Model")
	model.Name = "PrecipitationField"
	model.Parent = parent
	self._model = model
end

function PrecipitationField._particle(
	self: PrecipitationField,
	index: number,
	speed: number,
	cycleOffset: number,
	now: number
): Particle
	local particle = self._particles[index]
	if particle then
		return particle
	end
	local part = Instance.new("Part")
	part.Name = "Drop"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Parent = self._model
	local created = {
		Part = part,
		Floor = -math.huge,
		SampleAt = -math.huge,
		SamplePosition = Vector3.zero,
		SpeedFrom = speed,
		SpeedTo = speed,
		SpeedStartedAt = now,
		CycleOffset = cycleOffset,
	}
	self._particles[index] = created
	return created
end

local function speedAt(particle: Particle, now: number, transitionTime: number): number
	local alpha = math.clamp((now - particle.SpeedStartedAt) / transitionTime, 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	return particle.SpeedFrom + (particle.SpeedTo - particle.SpeedFrom) * alpha
end

local function distanceAt(particle: Particle, now: number, transitionTime: number): number
	local elapsed = math.max(0, now - particle.SpeedStartedAt)
	local transitioning = math.min(elapsed, transitionTime)
	local alpha = transitioning / transitionTime
	local easedIntegral = alpha ^ 3 - alpha ^ 4 * 0.5
	local transitionDistance = particle.SpeedFrom * transitioning
		+ (particle.SpeedTo - particle.SpeedFrom) * transitionTime * easedIntegral
	return transitionDistance + particle.SpeedTo * math.max(0, elapsed - transitionTime)
end

function PrecipitationField.Update(
	self: PrecipitationField,
	rainRate: number,
	snowRate: number,
	wind: Vector3,
	now: number,
	camera: CFrame?,
	probe: WeatherTypes.SurfaceProbe
)
	if not self._model then
		return
	end
	local config = self._config
	local rainDemand = math.max(0, rainRate) * config.Height * 2 / config.RainSpeed
	local snowDemand = math.max(0, snowRate) * config.Height * 2 / config.SnowSpeed
	local totalDemand = rainDemand + snowDemand
	local desired = math.ceil(totalDemand)
	local count = if camera then math.min(config.MaxParticles, desired) else 0
	local rainFraction = if totalDemand > 0 then rainDemand / totalDemand else 0
	local center = if camera then camera.Position else Vector3.zero
	local drift = Vector3.new(wind.X, 0, wind.Z) * config.WindInfluence
	for index = 1, count do
		local typePhase = fraction(index * 0.754877666)
		local speedPhase = fraction(index * 0.569840296)
		local verticalPhase = fraction(index * 0.819172513)
		local rain = typePhase < rainFraction
		local variation = 1 + (speedPhase * 2 - 1) * config.SpeedVariation
		local speed = (if rain then config.RainSpeed else config.SnowSpeed) * variation
		local particle = self:_particle(index, speed, verticalPhase * config.Height * 2, now)
		local part = particle.Part
		local name = if rain then "Rain" else "Snow"
		if part.Name ~= "Drop" and part.Name ~= name then
			particle.CycleOffset = part.CFrame.Position.Y - center.Y
			particle.SpeedFrom = speedAt(particle, now, config.SpeedTransitionTime)
			particle.SpeedTo = speed
			particle.SpeedStartedAt = now
		end
		local currentSpeed = speedAt(particle, now, config.SpeedTransitionTime)
		local sway = if rain then 0 else math.sin(now * 1.7 + index) * 0.7
		local position = Vector3.new(
			wrap(
				fraction(index * 0.618033989) * config.AreaSize + drift.X * now + sway,
				center.X,
				config.AreaSize
			),
			wrap(
				center.Y + particle.CycleOffset - distanceAt(particle, now, config.SpeedTransitionTime),
				center.Y,
				config.Height * 2
			),
			wrap(fraction(index * 0.414213562) * config.AreaSize + drift.Z * now, center.Z, config.AreaSize)
		)
		local origin = Vector3.new(position.X, center.Y + config.Height + config.SkyCheckHeight, position.Z)
		if now >= particle.SampleAt or (origin - particle.SamplePosition).Magnitude > 8 then
			local direction = Vector3.new(0, -config.SkyCheckHeight - config.Height * 2, 0)
			local hit = probe(origin, direction)
			particle.Floor = if hit then hit.Position.Y else -math.huge
			particle.SamplePosition = origin
			particle.SampleAt = now + config.OcclusionInterval * (0.75 + verticalPhase * 0.25)
		end
		local size = if rain then 0.035 else 0.12 + speedPhase * 0.1
		local length = if rain then 1.5 else size
		if part.Name ~= name then
			part.Name = name
			part.Shape = if rain then Enum.PartType.Block else Enum.PartType.Ball
			part.Color = if rain then Color3.fromRGB(185, 210, 230) else Color3.fromRGB(245, 248, 255)
			part.Size = Vector3.new(size, size, length)
		end
		part.CFrame = CFrame.lookAt(position, position + drift - Vector3.new(0, currentSpeed, 0))
		local distance = (position - center).Magnitude
		local visible = position.Y - length / 2 > particle.Floor and distance > 1.5
		local fade = math.clamp((distance - config.AreaSize * 0.78) / (config.AreaSize * 0.17), 0, 1)
		local opacity = if rain then 0.6 else 0.95
		part.Transparency = if visible then 1 - opacity * (1 - fade) else 1
	end
	for index = count + 1, #self._particles do
		self._particles[index].Part.Transparency = 1
	end
end

function PrecipitationField.Destroy(self: PrecipitationField)
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	table.clear(self._particles)
end

export type PrecipitationField = typeof(PrecipitationField.new({} :: WeatherTypes.Config))

return PrecipitationField
