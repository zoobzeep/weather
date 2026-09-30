--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)

local WeatherEnvironment = {}
WeatherEnvironment.__index = WeatherEnvironment

function WeatherEnvironment.new()
	return setmetatable({
		_original = nil :: WeatherTypes.Environment?,
		_atmosphere = nil :: Atmosphere?,
		_clouds = nil :: Clouds?,
		_ownsAtmosphere = false,
		_ownsClouds = false,
		_cloudsEnabled = false,
	}, WeatherEnvironment)
end

function WeatherEnvironment.Start(self: WeatherEnvironment)
	if self._original then
		return
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	self._ownsAtmosphere = atmosphere == nil
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "WeatherAtmosphere"
		atmosphere.Parent = Lighting
	end
	self._atmosphere = atmosphere
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	self._ownsClouds = clouds == nil
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "WeatherClouds"
		clouds.Parent = Workspace.Terrain
	end
	self._clouds = clouds
	self._cloudsEnabled = clouds.Enabled
	self._original = {
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		AtmosphereDensity = atmosphere.Density,
		AtmosphereOffset = atmosphere.Offset,
		AtmosphereColor = atmosphere.Color,
		AtmosphereDecay = atmosphere.Decay,
		AtmosphereGlare = atmosphere.Glare,
		AtmosphereHaze = atmosphere.Haze,
		CloudCover = clouds.Cover,
		CloudDensity = clouds.Density,
		CloudColor = clouds.Color,
		Wind = Workspace.GlobalWind,
		RainRate = 0,
		SnowRate = 0,
		Temperature = 0,
		Sunshine = 0,
	}
end

function WeatherEnvironment.Apply(self: WeatherEnvironment, environment: WeatherTypes.Environment)
	Lighting.Brightness = environment.Brightness
	Lighting.ExposureCompensation = environment.ExposureCompensation
	Lighting.Ambient = environment.Ambient
	Lighting.OutdoorAmbient = environment.OutdoorAmbient
	Workspace.GlobalWind = environment.Wind
	local atmosphere = self._atmosphere
	if atmosphere and atmosphere.Parent then
		atmosphere.Density = environment.AtmosphereDensity
		atmosphere.Offset = environment.AtmosphereOffset
		atmosphere.Color = environment.AtmosphereColor
		atmosphere.Decay = environment.AtmosphereDecay
		atmosphere.Glare = environment.AtmosphereGlare
		atmosphere.Haze = environment.AtmosphereHaze
	end
	local clouds = self._clouds
	if clouds and clouds.Parent then
		clouds.Enabled = true
		clouds.Cover = environment.CloudCover
		clouds.Density = environment.CloudDensity
		clouds.Color = environment.CloudColor
	end
end

function WeatherEnvironment.Destroy(self: WeatherEnvironment)
	if self._original then
		self:Apply(self._original)
		self._original = nil
	end
	if self._clouds then
		if self._ownsClouds then
			self._clouds:Destroy()
		elseif self._clouds.Parent then
			self._clouds.Enabled = self._cloudsEnabled
		end
		self._clouds = nil
	end
	if self._atmosphere then
		if self._ownsAtmosphere then
			self._atmosphere:Destroy()
		end
		self._atmosphere = nil
	end
end

export type WeatherEnvironment = typeof(WeatherEnvironment.new())

return WeatherEnvironment
