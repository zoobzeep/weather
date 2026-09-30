--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local shared = ReplicatedStorage:WaitForChild("Weather")
local function waitForModules(parent: Instance, names: { string })
	for _, name in names do
		parent:WaitForChild(name)
	end
end

shared:WaitForChild("Lifecycle")
waitForModules(shared:WaitForChild("Types"), { "WeatherTypes", "SimulationTypes" })
waitForModules(shared:WaitForChild("Config"), { "WeatherConfig", "SimulationConfig" })
waitForModules(shared:WaitForChild("Math"), { "WeatherBlend", "TimeMath", "LightningMath", "SnowMath" })
waitForModules(
	shared:WaitForChild("Validation"),
	{ "WeatherValidation", "WeatherSnapshot", "SimulationValidation" }
)
local controllers = script.Parent:WaitForChild("Controllers")
waitForModules(controllers, {
	"WeatherController",
	"PrecipitationController",
	"TimeController",
	"LightningController",
	"SnowController",
})
waitForModules(
	script.Parent:WaitForChild("Presentation"),
	{ "WeatherEnvironment", "PrecipitationField", "RainAudio", "RainSplashes" }
)
local Lifecycle = require(shared.Lifecycle)
local WeatherConfig = require(shared.Config.WeatherConfig)
local WeatherController = require(controllers.WeatherController)

local controller = WeatherController.new(WeatherConfig)
local runtime = Lifecycle.new({
	{
		Name = controller.Name,
		Init = function(_self, systems)
			controller:Init(systems)
		end,
		Start = function(_self)
			controller:Start()
		end,
		Destroy = function(_self)
			controller:Destroy()
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
runtime:Start()
script:SetAttribute("Ready", true)
