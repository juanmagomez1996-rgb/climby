--!strict
-- AUTOGENERADO desde reference/src-js/game1.js (prototipo HTML). No editar a mano los números:
-- si cambian en el prototipo, regenerar. Nombres visibles en español, ids en inglés.
local Upgrades = {
	fillSpeed = {
		name = "Velocidad",
		desc = "Los squishies se llenan más rápido.",
		costs = { 300, 700, 1500, 3000, 6000 },
		max = 6,
	},
	luck = {
		name = "Suerte",
		desc = "+6% de probabilidad de rarezas altas por nivel.",
		costs = { 400, 1000, 2500, 6000, 12000 },
		max = 5,
		start = 0,
	},
	storage = {
		name = "Espacio",
		desc = "Guarda más squishies.",
		costs = { 500, 1200, 3000, 7000, 15000 },
		caps = { 20, 30, 50, 75, 100, 150 },
		max = 6,
	},
}

return Upgrades
