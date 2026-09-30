--!strict

export type Environment = {
	Brightness: number,
	ExposureCompensation: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmosphereDensity: number,
	AtmosphereOffset: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereGlare: number,
	AtmosphereHaze: number,
	CloudCover: number,
	CloudDensity: number,
	CloudColor: Color3,
	Wind: Vector3,
	RainRate: number,
	SnowRate: number,
	Temperature: number,
	Sunshine: number,
}

export type Definition = {
	Id: string,
	Weight: number,
	MinDuration: number,
	MaxDuration: number,
	TransitionTime: number,
	Environment: Environment,
}

export type SurfaceHit = { Position: Vector3, Normal: Vector3 }
export type SurfaceProbe = (origin: Vector3, direction: Vector3) -> SurfaceHit?

export type RainAudioBand = {
	Name: string,
	MaxRate: number,
	SoundIds: { string },
}

export type RainAudioConfig = {
	Enabled: boolean,
	Bands: { RainAudioBand },
	Hysteresis: number,
	MinVariantDuration: number,
	MaxVariantDuration: number,
	Volume: number,
	IndoorVolume: number,
	FadeTime: number,
}

export type SplashConfig = {
	Enabled: boolean,
	MaxSplashes: number,
	Rate: number,
	Radius: number,
	RayDepth: number,
	Lifetime: number,
	Size: number,
	Spread: number,
	Height: number,
}

export type Config = {
	Seed: number?,
	InitialWeather: string,
	AllowRepeats: boolean,
	SnapshotInterval: number,
	Definitions: { Definition },
	Precipitation: {
		Enabled: boolean,
		TemplateFolder: string,
		Height: number,
		AreaSize: number,
		MaxParticles: number,
		RainSpeed: number,
		SnowSpeed: number,
		SpeedVariation: number,
		SpeedTransitionTime: number,
		WindInfluence: number,
		OcclusionInterval: number,
		SkyCheckHeight: number,
		RainAudio: RainAudioConfig,
		Splashes: SplashConfig,
	},
}

export type Snapshot = {
	Version: number,
	Sequence: number,
	Seed: number,
	Current: string,
	Next: string,
	StartedAt: number,
	TransitionAt: number,
	EndsAt: number,
	ServerTime: number,
	TransitionProgress: number,
	TimeRemaining: number,
	FromEnvironment: Environment?,
}

return {}
