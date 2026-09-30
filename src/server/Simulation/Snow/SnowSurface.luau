--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SimulationTypes = require(ReplicatedStorage.Weather.Types.SimulationTypes)
local SimulationValidation = require(ReplicatedStorage.Weather.Validation.SimulationValidation)

local SnowSurface = {}

function SnowSurface.Read(
	part: Instance,
	id: string,
	config: SimulationTypes.SnowConfig
): SimulationTypes.Surface
	assert(
		part:IsA("Part") and part.Shape == Enum.PartType.Block,
		"SnowSurface supports only block Parts, not Terrain, meshes, wedges, or unions"
	)
	assert(
		part.Anchored and part.CanQuery and part.CanCollide,
		"SnowSurface must be anchored, queryable, and solid"
	)
	assert(part:IsDescendantOf(Workspace), "SnowSurface must be in Workspace")
	assert(
		part.CFrame.UpVector:Dot(Vector3.yAxis) > 0.99999,
		"SnowSurface must be horizontal and face upward"
	)
	local function attribute(name: string, default: number, minimum: number, maximum: number): number
		local value = part:GetAttribute(name)
		return SimulationValidation.Number(if value == nil then default else value, name, minimum, maximum)
	end
	local cellSize = attribute("SnowCellSize", config.CellSize, 0.2, 4)
	local columns = math.ceil(part.Size.X / cellSize)
	local rows = math.ceil(part.Size.Z / cellSize)
	assert(columns * rows <= config.MaxCellsPerSurface, "SnowSurface exceeds MaxCellsPerSurface")
	return {
		Id = id,
		Frame = part.CFrame,
		Size = part.Size,
		Columns = columns,
		Rows = rows,
		MaxDepth = attribute("SnowMaxDepth", config.MaxDepth, 0.02, 3),
		AccumulationMultiplier = attribute("SnowAccumulationMultiplier", 1, 0, 10),
		MeltMultiplier = attribute("SnowMeltMultiplier", 1, 0, 10),
	}
end

return SnowSurface
