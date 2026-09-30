--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SimulationValidation = require(ReplicatedStorage.Weather.Validation.SimulationValidation)
local TimeMath = require(ReplicatedStorage.Weather.Math.TimeMath)

local TimeCycle = {}
TimeCycle.__index = TimeCycle

function TimeCycle.new(config: SimulationTypes.TimeConfig, now: number)
	local state: SimulationTypes.TimeState = {
		Version = 1,
		Sequence = 1,
		StartTimestamp = now,
		ClockTime = config.InitialTime % 24,
		DayDuration = config.DayDuration,
		Speed = config.Speed,
		Paused = config.Paused,
	}
	assert(TimeMath.IsValid(state), "Invalid time settings")
	return setmetatable({ _state = state }, TimeCycle)
end

function TimeCycle.GetState(self: TimeCycle): SimulationTypes.TimeState
	return table.clone(self._state)
end

function TimeCycle.GetClockTime(self: TimeCycle, now: number): number
	return TimeMath.ClockTime(self._state, now)
end

function TimeCycle._anchor(self: TimeCycle, now: number)
	self._state.ClockTime = self:GetClockTime(now)
	self._state.StartTimestamp = now
	self._state.Sequence += 1
end

function TimeCycle.SetPaused(self: TimeCycle, paused: boolean, now: number)
	assert(type(paused) == "boolean", "Paused must be boolean")
	self:_anchor(now)
	self._state.Paused = paused
end

function TimeCycle.SetSpeed(self: TimeCycle, speed: number, now: number)
	SimulationValidation.Number(speed, "Time.Speed", 0, 100)
	self:_anchor(now)
	self._state.Speed = speed
end

function TimeCycle.SetClockTime(self: TimeCycle, clockTime: number, now: number)
	SimulationValidation.Number(clockTime, "Time.ClockTime", 0, 24)
	self:_anchor(now)
	self._state.ClockTime = clockTime % 24
end

export type TimeCycle = typeof(setmetatable({ _state = {} :: SimulationTypes.TimeState }, TimeCycle))

return TimeCycle
