--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)
local WeatherValidation = require(ReplicatedStorage.Weather.Validation.WeatherValidation)
local WeatherBlend = require(ReplicatedStorage.Weather.Math.WeatherBlend)
local WeatherSnapshot = require(ReplicatedStorage.Weather.Validation.WeatherSnapshot)
local WeatherEnvironment = require(script.Parent.Parent.Presentation.WeatherEnvironment)
local PrecipitationController = require(script.Parent.PrecipitationController)
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SimulationConfig = require(ReplicatedStorage.Weather.Config.SimulationConfig)
local SimulationValidation = require(ReplicatedStorage.Weather.Validation.SimulationValidation)
local TimeController = require(script.Parent.TimeController)
local LightningController = require(script.Parent.LightningController)
local SnowController = require(script.Parent.SnowController)

local WeatherController = {}
WeatherController.__index = WeatherController

function WeatherController.new(
	config: WeatherTypes.Config,
	simulation: SimulationTypes.Config?
): WeatherController
	return setmetatable({
		Name = "WeatherController",
		_config = config,
		_simulation = simulation or SimulationConfig,
		_time = TimeController.new(),
		_lightning = nil :: LightningController.LightningController?,
		_snow = nil :: SnowController.SnowController?,
		_definitions = {} :: { [string]: WeatherTypes.Definition },
		_state = nil :: WeatherTypes.Snapshot?,
		_channel = nil :: StringValue?,
		_changed = nil :: RBXScriptConnection?,
		_connections = {} :: { RBXScriptConnection },
		_environment = WeatherEnvironment.new(),
		_precipitation = nil :: PrecipitationController.PrecipitationController?,
	}, WeatherController)
end

function WeatherController.Init(self: WeatherController, _systems: { [string]: any })
	self._config = WeatherValidation.Validate(self._config)
	self._simulation = SimulationValidation.Validate(self._simulation)
	self._lightning = LightningController.new(self._simulation.Lightning)
	self._snow = SnowController.new(self._simulation.Snow)
	for _, definition in self._config.Definitions do
		self._definitions[definition.Id] = definition
	end
	self._precipitation = PrecipitationController.new(self._config)
end

function WeatherController._unbind(self: WeatherController)
	if self._changed then
		self._changed:Disconnect()
		self._changed = nil
	end
	self._channel = nil
	self._state = nil
	self._environment:Destroy()
	if self._precipitation then
		self._precipitation:Destroy()
	end
end

function WeatherController._bind(self: WeatherController, instance: Instance)
	if instance.Name ~= "WeatherState" or not instance:IsA("StringValue") or self._channel == instance then
		return
	end
	self:_unbind()
	self._channel = instance
	local function receive()
		local ok, value = pcall(function(): any
			return HttpService:JSONDecode(instance.Value)
		end)
		local state = if ok then WeatherSnapshot.Deserialize(value, self._definitions) else nil
		if not state then
			warn("Weather: ignored an invalid server snapshot")
			return
		end
		local previous = self._state
		if previous and (state.Sequence < previous.Sequence or state.ServerTime < previous.ServerTime) then
			return
		end
		self._state = state
		self._environment:Start()
		if self._precipitation then
			self._precipitation:Start()
		end
	end
	self._changed = instance:GetPropertyChangedSignal("Value"):Connect(receive)
	receive()
end

function WeatherController.Start(self: WeatherController)
	assert(RunService:IsClient(), "WeatherController must run on a client")
	assert(#self._connections == 0, "WeatherController is already started")
	self._time:Start()
	if self._lightning then
		self._lightning:Start()
	end
	if self._snow then
		self._snow:Start()
	end
	table.insert(
		self._connections,
		ReplicatedStorage.ChildAdded:Connect(function(child)
			self:_bind(child)
		end)
	)
	table.insert(
		self._connections,
		ReplicatedStorage.ChildRemoved:Connect(function(child)
			if child == self._channel then
				self:_unbind()
			end
		end)
	)
	local channel = ReplicatedStorage:FindFirstChild("WeatherState")
	if channel then
		self:_bind(channel)
	end
	table.insert(
		self._connections,
		RunService.RenderStepped:Connect(function()
			local now = Workspace:GetServerTimeNow()
			local daylight = self._time:Update(now)
			if self._lightning then
				self._lightning:Update(now)
			end
			if self._snow then
				self._snow:Update(now)
			end
			local state = self._state
			if not state then
				return
			end
			local environment = WeatherBlend.Interpolate(
				state.FromEnvironment or self._definitions[state.Current].Environment,
				self._definitions[state.Next].Environment,
				WeatherBlend.Progress(state, now)
			)
			local ambientFactor = self._simulation.Time.NightAmbientFactor
				+ (1 - self._simulation.Time.NightAmbientFactor) * daylight
			environment.Ambient = environment.Ambient:Lerp(Color3.new(), 1 - ambientFactor)
			environment.OutdoorAmbient = environment.OutdoorAmbient:Lerp(Color3.new(), 1 - ambientFactor)
			self._environment:Apply(environment)
			if self._precipitation then
				self._precipitation:Update(environment, now)
			end
		end)
	)
end

function WeatherController.GetState(self: WeatherController): WeatherTypes.Snapshot?
	if not self._state then
		return nil
	end
	local state = table.clone(self._state)
	state.ServerTime = Workspace:GetServerTimeNow()
	state.TransitionProgress = WeatherBlend.Progress(state, state.ServerTime)
	state.TimeRemaining = WeatherBlend.Remaining(state, state.ServerTime)
	return state
end

function WeatherController.Destroy(self: WeatherController)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._snow then
		self._snow:Destroy()
	end
	if self._lightning then
		self._lightning:Destroy()
	end
	self._time:Destroy()
	self:_unbind()
end

export type WeatherController = typeof(setmetatable({
	Name = "WeatherController",
	_config = {} :: WeatherTypes.Config,
	_simulation = {} :: SimulationTypes.Config,
	_time = TimeController.new(),
	_lightning = nil :: LightningController.LightningController?,
	_snow = nil :: SnowController.SnowController?,
	_definitions = {} :: { [string]: WeatherTypes.Definition },
	_state = nil :: WeatherTypes.Snapshot?,
	_channel = nil :: StringValue?,
	_changed = nil :: RBXScriptConnection?,
	_connections = {} :: { RBXScriptConnection },
	_environment = WeatherEnvironment.new(),
	_precipitation = nil :: PrecipitationController.PrecipitationController?,
}, WeatherController))

return WeatherController
