--!strict

export type TimeConfig = {
	InitialTime: number,
	DayDuration: number,
	Speed: number,
	Paused: boolean,
	NightTemperatureDrop: number,
	NightAmbientFactor: number,
}

export type TimeState = {
	Version: number,
	Sequence: number,
	StartTimestamp: number,
	ClockTime: number,
	DayDuration: number,
	Speed: number,
	Paused: boolean,
}

export type LightningConfig = {
	Enabled: boolean,
	FirstStrikeDelay: number,
	MinInterval: number,
	MaxInterval: number,
	SevereFirstStrikeDelay: number,
	SevereMinInterval: number,
	SevereMaxInterval: number,
	LeadTime: number,
	Radius: number,
	Height: number,
	Segments: number,
	Jitter: number,
	Width: number,
	FlashDuration: number,
	FlashBrightness: number,
	ThunderSoundId: string,
	SoundSpeed: number,
	MaxSoundDistance: number,
	SoundLifetime: number,
	Volume: number,
}

export type Strike = {
	Version: number,
	Id: number,
	Timestamp: number,
	Position: { number },
	Points: { { number } },
}

export type SnowConfig = {
	Enabled: boolean,
	CellSize: number,
	MaxDepth: number,
	MaxCellsPerSurface: number,
	MaxTotalCells: number,
	SimulationInterval: number,
	ReplicationInterval: number,
	DepthQuantum: number,
	AccumulationRate: number,
	SunnyMeltRate: number,
	TemperatureMeltRate: number,
	FootprintDepth: number,
	FootprintLength: number,
	FootprintWidth: number,
	FootprintRefillMultiplier: number,
	FootprintSoftenRate: number,
	StepDistance: number,
	StepInterval: number,
	StepOffset: number,
	MaxStepSpeed: number,
	DrawDistance: number,
}

export type Config = {
	Time: TimeConfig,
	Lightning: LightningConfig,
	Snow: SnowConfig,
}

export type Surface = {
	Id: string,
	Frame: CFrame,
	Size: Vector3,
	Columns: number,
	Rows: number,
	MaxDepth: number,
	AccumulationMultiplier: number,
	MeltMultiplier: number,
}

export type SnowState = {
	Version: number,
	Id: string,
	Revision: number,
	Columns: number,
	Rows: number,
	Quantum: number,
	Depths: { number },
}

export type SnowForcing = {
	Snowfall: number,
	Sunshine: number,
	Daylight: number,
	Temperature: number,
}

return {}
