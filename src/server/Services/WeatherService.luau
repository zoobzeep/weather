--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)
local WeatherValidation = require(ReplicatedStorage.Weather.Validation.WeatherValidation)
local WeatherCycle = require(script.Parent.Parent.Simulation.WeatherCycle)
local WeatherSnapshot = require(ReplicatedStorage.Weather.Validation.WeatherSnapshot)
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SimulationConfig = require(ReplicatedStorage.Weather.Config.SimulationConfig)
local SimulationValidation = require(ReplicatedStorage.Weather.Validation.SimulationValidation)
local TimeService = require(script.Parent.TimeService)
local SnowService = require(script.Parent.SnowService)
local LightningService = require(script.Parent.LightningService)

type ActiveWeatherService = { _cycle: WeatherCycle.WeatherCycle?, _channel: StringValue? }

local WeatherService = {}
WeatherService.__index = WeatherService
local activeService: ActiveWeatherService? = nil

function WeatherService.new(config: WeatherTypes.Config, simulation: SimulationTypes.Config?): WeatherService
	return setmetatable({
		Name = "WeatherService",
		_config = config,
		_simulation = simulation or SimulationConfig,
		_time = nil :: TimeService.TimeService?,
		_snow = nil :: SnowService.SnowService?,
		_lightning = nil :: LightningService.LightningService?,
		_cycle = nil :: WeatherCycle.WeatherCycle?,
		_channel = nil :: StringValue?,
		_connection = nil :: RBXScriptConnection?,
	}, WeatherService)
end

function WeatherService.Init(self: WeatherService, _systems: { [string]: any })
	self._config = WeatherValidation.Validate(self._config)
	self._simulation = SimulationValidation.Validate(self._simulation)
end

function WeatherService.Start(self: WeatherService)
	assert(RunService:IsServer(), "WeatherService must run on the server")
	assert(self._connection == nil, "WeatherService is already started")
	assert(ReplicatedStorage:FindFirstChild("WeatherState") == nil, "WeatherState is already owned")
	local now = Workspace:GetServerTimeNow()
	local fallbackSeed = Random.new():NextInteger(1, 2147483646)
	local cycle = WeatherCycle.new(self._config, now, fallbackSeed)
	self._cycle = cycle
	local time = TimeService.new(self._simulation.Time)
	local snow = SnowService.new(self._simulation.Snow)
	local lightning = LightningService.new(self._simulation.Lightning, cycle:GetSnapshot(now).Seed)
	self._time = time
	self._snow = snow
	self._lightning = lightning
	time:Start()
	snow:Start(now)
	lightning:Start()
	local channel = Instance.new("StringValue")
	channel.Name = "WeatherState"
	channel.Value = HttpService:JSONEncode(WeatherSnapshot.Serialize(cycle:GetSnapshot(now)))
	self._channel = channel
	channel.Parent = ReplicatedStorage
	local lastPublish = now
	local lastSequence = 1
	local function sampleSnow(sampleTime: number): SimulationTypes.SnowForcing
		assert(cycle:Advance(sampleTime), "Weather could not advance to the snow simulation tick")
		local environment = cycle:GetEnvironment(sampleTime)
		local daylight = time:GetDaylight(sampleTime)
		return {
			Snowfall = environment.SnowRate / 100,
			Sunshine = environment.Sunshine,
			Daylight = daylight,
			Temperature = environment.Temperature
				- (1 - daylight) * self._simulation.Time.NightTemperatureDrop,
		}
	end
	self._connection = RunService.Heartbeat:Connect(function()
		local serverTime = Workspace:GetServerTimeNow()
		if not snow:Update(serverTime, sampleSnow) or not cycle:Advance(serverTime) then
			return
		end
		local state = cycle:GetSnapshot(serverTime)
		local isStorm = state.Current == "Thunderstorm" or state.Current == "SevereThunderstorm"
		local stormEndsAt = if isStorm and serverTime < state.TransitionAt then state.TransitionAt else nil
		lightning:Update(serverTime, stormEndsAt, state.Current == "SevereThunderstorm")
		if state.Sequence ~= lastSequence or serverTime - lastPublish >= self._config.SnapshotInterval then
			channel.Value = HttpService:JSONEncode(WeatherSnapshot.Serialize(state))
			lastPublish = serverTime
			lastSequence = state.Sequence
		end
	end)
	activeService = { _cycle = self._cycle, _channel = self._channel }
end

function WeatherService.ForceWeather(weatherId: string, holdDuration: number?): boolean
	local service = activeService
	assert(service, "WeatherService is not running")
	local cycle = service._cycle
	assert(cycle, "WeatherService is not running")
	local now = Workspace:GetServerTimeNow()
	cycle:ForceWeather(weatherId, now, holdDuration or 60)
	local channel = service._channel
	assert(channel, "WeatherState is not available")
	channel.Value = HttpService:JSONEncode(WeatherSnapshot.Serialize(cycle:GetSnapshot(now)))
	return true
end

function WeatherService.GetState(self: WeatherService): WeatherTypes.Snapshot?
	local cycle = self._cycle
	return if cycle then cycle:GetSnapshot(Workspace:GetServerTimeNow()) else nil
end

function WeatherService.GetTimeService(self: WeatherService): TimeService.TimeService
	assert(self._time, "WeatherService is not running")
	return self._time
end

function WeatherService.Destroy(self: WeatherService)
	if activeService and activeService._cycle == self._cycle and activeService._channel == self._channel then
		activeService = nil
	end
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._lightning then
		self._lightning:Destroy()
		self._lightning = nil
	end
	if self._snow then
		self._snow:Destroy()
		self._snow = nil
	end
	if self._time then
		self._time:Destroy()
		self._time = nil
	end
	if self._channel then
		self._channel:Destroy()
		self._channel = nil
	end
	self._cycle = nil
end

export type WeatherService = typeof(setmetatable({
	Name = "WeatherService",
	_config = {} :: WeatherTypes.Config,
	_simulation = {} :: SimulationTypes.Config,
	_time = nil :: TimeService.TimeService?,
	_snow = nil :: SnowService.SnowService?,
	_lightning = nil :: LightningService.LightningService?,
	_cycle = nil :: WeatherCycle.WeatherCycle?,
	_channel = nil :: StringValue?,
	_connection = nil :: RBXScriptConnection?,
}, WeatherService))

return WeatherService
