--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local TimeMath = require(ReplicatedStorage.Weather.Math.TimeMath)
local HttpService = game:GetService("HttpService")

local TimeController = {}
TimeController.__index = TimeController

function TimeController.new()
	return setmetatable({
		_state = nil :: SimulationTypes.TimeState?,
		_original = nil :: number?,
		_channel = nil :: StringValue?,
		_changed = nil :: RBXScriptConnection?,
		_connections = {} :: { RBXScriptConnection },
	}, TimeController)
end

function TimeController._unbind(self: TimeController)
	if self._changed then
		self._changed:Disconnect()
		self._changed = nil
	end
	if self._original ~= nil then
		Lighting.ClockTime = self._original
		self._original = nil
	end
	self._state = nil
	self._channel = nil
end

function TimeController._bind(self: TimeController, channel: Instance)
	if channel.Name ~= "WeatherTime" or not channel:IsA("StringValue") or self._channel == channel then
		return
	end
	self:_unbind()
	self._channel = channel
	local function receive()
		local ok, state = pcall(HttpService.JSONDecode, HttpService, channel.Value)
		if not ok or not TimeMath.IsValid(state) then
			warn("Weather: ignored an invalid time snapshot")
			return
		end
		if self._state and state.Sequence < self._state.Sequence then
			return
		end
		if self._original == nil then
			self._original = Lighting.ClockTime
		end
		self._state = state
	end
	self._changed = channel:GetPropertyChangedSignal("Value"):Connect(receive)
	receive()
end

function TimeController.Start(self: TimeController)
	assert(#self._connections == 0, "TimeController already started")
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
	local channel = ReplicatedStorage:FindFirstChild("WeatherTime")
	if channel then
		self:_bind(channel)
	end
end

function TimeController.Update(self: TimeController, now: number): number
	if self._state then
		Lighting.ClockTime = TimeMath.ClockTime(self._state, now)
	end
	return TimeMath.Daylight(Lighting.ClockTime)
end

function TimeController.Destroy(self: TimeController)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_unbind()
end

export type TimeController = typeof(TimeController.new())

return TimeController
