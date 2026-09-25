--!strict
-- Misiones (porte de currentQuest() en game5.js). Índice 1-based en Luau: quest.i = 1 es la primera.
local Config = require(script.Parent.Parent.Config)

export type Quest = { id: string, title: string, goal: number, ev: string, reward: number, target: string? }

local Quests = {}

function Quests.current(i: number): Quest
	local list = Config.Quests
	if i <= #list then
		return list[i] :: Quest
	end
	-- cadena infinita: "Llena N squishies", N = 5 + k·5, premio 500 + k·250
	local k = i - #list
	return {
		id = "loop" .. k,
		title = string.format("Llena %d squishies", 5 + k * 5),
		goal = 5 + k * 5,
		ev = "fill",
		reward = 500 + k * 250,
		target = "machines",
	}
end

return Quests
