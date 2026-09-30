--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Weather.Lifecycle)
local WeatherConfig = require(ReplicatedStorage.Weather.Config.WeatherConfig)
local WeatherService = require(script.Parent.Services.WeatherService)

local service = WeatherService.new(WeatherConfig)
local runtime = Lifecycle.new({
	{
		Name = service.Name,
		Init = function(_self, systems)
			service:Init(systems)
		end,
		Start = function(_self)
			service:Start()
		end,
		Destroy = function(_self)
			service:Destroy()
		end,
	},
})
local destroying: RBXScriptConnection?
destroying = script.Destroying:Connect(function()
	runtime:Destroy()
	if destroying then
		destroying:Disconnect()
	end
end)
game:BindToClose(function()
	runtime:Destroy()
end)
runtime:Start()
script:SetAttribute("Ready", true)
