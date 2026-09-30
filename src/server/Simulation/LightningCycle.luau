--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local WeatherRandom = require(script.Parent.WeatherRandom)

local LightningCycle = {}
LightningCycle.__index = LightningCycle

function LightningCycle.new(config: SimulationTypes.LightningConfig, seed: number)
	return setmetatable({
		_config = config,
		_random = WeatherRandom.new((seed + 104729) % 2147483646 + 1),
		_due = nil :: number?,
		_stormEndsAt = nil :: number?,
		_severe = false,
		_id = 0,
	}, LightningCycle)
end

function LightningCycle.IsDue(
	self: LightningCycle,
	now: number,
	stormEndsAt: number?,
	severe: boolean?
): boolean
	if not self._config.Enabled or not stormEndsAt or now + self._config.LeadTime >= stormEndsAt then
		self._due = nil
		self._stormEndsAt = nil
		self._severe = false
		return false
	end
	local isSevere = severe == true
	if self._stormEndsAt ~= stormEndsAt or self._severe ~= isSevere then
		self._stormEndsAt = stormEndsAt
		self._severe = isSevere
		local delay = if isSevere then self._config.SevereFirstStrikeDelay else self._config.FirstStrikeDelay
		self._due = now + delay
	elseif not self._due then
		local minimum = if isSevere then self._config.SevereMinInterval else self._config.MinInterval
		local maximum = if isSevere then self._config.SevereMaxInterval else self._config.MaxInterval
		self._due = now + minimum + self._random:NextNumber() * (maximum - minimum)
	end
	local due = self._due
	assert(due)
	if now < due then
		return false
	end
	self._due = nil
	return true
end

function LightningCycle.ChoosePosition(self: LightningCycle, anchor: Vector3): Vector3
	local angle = self._random:NextNumber() * math.pi * 2
	local radius = math.sqrt(self._random:NextNumber()) * self._config.Radius
	return anchor + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function LightningCycle.CreateStrike(
	self: LightningCycle,
	position: Vector3,
	now: number
): SimulationTypes.Strike
	self._id += 1
	local points: { { number } } = {}
	for index = 0, self._config.Segments do
		local alpha = index / self._config.Segments
		local jitter = if index == 0 or index == self._config.Segments then 0 else self._config.Jitter
		local x = position.X + (self._random:NextNumber() * 2 - 1) * jitter
		local z = position.Z + (self._random:NextNumber() * 2 - 1) * jitter
		table.insert(points, { x, position.Y + self._config.Height * (1 - alpha), z })
	end
	return {
		Version = 1,
		Id = self._id,
		Timestamp = now + self._config.LeadTime,
		Position = { position.X, position.Y, position.Z },
		Points = points,
	}
end

export type LightningCycle = typeof(setmetatable({
	_config = {} :: SimulationTypes.LightningConfig,
	_random = WeatherRandom.new(1),
	_due = nil :: number?,
	_stormEndsAt = nil :: number?,
	_severe = false,
	_id = 0,
}, LightningCycle))

return LightningCycle
