--!strict
-- AUTOGENERADO desde reference/src-js/game1.js (prototipo HTML). No editar a mano los números:
-- si cambian en el prototipo, regenerar. Nombres visibles en español, ids en inglés.
local Quests: { any } = {
	{ id = "fill3", title = "Llena 3 squishies", goal = 3, ev = "fill", reward = 250, target = "machines" },
	{
		id = "unc",
		title = "Descubre un squishy Poco común",
		goal = 1,
		ev = "getUncommon",
		reward = 150,
		target = "machines",
	},
	{ id = "dupe", title = "Vende un repetido", goal = 1, ev = "sellDupe", reward = 150 },
	{
		id = "speed",
		title = "Mejora la Velocidad en la Tienda",
		goal = 1,
		ev = "upFill",
		reward = 200,
		target = "shop",
	},
	{
		id = "perfect",
		title = "Consigue 3 llenados Perfectos",
		goal = 3,
		ev = "perfect",
		reward = 300,
		target = "machines",
	},
	{
		id = "lvl3",
		title = "Llega a nivel 3 para desbloquear la Rana",
		goal = 3,
		ev = "level",
		reward = 250,
		target = "machines",
	},
	{ id = "rare", title = "Descubre un squishy Raro", goal = 1, ev = "getRare", reward = 500, target = "machines" },
	{
		id = "trade",
		title = "Haz un intercambio en la Plaza",
		goal = 1,
		ev = "trade",
		reward = 400,
		target = "trading",
	},
	{
		id = "idx15",
		title = "Descubre 15 squishies en el Índice",
		goal = 15,
		ev = "index",
		reward = 800,
		target = "collection",
	},
	{ id = "epic", title = "Descubre un squishy Épico", goal = 1, ev = "getEpic", reward = 1500, target = "machines" },
}
-- Al terminar la lista: misiones infinitas "Llena N squishies" (N = 5 + k*5, premio creciente). Ver docs/SYSTEMS_SPEC.md

return Quests
