--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local LightningCycle = require(script.Parent.Parent.Simulation.LightningCycle)

local LightningService = {}
LightningService.__index = LightningService

function LightningService.new(config: SimulationTypes.LightningConfig, seed: number)
	return setmetatable({
		_cycle = LightningCycle.new(config, seed),
		_channel = nil :: StringValue?,
	}, LightningService)
end

function LightningService.Start(self: LightningService)
	assert(
		not self._channel and not ReplicatedStorage:FindFirstChild("WeatherLightning"),
		"WeatherLightning already exists"
	)
	local channel = Instance.new("StringValue")
	channel.Name = "WeatherLightning"
	channel.Parent = ReplicatedStorage
	self._channel = channel
end

function LightningService.Update(self: LightningService, now: number, stormEndsAt: number?, severe: boolean?)
	if not self._channel or not self._cycle:IsDue(now, stormEndsAt, severe) then
		return
	end
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local anchor = Vector3.zero
	local excluded: { Instance } = {}
	for _, player in players do
		local character = player.Character
		if character then
			table.insert(excluded, character)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and anchor == Vector3.zero then
				anchor = root.Position
			end
		end
	end
	local position = self._cycle:ChoosePosition(anchor)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = excluded
	local hit = Workspace:Raycast(position + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0), parameters)
	if hit then
		position = hit.Position
	end
	self._channel.Value = HttpService:JSONEncode(self._cycle:CreateStrike(position, now))
end

function LightningService.Destroy(self: LightningService)
	if self._channel then
		self._channel:Destroy()
		self._channel = nil
	end
end

export type LightningService = typeof(LightningService.new({} :: SimulationTypes.LightningConfig, 1))

return LightningService
