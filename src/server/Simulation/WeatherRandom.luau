--!strict

local WeatherRandom = {}
WeatherRandom.__index = WeatherRandom

function WeatherRandom.new(seed: number)
	return setmetatable({ _state = seed }, WeatherRandom)
end

function WeatherRandom.NextNumber(self: WeatherRandom): number
	self._state = (self._state * 16807) % 2147483647
	return (self._state - 1) / 2147483646
end

export type WeatherRandom = typeof(setmetatable({ _state = 1 }, WeatherRandom))

return WeatherRandom
