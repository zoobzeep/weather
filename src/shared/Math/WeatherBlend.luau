--!strict

local WeatherTypes = require(script.Parent.Parent.Types.WeatherTypes)
local WeatherBlend = {}

function WeatherBlend.Progress(state: WeatherTypes.Snapshot, now: number): number
	if now < state.TransitionAt then
		return 0
	end
	if state.EndsAt <= state.TransitionAt then
		return 1
	end
	return math.clamp((now - state.TransitionAt) / (state.EndsAt - state.TransitionAt), 0, 1)
end

function WeatherBlend.Remaining(state: WeatherTypes.Snapshot, now: number): number
	return math.max(0, state.EndsAt - now)
end

function WeatherBlend.Interpolate(
	from: WeatherTypes.Environment,
	to: WeatherTypes.Environment,
	progress: number
): WeatherTypes.Environment
	local alpha = math.clamp(progress, 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local function lerp(a: number, b: number): number
		return a + (b - a) * alpha
	end
	return {
		Brightness = lerp(from.Brightness, to.Brightness),
		ExposureCompensation = lerp(from.ExposureCompensation, to.ExposureCompensation),
		Ambient = from.Ambient:Lerp(to.Ambient, alpha),
		OutdoorAmbient = from.OutdoorAmbient:Lerp(to.OutdoorAmbient, alpha),
		AtmosphereDensity = lerp(from.AtmosphereDensity, to.AtmosphereDensity),
		AtmosphereOffset = lerp(from.AtmosphereOffset, to.AtmosphereOffset),
		AtmosphereColor = from.AtmosphereColor:Lerp(to.AtmosphereColor, alpha),
		AtmosphereDecay = from.AtmosphereDecay:Lerp(to.AtmosphereDecay, alpha),
		AtmosphereGlare = lerp(from.AtmosphereGlare, to.AtmosphereGlare),
		AtmosphereHaze = lerp(from.AtmosphereHaze, to.AtmosphereHaze),
		CloudCover = lerp(from.CloudCover, to.CloudCover),
		CloudDensity = lerp(from.CloudDensity, to.CloudDensity),
		CloudColor = from.CloudColor:Lerp(to.CloudColor, alpha),
		Wind = from.Wind:Lerp(to.Wind, alpha),
		RainRate = lerp(from.RainRate, to.RainRate),
		SnowRate = lerp(from.SnowRate, to.SnowRate),
		Temperature = lerp(from.Temperature, to.Temperature),
		Sunshine = lerp(from.Sunshine, to.Sunshine),
	}
end

function WeatherBlend.SerializeEnvironment(environment: WeatherTypes.Environment): { [string]: any }
	local result: { [string]: any } = table.clone(environment)
	for _, key in { "Ambient", "OutdoorAmbient", "AtmosphereColor", "AtmosphereDecay", "CloudColor" } do
		local value = environment[key]
		result[key] = { value.R, value.G, value.B }
	end
	result.Wind = { environment.Wind.X, environment.Wind.Y, environment.Wind.Z }
	return result
end

function WeatherBlend.DeserializeEnvironment(value: any): WeatherTypes.Environment?
	if type(value) ~= "table" then
		return nil
	end
	local result: any = table.clone(value)
	for _, key in { "Ambient", "OutdoorAmbient", "AtmosphereColor", "AtmosphereDecay", "CloudColor" } do
		local color = value[key]
		if
			type(color) ~= "table"
			or type(color[1]) ~= "number"
			or type(color[2]) ~= "number"
			or type(color[3]) ~= "number"
			or color[1] ~= color[1]
			or color[2] ~= color[2]
			or color[3] ~= color[3]
			or color[1] < 0
			or color[1] > 1
			or color[2] < 0
			or color[2] > 1
			or color[3] < 0
			or color[3] > 1
		then
			return nil
		end
		result[key] = Color3.new(color[1], color[2], color[3])
	end
	local wind = value.Wind
	if
		type(wind) ~= "table"
		or type(wind[1]) ~= "number"
		or type(wind[2]) ~= "number"
		or type(wind[3]) ~= "number"
		or wind[1] ~= wind[1]
		or wind[2] ~= wind[2]
		or wind[3] ~= wind[3]
	then
		return nil
	end
	result.Wind = Vector3.new(wind[1], wind[2], wind[3])
	for _, key in
		{
			"Brightness",
			"ExposureCompensation",
			"AtmosphereDensity",
			"AtmosphereOffset",
			"AtmosphereGlare",
			"AtmosphereHaze",
			"CloudCover",
			"CloudDensity",
			"RainRate",
			"SnowRate",
			"Temperature",
			"Sunshine",
		}
	do
		local number = value[key]
		if type(number) ~= "number" or number ~= number or math.abs(number) == math.huge then
			return nil
		end
	end
	return result :: WeatherTypes.Environment
end

return WeatherBlend
