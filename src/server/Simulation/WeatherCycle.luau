--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)
local WeatherValidation = require(ReplicatedStorage.Weather.Validation.WeatherValidation)
local WeatherBlend = require(ReplicatedStorage.Weather.Math.WeatherBlend)
local WeatherRandom = require(script.Parent.WeatherRandom)

local WeatherCycle = {}
WeatherCycle.__index = WeatherCycle

function WeatherCycle.Select(
	definitions: { WeatherTypes.Definition },
	current: string,
	allowRepeats: boolean,
	roll: number
): WeatherTypes.Definition
	assert(roll >= 0 and roll < 1, "Weather roll must be in [0, 1)")
	local total = 0
	for _, definition in definitions do
		if allowRepeats or definition.Id ~= current then
			total += definition.Weight
		end
	end
	assert(total > 0, "No eligible weather has a positive weight")
	local threshold = roll * total
	local last: WeatherTypes.Definition? = nil
	for _, definition in definitions do
		if definition.Weight > 0 and (allowRepeats or definition.Id ~= current) then
			last = definition
			threshold -= definition.Weight
			if threshold < 0 then
				return definition
			end
		end
	end
	assert(last)
	return last
end

function WeatherCycle._schedule(self: WeatherCycle, now: number, durationOverride: number?)
	local current = self._definitions[self._current]
	local duration: number
	if durationOverride then
		duration = durationOverride
	else
		local durationRoll = self._random:NextNumber()
		duration = current.MinDuration + (current.MaxDuration - current.MinDuration) * durationRoll
	end
	local nextWeather = WeatherCycle.Select(
		self._config.Definitions,
		self._current,
		self._config.AllowRepeats,
		self._random:NextNumber()
	)
	self._next = nextWeather.Id
	self._startedAt = now
	self._transitionAt = now + duration
	self._endsAt = self._transitionAt + nextWeather.TransitionTime
end

function WeatherCycle.new(config: WeatherTypes.Config, now: number, fallbackSeed: number?)
	local validated = WeatherValidation.Validate(config)
	local seed = validated.Seed or fallbackSeed
	assert(seed and seed % 1 == 0 and seed >= 1 and seed <= 2147483646, "A valid seed is required")
	local definitions: { [string]: WeatherTypes.Definition } = {}
	for _, definition in validated.Definitions do
		definitions[definition.Id] = definition
	end
	local self: WeatherCycle = setmetatable({
		_config = validated,
		_definitions = definitions,
		_random = WeatherRandom.new(seed),
		_seed = seed,
		_current = validated.InitialWeather,
		_next = validated.InitialWeather,
		_sequence = 1,
		_startedAt = now,
		_transitionAt = now,
		_endsAt = now,
		_fromEnvironment = nil :: WeatherTypes.Environment?,
		_forcedHoldDuration = nil :: number?,
	}, WeatherCycle)
	self:_schedule(now)
	return self
end

function WeatherCycle.Advance(self: WeatherCycle, now: number): boolean
	for _index = 1, 128 do
		if now < self._endsAt then
			return true
		end
		self._current = self._next
		self._sequence += 1
		self._fromEnvironment = nil
		local forcedHoldDuration = self._forcedHoldDuration
		self._forcedHoldDuration = nil
		self:_schedule(self._endsAt, forcedHoldDuration)
	end
	return now < self._endsAt
end

function WeatherCycle.ForceWeather(self: WeatherCycle, weatherId: string, now: number, holdDuration: number)
	local target = self._definitions[weatherId]
	assert(target, `Unknown weather: {weatherId}`)
	assert(holdDuration >= 0.1 and holdDuration <= 86400, "Hold duration must be between 0.1 and 86400")
	local fromEnvironment = self:GetEnvironment(now)
	self._next = weatherId
	self._startedAt = now
	self._transitionAt = now
	self._endsAt = now + target.TransitionTime
	self._fromEnvironment = fromEnvironment
	self._forcedHoldDuration = holdDuration
	self._sequence += 1
end

function WeatherCycle.GetEnvironment(self: WeatherCycle, now: number): WeatherTypes.Environment
	local state = self:GetSnapshot(now)
	return WeatherBlend.Interpolate(
		state.FromEnvironment or self._definitions[state.Current].Environment,
		self._definitions[state.Next].Environment,
		WeatherBlend.Progress(state, now)
	)
end

function WeatherCycle.GetSnapshot(self: WeatherCycle, now: number): WeatherTypes.Snapshot
	local state: WeatherTypes.Snapshot = {
		Version = 1,
		Sequence = self._sequence,
		Seed = self._seed,
		Current = self._current,
		Next = self._next,
		StartedAt = self._startedAt,
		TransitionAt = self._transitionAt,
		EndsAt = self._endsAt,
		ServerTime = now,
		TransitionProgress = 0,
		TimeRemaining = 0,
		FromEnvironment = if self._fromEnvironment then table.clone(self._fromEnvironment) else nil,
	}
	state.TransitionProgress = WeatherBlend.Progress(state, now)
	state.TimeRemaining = WeatherBlend.Remaining(state, now)
	return state
end

export type WeatherCycle = typeof(setmetatable({
	_config = {} :: WeatherTypes.Config,
	_definitions = {} :: { [string]: WeatherTypes.Definition },
	_random = WeatherRandom.new(1),
	_seed = 1,
	_current = "",
	_next = "",
	_sequence = 1,
	_startedAt = 0,
	_transitionAt = 0,
	_endsAt = 0,
	_fromEnvironment = nil :: WeatherTypes.Environment?,
	_forcedHoldDuration = nil :: number?,
}, WeatherCycle))

return WeatherCycle
