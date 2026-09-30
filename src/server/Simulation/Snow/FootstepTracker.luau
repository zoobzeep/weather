--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)

local FootstepTracker = {}
FootstepTracker.__index = FootstepTracker

function FootstepTracker.new(config: SimulationTypes.SnowConfig)
	return setmetatable({
		_config = config,
		_position = nil :: Vector3?,
		_time = 0,
		_lastStep = -math.huge,
		_distance = 0,
		_side = -1,
	}, FootstepTracker)
end

function FootstepTracker.Observe(
	self: FootstepTracker,
	position: Vector3,
	now: number,
	grounded: boolean
): (Vector3?, number)
	local previous = self._position
	local elapsed = now - self._time
	self._position = position
	self._time = now
	if not previous or elapsed <= 0 or elapsed > 1 or not grounded then
		self._distance = 0
		return nil, self._side
	end
	local displacement = position - previous
	local distance = displacement.Magnitude
	if distance ~= distance or distance > self._config.MaxStepSpeed * elapsed + 0.5 then
		self._distance = 0
		return nil, self._side
	end
	local horizontal = Vector3.new(displacement.X, 0, displacement.Z)
	if horizontal.Magnitude < 0.01 then
		return nil, self._side
	end
	self._distance += horizontal.Magnitude
	if self._distance < self._config.StepDistance or now - self._lastStep < self._config.StepInterval then
		return nil, self._side
	end
	self._distance %= self._config.StepDistance
	self._lastStep = now
	self._side = -self._side
	return horizontal.Unit, self._side
end

export type FootstepTracker = typeof(setmetatable({
	_config = {} :: SimulationTypes.SnowConfig,
	_position = nil :: Vector3?,
	_time = 0,
	_lastStep = -math.huge,
	_distance = 0,
	_side = -1,
}, FootstepTracker))

return FootstepTracker
