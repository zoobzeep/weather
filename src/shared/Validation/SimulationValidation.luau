--!strict

local SimulationTypes = require(script.Parent.Parent.Types.SimulationTypes)
local SimulationValidation = {}

function SimulationValidation.Number(value: any, path: string, minimum: number, maximum: number): number
	assert(
		type(value) == "number" and value == value and value >= minimum and value <= maximum,
		`Weather configuration: {path} must be finite and between {minimum} and {maximum}`
	)
	return value
end

local function boolean(value: any, path: string)
	assert(type(value) == "boolean", `Weather configuration: {path} must be boolean`)
end

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return table.freeze(result)
end

function SimulationValidation.Validate(config: any): SimulationTypes.Config
	assert(type(config) == "table", "SimulationConfig must be a table")
	local time = config.Time
	local lightning = config.Lightning
	local snow = config.Snow
	assert(
		type(time) == "table" and type(lightning) == "table" and type(snow) == "table",
		"SimulationConfig needs Time, Lightning, and Snow tables"
	)
	local number = SimulationValidation.Number
	number(time.InitialTime, "Time.InitialTime", 0, 24)
	number(time.DayDuration, "Time.DayDuration", 10, 604800)
	number(time.Speed, "Time.Speed", 0, 100)
	boolean(time.Paused, "Time.Paused")
	number(time.NightTemperatureDrop, "Time.NightTemperatureDrop", 0, 40)
	number(time.NightAmbientFactor, "Time.NightAmbientFactor", 0, 1)
	boolean(lightning.Enabled, "Lightning.Enabled")
	number(lightning.FirstStrikeDelay, "Lightning.FirstStrikeDelay", 0.1, 3600)
	number(lightning.MinInterval, "Lightning.MinInterval", 5, 3600)
	number(lightning.MaxInterval, "Lightning.MaxInterval", lightning.MinInterval, 3600)
	number(lightning.SevereFirstStrikeDelay, "Lightning.SevereFirstStrikeDelay", 0.1, 3600)
	number(lightning.SevereMinInterval, "Lightning.SevereMinInterval", 0.5, 3600)
	number(lightning.SevereMaxInterval, "Lightning.SevereMaxInterval", lightning.SevereMinInterval, 3600)
	number(lightning.LeadTime, "Lightning.LeadTime", 0.1, 2)
	number(lightning.Radius, "Lightning.Radius", 10, 2000)
	number(lightning.Height, "Lightning.Height", 20, 1000)
	number(lightning.Segments, "Lightning.Segments", 3, 32)
	assert(lightning.Segments % 1 == 0, "Lightning.Segments must be an integer")
	number(lightning.Jitter, "Lightning.Jitter", 0, 100)
	number(lightning.Width, "Lightning.Width", 0.05, 3)
	number(lightning.FlashDuration, "Lightning.FlashDuration", 0.05, 0.5)
	number(lightning.FlashBrightness, "Lightning.FlashBrightness", 0, 1)
	assert(type(lightning.ThunderSoundId) == "string", "Lightning.ThunderSoundId must be a string")
	assert(
		lightning.ThunderSoundId == "" or string.match(lightning.ThunderSoundId, "^rbxassetid://%d+$"),
		"Lightning.ThunderSoundId must be empty or rbxassetid:// followed by digits"
	)
	number(lightning.SoundSpeed, "Lightning.SoundSpeed", 10, 10000)
	number(lightning.MaxSoundDistance, "Lightning.MaxSoundDistance", 10, 10000)
	number(lightning.SoundLifetime, "Lightning.SoundLifetime", 1, 120)
	number(lightning.Volume, "Lightning.Volume", 0, 3)
	boolean(snow.Enabled, "Snow.Enabled")
	number(snow.CellSize, "Snow.CellSize", 0.2, 4)
	number(snow.MaxDepth, "Snow.MaxDepth", 0.02, 3)
	for _, key in { "MaxCellsPerSurface", "MaxTotalCells" } do
		number(snow[key], `Snow.{key}`, 1, 32768)
		assert(snow[key] % 1 == 0, `Snow.{key} must be an integer`)
	end
	number(snow.SimulationInterval, "Snow.SimulationInterval", 0.05, 2)
	number(snow.ReplicationInterval, "Snow.ReplicationInterval", 0.25, 10)
	number(snow.DepthQuantum, "Snow.DepthQuantum", 0.001, 0.05)
	for _, key in { "AccumulationRate", "SunnyMeltRate", "TemperatureMeltRate", "FootprintSoftenRate" } do
		number(snow[key], `Snow.{key}`, 0, 0.1)
	end
	number(snow.FootprintDepth, "Snow.FootprintDepth", 0, 1)
	number(snow.FootprintLength, "Snow.FootprintLength", 0.5, 3)
	number(snow.FootprintWidth, "Snow.FootprintWidth", 0.3, 2)
	number(snow.FootprintRefillMultiplier, "Snow.FootprintRefillMultiplier", 0, 10)
	number(snow.StepDistance, "Snow.StepDistance", 1, 10)
	number(snow.StepInterval, "Snow.StepInterval", 0.1, 2)
	number(snow.StepOffset, "Snow.StepOffset", 0, 1)
	number(snow.MaxStepSpeed, "Snow.MaxStepSpeed", 1, 100)
	number(snow.DrawDistance, "Snow.DrawDistance", 10, 1000)
	return copy(config) :: SimulationTypes.Config
end

return SimulationValidation
