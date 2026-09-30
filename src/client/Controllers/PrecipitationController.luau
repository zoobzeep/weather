--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)

local PrecipitationField = require(script.Parent.Parent.Presentation.PrecipitationField)

local RainAudio = require(script.Parent.Parent.Presentation.RainAudio)
local RainSplashes = require(script.Parent.Parent.Presentation.RainSplashes)

type CameraProvider = () -> Camera?

local PrecipitationController = {}
PrecipitationController.__index = PrecipitationController

function PrecipitationController.new(
	config: WeatherTypes.Config,
	probe: WeatherTypes.SurfaceProbe?,
	cameraProvider: CameraProvider?
)
	return setmetatable({
		_config = config.Precipitation,
		_part = nil :: Part?,
		_emitters = {} :: { [string]: ParticleEmitter },
		_lastSearch = -math.huge,
		_field = PrecipitationField.new(config),
		_audio = RainAudio.new(config.Precipitation.RainAudio),
		_splashes = RainSplashes.new(config),
		_probe = probe,
		_cameraProvider = (cameraProvider or function(): Camera?
			return Workspace.CurrentCamera
		end) :: CameraProvider,
		_lastCamera = nil :: CFrame?,
		_sheltered = false,
		_shelterAt = -math.huge,
	}, PrecipitationController)
end

function PrecipitationController.Start(self: PrecipitationController)
	if not self._config.Enabled or self._part then
		return
	end
	local part = Instance.new("Part")
	part.Name = "WeatherPrecipitation"
	part.Size = Vector3.new(self._config.AreaSize, 1, self._config.AreaSize)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = Workspace
	self._part = part
	self._field:Start(part)
	self._audio:Start()
	self._splashes:Start(part)
	if not self._probe then
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.IgnoreWater = false
		self._probe = function(origin: Vector3, direction: Vector3): WeatherTypes.SurfaceHit?
			local excluded: { Instance } = {}
			if self._part then
				table.insert(excluded, self._part)
			end
			local player = Players.LocalPlayer
			if player and player.Character then
				table.insert(excluded, player.Character)
			end
			parameters.FilterDescendantsInstances = excluded
			local hit = Workspace:Raycast(origin, direction, parameters)
			return if hit then { Position = hit.Position, Normal = hit.Normal } else nil
		end
	end
end

function PrecipitationController._findTemplates(self: PrecipitationController, now: number)
	if now - self._lastSearch < 1 then
		return
	end
	self._lastSearch = now
	local folder = ReplicatedStorage:FindFirstChild(self._config.TemplateFolder)
	for _, name in { "Rain", "Snow" } do
		if self._emitters[name] then
			continue
		end
		local template = if folder then folder:FindFirstChild(name) else nil
		if
			template
			and template:IsA("ParticleEmitter")
			and template.Texture ~= ""
			and template.Archivable
		then
			local emitter = template:Clone()
			emitter:ClearAllChildren()
			emitter.Enabled = false
			emitter.Rate = 0
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.Parent = self._part
			self._emitters[name] = emitter
		end
	end
end

function PrecipitationController.Update(
	self: PrecipitationController,
	environment: WeatherTypes.Environment,
	now: number
)
	local part = self._part
	if not part then
		return
	end
	self:_findTemplates(now)
	local camera = self._cameraProvider()
	if camera then
		self._lastCamera = camera.CFrame
	end
	local viewFrame = if camera then camera.CFrame else self._lastCamera
	if viewFrame then
		part.CFrame = CFrame.new(viewFrame.Position + Vector3.new(0, self._config.Height, 0))
	end
	local probe = self._probe
	if not probe then
		return
	end
	if viewFrame and now >= self._shelterAt then
		local position = viewFrame.Position
		local height = self._config.Height + self._config.SkyCheckHeight
		local ceiling = probe(position, Vector3.new(0, height, 0))
		self._sheltered = ceiling ~= nil
		self._shelterAt = now + self._config.OcclusionInterval
	end
	for name, emitter in self._emitters do
		local rate = if name == "Rain" then environment.RainRate else environment.SnowRate
		local wasEnabled = emitter.Enabled
		emitter.Rate = rate
		emitter.Enabled = viewFrame ~= nil and not self._sheltered and rate > 0
		if wasEnabled and not emitter.Enabled then
			emitter:Clear()
		end
	end
	self._audio:Update(if viewFrame then environment.RainRate else 0, self._sheltered, now)
	self._splashes:Update(environment.RainRate, now, viewFrame, probe)
	self._field:Update(
		if self._emitters.Rain then 0 else environment.RainRate,
		if self._emitters.Snow then 0 else environment.SnowRate,
		environment.Wind,
		now,
		viewFrame,
		probe
	)
end

function PrecipitationController.Destroy(self: PrecipitationController)
	self._audio:Destroy()
	self._splashes:Destroy()
	self._field:Destroy()
	if self._part then
		self._part:Destroy()
		self._part = nil
	end
	table.clear(self._emitters)
	self._lastSearch = -math.huge
	self._lastCamera = nil
	self._shelterAt = -math.huge
	self._sheltered = false
end

export type PrecipitationController = typeof(PrecipitationController.new({} :: WeatherTypes.Config))

return PrecipitationController
