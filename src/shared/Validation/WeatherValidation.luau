--!strict

local WeatherTypes = require(script.Parent.Parent.Types.WeatherTypes)
local WeatherValidation = {}

local function expect(condition: boolean, path: string, message: string)
	assert(condition, `Weather configuration: {path} {message}`)
end

local function numberIn(value: any, path: string, minimum: number, maximum: number)
	expect(type(value) == "number", path, "must be a number")
	expect(
		value == value and value >= minimum and value <= maximum,
		path,
		`must be finite and between {minimum} and {maximum}`
	)
end

local function color(value: any, path: string)
	expect(typeof(value) == "Color3", path, "must be Color3")
	numberIn(value.R, `{path}.R`, 0, 1)
	numberIn(value.G, `{path}.G`, 0, 1)
	numberIn(value.B, `{path}.B`, 0, 1)
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

function WeatherValidation.Validate(value: any): WeatherTypes.Config
	expect(type(value) == "table", "Config", "must be a table")
	expect(type(value.AllowRepeats) == "boolean", "AllowRepeats", "must be boolean")
	numberIn(value.SnapshotInterval, "SnapshotInterval", 0.1, 60)
	if value.Seed ~= nil then
		numberIn(value.Seed, "Seed", 1, 2147483646)
		expect(value.Seed % 1 == 0, "Seed", "must be an integer")
	end
	expect(type(value.Definitions) == "table", "Definitions", "must be an array")
	local count = #value.Definitions
	expect(count > 0 and count <= 100, "Definitions", "must contain 1 to 100 entries")
	for key in value.Definitions do
		expect(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
			"Definitions",
			"must be a dense array"
		)
	end
	local ids: { [string]: boolean } = {}
	local positiveCount = 0
	for index = 1, count do
		local definition = value.Definitions[index]
		local path = `Definitions[{index}]`
		expect(type(definition) == "table", path, "must be a table")
		expect(type(definition.Id) == "string" and #definition.Id > 0, `{path}.Id`, "must be nonempty")
		expect(not ids[definition.Id], `{path}.Id`, `duplicates {definition.Id}`)
		ids[definition.Id] = true
		numberIn(definition.Weight, `{path}.Weight`, 0, 1000000)
		if definition.Weight > 0 then
			positiveCount += 1
		end
		numberIn(definition.MinDuration, `{path}.MinDuration`, 0.1, 86400)
		numberIn(definition.MaxDuration, `{path}.MaxDuration`, definition.MinDuration, 86400)
		numberIn(definition.TransitionTime, `{path}.TransitionTime`, 0, 3600)
		local environment = definition.Environment
		expect(type(environment) == "table", `{path}.Environment`, "must be a table")
		path ..= ".Environment"
		for _, key in { "Brightness", "AtmosphereGlare", "AtmosphereHaze" } do
			numberIn(environment[key], `{path}.{key}`, 0, 10)
		end
		for _, key in { "AtmosphereDensity", "CloudCover", "CloudDensity" } do
			numberIn(environment[key], `{path}.{key}`, 0, 1)
		end
		numberIn(environment.AtmosphereOffset, `{path}.AtmosphereOffset`, -1, 1)
		numberIn(environment.ExposureCompensation, `{path}.ExposureCompensation`, -5, 5)
		numberIn(environment.Temperature, `{path}.Temperature`, -80, 60)
		numberIn(environment.Sunshine, `{path}.Sunshine`, 0, 1)
		for _, key in { "RainRate", "SnowRate" } do
			numberIn(environment[key], `{path}.{key}`, 0, 1000)
		end
		for _, key in { "Ambient", "OutdoorAmbient", "AtmosphereColor", "AtmosphereDecay", "CloudColor" } do
			color(environment[key], `{path}.{key}`)
		end
		expect(typeof(environment.Wind) == "Vector3", `{path}.Wind`, "must be Vector3")
		for _, axis in { "X", "Y", "Z" } do
			numberIn(environment.Wind[axis], `{path}.Wind.{axis}`, -1000, 1000)
		end
	end
	expect(positiveCount > 0, "Definitions", "needs at least one positive weight")
	expect(
		value.AllowRepeats or positiveCount >= 2,
		"AllowRepeats",
		"false requires at least two positive weights"
	)
	expect(
		type(value.InitialWeather) == "string" and ids[value.InitialWeather] == true,
		"InitialWeather",
		"must name a definition"
	)
	local precipitation = value.Precipitation
	expect(type(precipitation) == "table", "Precipitation", "must be a table")
	expect(type(precipitation.Enabled) == "boolean", "Precipitation.Enabled", "must be boolean")
	expect(
		type(precipitation.TemplateFolder) == "string" and #precipitation.TemplateFolder > 0,
		"Precipitation.TemplateFolder",
		"must be nonempty"
	)
	numberIn(precipitation.Height, "Precipitation.Height", 1, 500)
	numberIn(precipitation.AreaSize, "Precipitation.AreaSize", 1, 500)
	numberIn(precipitation.MaxParticles, "Precipitation.MaxParticles", 1, 600)
	expect(precipitation.MaxParticles % 1 == 0, "Precipitation.MaxParticles", "must be an integer")
	numberIn(precipitation.RainSpeed, "Precipitation.RainSpeed", 1, 200)
	numberIn(precipitation.SnowSpeed, "Precipitation.SnowSpeed", 1, 50)
	numberIn(precipitation.SpeedVariation, "Precipitation.SpeedVariation", 0, 0.5)
	numberIn(precipitation.SpeedTransitionTime, "Precipitation.SpeedTransitionTime", 0.05, 5)
	numberIn(precipitation.WindInfluence, "Precipitation.WindInfluence", 0, 2)
	numberIn(precipitation.OcclusionInterval, "Precipitation.OcclusionInterval", 0.05, 1)
	numberIn(precipitation.SkyCheckHeight, "Precipitation.SkyCheckHeight", 1, 2000)
	local audio = precipitation.RainAudio
	expect(type(audio) == "table", "Precipitation.RainAudio", "must be a table")
	expect(type(audio.Enabled) == "boolean", "RainAudio.Enabled", "must be boolean")
	numberIn(audio.Hysteresis, "RainAudio.Hysteresis", 0, 100)
	numberIn(audio.MinVariantDuration, "RainAudio.MinVariantDuration", 5, 3600)
	numberIn(audio.MaxVariantDuration, "RainAudio.MaxVariantDuration", audio.MinVariantDuration, 3600)
	expect(type(audio.Bands) == "table", "RainAudio.Bands", "must be an array")
	expect(#audio.Bands >= 1 and #audio.Bands <= 8, "RainAudio.Bands", "needs 1 to 8 bands")
	local previousRate = 0
	local names: { [string]: boolean } = {}
	for key in audio.Bands do
		expect(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #audio.Bands,
			"RainAudio.Bands",
			"must be a dense array"
		)
	end
	for index, band in audio.Bands do
		local path = `RainAudio.Bands[{index}]`
		expect(type(band) == "table", path, "must be a table")
		expect(type(band.Name) == "string" and #band.Name > 0, path, "needs a nonempty Name")
		expect(not names[band.Name], path, "needs a unique Name")
		names[band.Name] = true
		numberIn(band.MaxRate, `{path}.MaxRate`, 1, 1000)
		expect(
			band.MaxRate > previousRate + audio.Hysteresis,
			path,
			"thresholds must increase beyond hysteresis"
		)
		previousRate = band.MaxRate
		expect(type(band.SoundIds) == "table", path, "needs a SoundIds array")
		expect(#band.SoundIds >= 1 and #band.SoundIds <= 8, path, "needs 1 to 8 sounds")
		local soundIds: { [string]: boolean } = {}
		for key in band.SoundIds do
			expect(
				type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #band.SoundIds,
				path,
				"SoundIds must be a dense array"
			)
		end
		for _, id in band.SoundIds do
			expect(
				type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil,
				path,
				"SoundIds must contain rbxassetid:// followed by digits"
			)
			expect(not soundIds[id], path, "SoundIds must not contain duplicates")
			soundIds[id] = true
		end
	end
	expect(previousRate == 1000, "RainAudio.Bands", "last MaxRate must cover the maximum RainRate of 1000")
	numberIn(audio.Volume, "RainAudio.Volume", 0, 3)
	numberIn(audio.IndoorVolume, "RainAudio.IndoorVolume", 0, 1)
	numberIn(audio.FadeTime, "RainAudio.FadeTime", 0.05, 10)
	local splashes = precipitation.Splashes
	expect(type(splashes) == "table", "Precipitation.Splashes", "must be a table")
	expect(type(splashes.Enabled) == "boolean", "Splashes.Enabled", "must be boolean")
	numberIn(splashes.MaxSplashes, "Splashes.MaxSplashes", 1, 128)
	expect(splashes.MaxSplashes % 1 == 0, "Splashes.MaxSplashes", "must be an integer")
	numberIn(splashes.Rate, "Splashes.Rate", 1, 120)
	numberIn(splashes.Radius, "Splashes.Radius", 1, 100)
	numberIn(splashes.RayDepth, "Splashes.RayDepth", 1, 2000)
	numberIn(splashes.Lifetime, "Splashes.Lifetime", 0.1, 1)
	numberIn(splashes.Size, "Splashes.Size", 0.02, 0.3)
	numberIn(splashes.Spread, "Splashes.Spread", 0.05, 2)
	numberIn(splashes.Height, "Splashes.Height", 0.05, 2)
	return copy(value) :: WeatherTypes.Config
end

return WeatherValidation
