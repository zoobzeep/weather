--!strict

local SimulationTypes = require(script.Parent.Parent.Types.SimulationTypes)
local LightningMath = {}

function LightningMath.Vector(point: { number }): Vector3
	return Vector3.new(point[1], point[2], point[3])
end

function LightningMath.Arrival(position: Vector3, listener: Vector3, timestamp: number, speed: number): number
	return timestamp + (position - listener).Magnitude / speed
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function point(value: any): boolean
	return type(value) == "table"
		and #value == 3
		and finite(value[1])
		and finite(value[2])
		and finite(value[3])
end

function LightningMath.IsValid(strike: any): boolean
	if
		type(strike) ~= "table"
		or strike.Version ~= 1
		or not finite(strike.Id)
		or strike.Id < 1
		or strike.Id % 1 ~= 0
		or not finite(strike.Timestamp)
		or not point(strike.Position)
	then
		return false
	end
	if type(strike.Points) ~= "table" or #strike.Points < 4 or #strike.Points > 33 then
		return false
	end
	for _, value in strike.Points do
		if not point(value) then
			return false
		end
	end
	return true
end

function LightningMath.Position(strike: SimulationTypes.Strike): Vector3
	return LightningMath.Vector(strike.Position)
end

return LightningMath
