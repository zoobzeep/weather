--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

roblox.implementMethod("ParticleEmitter", "Clear", function(_emitter) end)
roblox.implementMethod("HttpService", "JSONEncode", function(_service, value)
	return serde.encode("json", value)
end)
roblox.implementMethod("HttpService", "JSONDecode", function(_service, value)
	return serde.decode("json", value)
end)

roblox.implementMethod("Sound", "Play", function(sound)
	sound:SetAttribute("TestPlaying", true)
end)
roblox.implementMethod("Sound", "Stop", function(sound)
	sound:SetAttribute("TestPlaying", false)
end)

local dataModel = roblox.deserializePlace(fs.readFile("build/weather.rbxlx"))
local cache: { [any]: any } = {}

local function loadModule(module: any): any
	assert(module:IsA("ModuleScript"), "Checks can only require ModuleScripts")
	if cache[module] ~= nil then
		return cache[module]
	end
	local environment: { [string]: any } = {
		game = dataModel,
		script = module,
		require = loadModule,
	}
	for key, value in roblox do
		environment[key] = value
	end
	local run = luau.load(module.Source, {
		debugName = module:GetFullName(),
		environment = environment,
	})
	local result = run()
	cache[module] = result
	return result
end

print(loadModule(dataModel:GetService("TestService").WeatherChecks.WeatherChecks)())
print(loadModule(dataModel:GetService("TestService").WeatherChecks.EnvironmentChecks)())
print(loadModule(dataModel:GetService("TestService").WeatherChecks.RainChecks)())
print(loadModule(dataModel:GetService("TestService").WeatherChecks.SimulationChecks)())
