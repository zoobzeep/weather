# Weather

Weather system made for Roblox created using typed LuaU and Rojo

# Force weather

```lua
local WeatherService = require(game.ServerScriptService.WeatherServer.Services.WeatherService)
WeatherService.ForceWeather("Rain", 90)
```
Change the first argument to whatever event you want that's included in `src/shared/Config/WeatherConfig.luau`

# Configs

All of these will be found inside of `src/shared/Config/WeatherConfig.luau` or `src/shared/Config/SimulationConfig.luau`

| Field | Meaning |
| --- | --- |
| `Version` | Snapshot schema, currently 1 |
| `Sequence` | Increasing cycle number, beginning at 1 |
| `Seed` | Actual seed used by this server |
| `Current`, `Next` | Source and target weather IDs |
| `StartedAt`, `TransitionAt`, `EndsAt` | Absolute server timestamps |
| `ServerTime` | Timestamp when the snapshot was sampled |
| `TransitionProgress` | Linear blend progress at the snapshot timestamp, from 0 to 1 |
| `TimeRemaining` | Seconds until `Next` is fully established, including any remaining hold |

| Channel | Payload and frequency |
| --- | --- |
| `WeatherTime` | Full clock anchor/settings JSON at startup and on server API changes only |
| `WeatherLightning` | Latest strike ID, future timestamp, position, and shared bolt points, once per strike |
| `WeatherSnow/<surface ID>` | Latest full quantized depth array per changed surface, normally once per second |

| Option | Accepted values and behavior |
| --- | --- |
| `Seed` | Integer 1–2147483646; `nil` chooses a server seed, included in every snapshot |
| `InitialWeather` | ID of an existing definition; may have zero weight |
| `AllowRepeats` | If false, at least two definitions must have positive weights |
| `SnapshotInterval` | 0.1–60 seconds; default 0.5 |
| `Definitions` | Dense, ordered array of 1–100 definitions with unique nonempty IDs |
| `Weight` | 0–1000000; zero disables random selection of that definition |
| `MinDuration`, `MaxDuration` | Hold bounds, 0.1–86400 seconds, minimum no greater than maximum |
| `TransitionTime` | Incoming blend duration, 0–3600 seconds |

| Fields | Validation |
| --- | --- |
| `Brightness`, `AtmosphereGlare`, `AtmosphereHaze` | Finite numbers, 0–10 |
| `ExposureCompensation` | Finite number, -5–5 |
| `AtmosphereDensity`, `CloudCover`, `CloudDensity` | Finite numbers, 0–1 |
| `AtmosphereOffset` | Finite number, -1–1 |
| `Ambient`, `OutdoorAmbient`, `AtmosphereColor`, `AtmosphereDecay`, `CloudColor` | Color3 with channels 0–1 |
| `Wind` | Vector3 with each component from -1000 to 1000 |
| `RainRate`, `SnowRate` | Intensity, 0–1000; geometry observes its budget, custom emitters use particles/second |
| `Temperature` | Base temperature in Celsius, -80–60; blended across weather states |
| `Sunshine` | 0–1 solar exposure factor for daylight-driven melting |

| Setting | Default | Meaning |
| --- | --- | --- |
| `InitialTime` | 9 | Initial ClockTime, 0–24; 24 wraps to 0 |
| `DayDuration` | 1200 | Real seconds per full 24-hour day at speed 1, from 10 to 604800 |
| `Speed` | 1 | Time multiplier, 0–100; 0 holds the current time |
| `Paused` | false | Whether the clock starts paused |
| `NightTemperatureDrop` | 5 | Maximum nighttime cooling below the weather temperature |
| `NightAmbientFactor` | 0.3 | Fraction of weather ambient light retained at night |

| Settings | Defaults | Purpose |
| --- | --- | --- |
| `FirstStrikeDelay` | 3 seconds | Opening strike delay after entering a fully established storm |
| `MinInterval`, `MaxInterval` | 10, 22 seconds | Occasional random strike spacing; minimum permitted interval is 5 |
| `SevereFirstStrikeDelay` | 0.5 seconds | Severe storm opening strike delay |
| `SevereMinInterval`, `SevereMaxInterval` | 1.5, 3 seconds | Rapid random strike spacing during severe storms |
| `LeadTime` | 0.5 seconds | Advance notice for a shared future strike timestamp |
| `Radius`, `Height` | 180, 120 studs | Horizontal placement range and bolt height |
| `Segments`, `Jitter`, `Width` | 12, 12, 0.35 | Procedural bolt shape |
| `FlashDuration`, `FlashBrightness` | 0.22 seconds, 0.5 | Brief owned ColorCorrectionEffect flash |
| `ThunderSoundId` | `rbxassetid://123456` | Audio for thunder, empty string disables audio |
| `SoundSpeed` | 1125 studs/second | Configurable propagation speed in world units |
| `MaxSoundDistance`, `Volume` | 4000 studs, 0.6 | Thunder audibility and volume |
| `SoundLifetime` | 20 seconds | Sound cleanup deadline after its arrival time |

| Attribute | Default | Valid range / meaning |
| --- | --- | --- |
| `SnowCellSize` | 0.5 studs | 0.2–4; grid cells fit the surface exactly and are no larger than this target |
| `SnowMaxDepth` | 0.6 studs | 0.02–3; maximum snow depth above the original top face |
| `SnowAccumulationMultiplier` | 1 | 0–10; use 0 for surfaces that should receive no new snow |
| `SnowMeltMultiplier` | 1 | 0–10; scales solar and temperature-driven melting |

| Setting | Default | Purpose |
| --- | --- | --- |
| `Enabled` | true | Disable all rain/snow precipitation presentation |
| `AreaSize` | 40 | Width/depth of the camera-centered field, 1–500 studs |
| `Height` | 25 | Field extends this far above/below the camera; custom emitter sits above it |
| `MaxParticles` | 240 | Combined built-in rain/snow Part budget, integer 1–600 |
| `RainSpeed` | 65 | Rain fall speed, 1–200 studs/second |
| `SnowSpeed` | 50 | Snow fall speed, 1–50 studs/second |
| `SpeedVariation` | 0.15 | Per-particle speed spread around each fall speed, 0–0.5 |
| `SpeedTransitionTime` | 3 | Seconds for a pooled particle to ease to its new type's speed, 0.05–5 |
| `WindInfluence` | 0.35 | Horizontal wind multiplier, 0–2 |
| `OcclusionInterval` | 0.2 | Maximum normal interval between column probes, 0.05–1 seconds |
| `SkyCheckHeight` | 256 | Extra height above the field for roof detection, 1–2000 studs |
| `TemplateFolder` | WeatherEffects | Optional Studio-authored emitter overrides |

| Setting | Default | Purpose |
| --- | --- | --- |
| `Enabled` | true | Enable the local rain loop |
| `Bands` | Light / Moderate / Heavy | Ordered bands with Name, MaxRate, and SoundIds arrays |
| `Hysteresis` | 10 | Margin around the current band's thresholds before changing intensity |
| `MinVariantDuration`, `MaxVariantDuration` | 35, 60 seconds | Random interval before choosing another matching clip |
| `Volume` | 0.45 | Volume at RainRate 180; heavier rain scales up to 1.5 times this value |
| `IndoorVolume` | 0.2 | Sheltered volume multiplier, 0–1 |
| `FadeTime` | 0.8 seconds | Exponential volume/muffling smoothing time constant |

| Setting | Default | Purpose |
| --- | --- | --- |
| `Enabled` | true | Enable local impacts |
| `MaxSplashes` | 32 | Reused impact slots, four non-colliding Parts per slot |
| `Rate` | 45 | Candidate impacts/second at RainRate 180; misses produce nothing |
| `Radius` | 18 studs | Sampling radius around the camera |
| `RayDepth` | 120 studs | Search distance below the camera and maximum hit height difference |
| `Lifetime` | 0.3 seconds | Time for droplets to spread and fade |
| `Size`, `Spread`, `Height` | 0.08, 0.35, 0.2 studs | Droplet diameter, outward travel, and arc height |
