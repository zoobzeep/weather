--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local TimeMath = require(ReplicatedStorage.Weather.Math.TimeMath)
local TimeCycle = require(script.Parent.Parent.Simulation.TimeCycle)

local TimeService = {}
TimeService.__index = TimeService

function TimeService.new(config: SimulationTypes.TimeConfig)
	return setmetatable({
		_config = config,
		_cycle = nil :: TimeCycle.TimeCycle?,
		_channel = nil :: StringValue?,
	}, TimeService)
end

function TimeService._publish(self: TimeService)
	if self._channel and self._cycle then
		self._channel.Value = HttpService:JSONEncode(self._cycle:GetState())
	end
end

function TimeService.Start(self: TimeService)
	assert(
		not self._channel and not ReplicatedStorage:FindFirstChild("WeatherTime"),
		"WeatherTime already exists"
	)
	self._cycle = TimeCycle.new(self._config, Workspace:GetServerTimeNow())
	local channel = Instance.new("StringValue")
	channel.Name = "WeatherTime"
	self._channel = channel
	self:_publish()
	channel.Parent = ReplicatedStorage
end

function TimeService.SetPaused(self: TimeService, paused: boolean)
	assert(self._cycle, "TimeService is not running")
	self._cycle:SetPaused(paused, Workspace:GetServerTimeNow())
	self:_publish()
end

function TimeService.SetSpeed(self: TimeService, speed: number)
	assert(self._cycle, "TimeService is not running")
	self._cycle:SetSpeed(speed, Workspace:GetServerTimeNow())
	self:_publish()
end

function TimeService.SetClockTime(self: TimeService, clockTime: number)
	assert(self._cycle, "TimeService is not running")
	self._cycle:SetClockTime(clockTime, Workspace:GetServerTimeNow())
	self:_publish()
end

function TimeService.GetClockTime(self: TimeService, now: number): number
	assert(self._cycle, "TimeService is not running")
	return self._cycle:GetClockTime(now)
end

function TimeService.GetDaylight(self: TimeService, now: number): number
	return TimeMath.Daylight(self:GetClockTime(now))
end

function TimeService.Destroy(self: TimeService)
	if self._channel then
		self._channel:Destroy()
		self._channel = nil
	end
	self._cycle = nil
end

export type TimeService = typeof(TimeService.new({} :: SimulationTypes.TimeConfig))

return TimeService
