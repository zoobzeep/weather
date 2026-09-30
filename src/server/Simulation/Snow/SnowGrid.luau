--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SnowMath = require(ReplicatedStorage.Weather.Math.SnowMath)

local SnowGrid = {}
SnowGrid.__index = SnowGrid

function SnowGrid.new(surface: SimulationTypes.Surface, config: SimulationTypes.SnowConfig)
	local count = surface.Columns * surface.Rows
	return setmetatable({
		Surface = surface,
		_config = config,
		_depths = table.create(count, 0) :: { number },
		_dents = table.create(count, 0) :: { number },
		_sent = {} :: { number },
		_revision = 0,
	}, SnowGrid)
end

function SnowGrid.GetDepth(self: SnowGrid, index: number): number
	return math.max(0, self._depths[index] - self._dents[index])
end

function SnowGrid.Advance(self: SnowGrid, elapsed: number, forcing: SimulationTypes.SnowForcing)
	assert(elapsed >= 0 and elapsed < math.huge, "Snow elapsed time must be finite and nonnegative")
	local config = self._config
	local snowfall = math.max(0, forcing.Snowfall) * config.AccumulationRate
	local accumulation = snowfall * self.Surface.AccumulationMultiplier * elapsed
	local solarMelt = forcing.Sunshine * forcing.Daylight * config.SunnyMeltRate
	local thermalMelt = math.max(0, forcing.Temperature)
		* config.TemperatureMeltRate
		* (0.25 + forcing.Daylight * 0.75)
	local melt = (solarMelt + thermalMelt) * self.Surface.MeltMultiplier * elapsed
	local refill = accumulation * config.FootprintRefillMultiplier
		+ melt
		+ config.FootprintSoftenRate * elapsed
	for index = 1, #self._depths do
		local depth = math.clamp(self._depths[index] + accumulation - melt, 0, self.Surface.MaxDepth)
		self._depths[index] = depth
		self._dents[index] = math.min(depth, math.max(0, self._dents[index] - refill))
	end
end

function SnowGrid.Footprint(self: SnowGrid, position: Vector3, direction: Vector3): number
	local surface = self.Surface
	local localPosition = surface.Frame:PointToObjectSpace(position)
	local localDirection = surface.Frame:VectorToObjectSpace(direction)
	local forward = Vector2.new(localDirection.X, localDirection.Z)
	if forward.Magnitude < 0.001 then
		return 0
	end
	forward = forward.Unit
	local right = Vector2.new(forward.Y, -forward.X)
	local sizeX = surface.Size.X / surface.Columns
	local sizeZ = surface.Size.Z / surface.Rows
	local radius = math.max(self._config.FootprintLength, self._config.FootprintWidth)
	local minColumn = math.max(0, math.floor((localPosition.X - radius + surface.Size.X / 2) / sizeX))
	local maxColumn =
		math.min(surface.Columns - 1, math.floor((localPosition.X + radius + surface.Size.X / 2) / sizeX))
	local minRow = math.max(0, math.floor((localPosition.Z - radius + surface.Size.Z / 2) / sizeZ))
	local maxRow =
		math.min(surface.Rows - 1, math.floor((localPosition.Z + radius + surface.Size.Z / 2) / sizeZ))
	local changed = 0
	for row = minRow, maxRow do
		for column = minColumn, maxColumn do
			local index = row * surface.Columns + column + 1
			local cell = SnowMath.Cell(surface, index)
			local offset = Vector2.new(cell.X - localPosition.X, cell.Z - localPosition.Z)
			local along = offset:Dot(forward) / (self._config.FootprintLength / 2)
			local width = self._config.FootprintWidth * (if along > 0 then 1 else 0.8)
			local across = offset:Dot(right) / (width / 2)
			local distance = along * along + across * across
			if distance <= 1 and self._depths[index] > 0 then
				local dent = math.min(
					self._depths[index],
					self._dents[index] + self._config.FootprintDepth * (1 - distance * 0.35)
				)
				if dent > self._dents[index] then
					self._dents[index] = dent
					changed += 1
				end
			end
		end
	end
	return changed
end

function SnowGrid.Snapshot(self: SnowGrid, force: boolean?): SimulationTypes.SnowState?
	local depths: { number } = table.create(#self._depths)
	local changed = force == true or self._revision == 0
	for index = 1, #self._depths do
		depths[index] = math.floor(self:GetDepth(index) / self._config.DepthQuantum + 0.000001)
		changed = changed or depths[index] ~= self._sent[index]
	end
	if not changed then
		return nil
	end
	self._revision += 1
	self._sent = depths
	return {
		Version = 1,
		Id = self.Surface.Id,
		Revision = self._revision,
		Columns = self.Surface.Columns,
		Rows = self.Surface.Rows,
		Quantum = self._config.DepthQuantum,
		Depths = table.clone(depths),
	}
end

export type SnowGrid = typeof(setmetatable({
	Surface = {} :: SimulationTypes.Surface,
	_config = {} :: SimulationTypes.SnowConfig,
	_depths = {} :: { number },
	_dents = {} :: { number },
	_sent = {} :: { number },
	_revision = 0,
}, SnowGrid))

return SnowGrid
