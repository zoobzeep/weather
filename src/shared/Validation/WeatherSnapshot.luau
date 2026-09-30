--!strict

local WeatherTypes = require(script.Parent.Parent.Types.WeatherTypes)
local WeatherBlend = require(script.Parent.Parent.Math.WeatherBlend)
local WeatherSnapshot = {}

function WeatherSnapshot.IsValid(value: any, definitions: { [string]: WeatherTypes.Definition }): boolean
	if type(value) ~= "table" or value.Version ~= 1 then
		return false
	end
	if type(value.Current) ~= "string" or type(value.Next) ~= "string" then
		return false
	end
	if not definitions[value.Current] or not definitions[value.Next] then
		return false
	end
	for _, key in
		{
			"Sequence",
			"Seed",
			"StartedAt",
			"TransitionAt",
			"EndsAt",
			"ServerTime",
			"TransitionProgress",
			"TimeRemaining",
		}
	do
		local number = value[key]
		if type(number) ~= "number" or number ~= number or math.abs(number) == math.huge then
			return false
		end
	end
	if value.FromEnvironment ~= nil then
		local source = value.FromEnvironment
		if
			type(source) ~= "table"
			or (typeof(source.Ambient) ~= "Color3" and not WeatherBlend.DeserializeEnvironment(source))
		then
			return false
		end
	end
	return value.Sequence >= 1
		and value.Sequence % 1 == 0
		and value.Seed >= 1
		and value.Seed <= 2147483646
		and value.Seed % 1 == 0
		and value.StartedAt <= value.TransitionAt
		and value.TransitionAt <= value.EndsAt
		and value.TransitionProgress >= 0
		and value.TransitionProgress <= 1
		and value.TimeRemaining >= 0
end

function WeatherSnapshot.Serialize(state: WeatherTypes.Snapshot): { [string]: any }
	local result: { [string]: any } = table.clone(state)
	if state.FromEnvironment then
		result.FromEnvironment = WeatherBlend.SerializeEnvironment(state.FromEnvironment)
	end
	return result
end

function WeatherSnapshot.Deserialize(
	value: any,
	definitions: { [string]: WeatherTypes.Definition }
): WeatherTypes.Snapshot?
	if not WeatherSnapshot.IsValid(value, definitions) then
		return nil
	end
	local result = table.clone(value) :: any
	if value.FromEnvironment ~= nil then
		result.FromEnvironment = WeatherBlend.DeserializeEnvironment(value.FromEnvironment)
	end
	return result :: WeatherTypes.Snapshot
end

return WeatherSnapshot
