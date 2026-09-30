--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local WeatherTypes = require(ReplicatedStorage.Weather.Types.WeatherTypes)

type Track = { Sound: Sound, Equalizer: EqualizerSoundEffect, StartedAt: number?, Playing: boolean }

local RainAudio = {}
RainAudio.__index = RainAudio

local function randomRoll(): number
	return math.random()
end

local function soundLoaded(sound: Sound): boolean
	return sound.IsLoaded
end

function RainAudio.new(
	config: WeatherTypes.RainAudioConfig,
	randomNumber: (() -> number)?,
	isLoaded: ((Sound) -> boolean)?
)
	local loadCheck: (Sound) -> boolean = isLoaded or soundLoaded
	return setmetatable({
		_config = config,
		_random = randomNumber or randomRoll,
		_isLoaded = loadCheck,
		_tracks = {} :: { Track },
		_lastIds = {} :: { [number]: string },
		_failed = {} :: { [string]: boolean },
		_lastTime = nil :: number?,
		_band = nil :: number?,
		_active = 0,
		_nextChange = 0,
	}, RainAudio)
end

function RainAudio.SelectBand(config: WeatherTypes.RainAudioConfig, rate: number, previous: number?): number?
	if rate <= 0 then
		return nil
	end
	if previous then
		local lower = if previous > 1 then config.Bands[previous - 1].MaxRate - config.Hysteresis else 0
		local upper = config.Bands[previous].MaxRate + config.Hysteresis
		if rate > lower and rate <= upper then
			return previous
		end
	end
	for index, band in config.Bands do
		if rate <= band.MaxRate then
			return index
		end
	end
	return #config.Bands
end

function RainAudio.Start(self: RainAudio)
	if #self._tracks > 0 or not self._config.Enabled then
		return
	end
	for index = 1, 2 do
		local sound = Instance.new("Sound")
		sound.Name = `WeatherRainLoop{index}`
		sound.Looped = true
		sound.Volume = 0
		local equalizer = Instance.new("EqualizerSoundEffect")
		equalizer.Name = "RainShelter"
		equalizer.Parent = sound
		sound.Parent = SoundService
		table.insert(self._tracks, { Sound = sound, Equalizer = equalizer, Playing = false })
	end
end

function RainAudio._pick(self: RainAudio, band: number): string?
	local eligible: { string } = {}
	local last = self._lastIds[band]
	for _, id in self._config.Bands[band].SoundIds do
		if not self._failed[id] and id ~= last then
			table.insert(eligible, id)
		end
	end
	if #eligible == 0 then
		return if last and not self._failed[last] then last else nil
	end
	local index = math.min(#eligible, math.floor(self._random() * #eligible) + 1)
	return eligible[index]
end

function RainAudio._switch(self: RainAudio, band: number, now: number)
	local index = if self._active == 1 then 2 else 1
	local track = self._tracks[index]
	if track.Sound.Volume >= 0.001 then
		return
	end
	local id = self:_pick(band)
	if not id then
		self._active = 0
		self._band = band
		self._nextChange = math.huge
		return
	end
	track.Sound:Stop()
	track.Sound.Volume = 0
	track.Sound.SoundId = id
	track.Sound.TimePosition = 0
	track.Sound:Play()
	track.Playing = true
	track.StartedAt = now
	self._active = index
	self._band = band
	self._lastIds[band] = id
	self._nextChange = now
		+ self._config.MinVariantDuration
		+ self._random() * (self._config.MaxVariantDuration - self._config.MinVariantDuration)
end

function RainAudio.Update(self: RainAudio, rainRate: number, sheltered: boolean, now: number)
	if #self._tracks == 0 then
		return
	end
	local delta = if self._lastTime then math.max(0, now - self._lastTime) else 0
	self._lastTime = now
	for index, track in self._tracks do
		if track.StartedAt and now - track.StartedAt > 15 and not self._isLoaded(track.Sound) then
			local id = track.Sound.SoundId
			if not self._failed[id] then
				warn(`Weather: rain audio {id} did not load; trying another clip in the same intensity band`)
			end
			self._failed[id] = true
			track.Sound:Stop()
			track.Sound.Volume = 0
			track.Playing = false
			track.StartedAt = nil
			if self._active == index then
				self._active = 0
				self._nextChange = 0
			end
		end
	end
	local band = RainAudio.SelectBand(self._config, rainRate, self._band)
	if band and (band ~= self._band or now >= self._nextChange) then
		self:_switch(band, now)
	elseif not band then
		self._band = nil
		self._nextChange = 0
	end
	local intensity = math.clamp(rainRate / 180, 0, 1.5)
	local volume = self._config.Volume * intensity * (if sheltered then self._config.IndoorVolume else 1)
	local alpha = 1 - math.exp(-delta / self._config.FadeTime)
	for index, track in self._tracks do
		local target = if band and index == self._active then volume else 0
		track.Sound.Volume += (target - track.Sound.Volume) * alpha
		local highGain = if sheltered then -18 else 0
		track.Equalizer.HighGain += (highGain - track.Equalizer.HighGain) * alpha
		if target == 0 and track.Sound.Volume < 0.001 and track.Playing then
			track.Sound:Stop()
			track.Sound.Volume = 0
			track.Playing = false
			track.StartedAt = nil
		end
	end
end

function RainAudio.Destroy(self: RainAudio)
	for _, track in self._tracks do
		track.Sound:Destroy()
	end
	table.clear(self._tracks)
	table.clear(self._lastIds)
	table.clear(self._failed)
	self._lastTime = nil
	self._band = nil
	self._active = 0
	self._nextChange = 0
end

export type RainAudio = typeof(RainAudio.new({} :: WeatherTypes.RainAudioConfig))

return RainAudio
