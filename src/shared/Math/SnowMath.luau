--!strict

local SimulationTypes = require(script.Parent.Parent.Types.SimulationTypes)
local SnowMath = {}

function SnowMath.Cell(surface: SimulationTypes.Surface, index: number): Vector3
	local column = (index - 1) % surface.Columns
	local row = math.floor((index - 1) / surface.Columns)
	return Vector3.new(
		-surface.Size.X / 2 + (column + 0.5) * surface.Size.X / surface.Columns,
		surface.Size.Y / 2,
		-surface.Size.Z / 2 + (row + 0.5) * surface.Size.Z / surface.Rows
	)
end

function SnowMath.IsValid(state: any, maxCells: number): boolean
	if type(state) ~= "table" or state.Version ~= 1 or type(state.Id) ~= "string" then
		return false
	end
	for _, key in { "Revision", "Columns", "Rows" } do
		local value = state[key]
		if type(value) ~= "number" or value < 1 or value > 2147483646 or value % 1 ~= 0 then
			return false
		end
	end
	local count = state.Columns * state.Rows
	if count > maxCells or type(state.Depths) ~= "table" or #state.Depths ~= count then
		return false
	end
	if type(state.Quantum) ~= "number" or not (state.Quantum >= 0.001 and state.Quantum <= 0.05) then
		return false
	end
	for _, depth in state.Depths do
		if type(depth) ~= "number" or depth < 0 or depth > 3000 or depth % 1 ~= 0 then
			return false
		end
	end
	return true
end

return SnowMath
