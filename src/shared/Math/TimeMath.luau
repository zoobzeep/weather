--!strict

local SimulationTypes = require(script.Parent.Parent.Types.SimulationTypes)
local TimeMath = {}

function TimeMath.ClockTime(state: SimulationTypes.TimeState, now: number): number
	local elapsed = if state.Paused then 0 else math.max(0, now - state.StartTimestamp)
	return (state.ClockTime + elapsed * 24 * state.Speed / state.DayDuration) % 24
end

function TimeMath.Daylight(clockTime: number): number
	return math.max(0, math.sin((clockTime - 6) * math.pi / 12))
end

function TimeMath.IsValid(state: any): boolean
	if type(state) ~= "table" or state.Version ~= 1 or type(state.Paused) ~= "boolean" then
		return false
	end
	for _, key in { "Sequence", "StartTimestamp", "ClockTime", "DayDuration", "Speed" } do
		local value = state[key]
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return false
		end
	end
	return state.Sequence >= 1
		and state.Sequence % 1 == 0
		and state.ClockTime >= 0
		and state.ClockTime < 24
		and state.DayDuration >= 10
		and state.DayDuration <= 604800
		and state.Speed >= 0
		and state.Speed <= 100
end

return TimeMath
