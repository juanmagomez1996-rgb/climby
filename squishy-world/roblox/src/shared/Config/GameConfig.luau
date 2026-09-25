--!strict
-- AUTOGENERADO desde reference/src-js/game1.js (prototipo HTML). No editar a mano los números:
-- si cambian en el prototipo, regenerar. Nombres visibles en español, ids en inglés.
local GameConfig = {
	DEBUG = true,
	START = { coins = 500, level = 1, storage = 20 },
	PLAYER = { scale = 2, walk = 13, run = 22, radius = 1.3, turn = 12 },
	CAM = {
		dist = 14,
		min = 7,
		max = 24,
		lookH = 5.2,
		pitch = 0.28,
		pitchMin = -0.25,
		pitchMax = 1.05,
		sens = 0.0026,
		keyTurn = 2.2,
	},
	WORLD = { radius = 92 },
	FILL = {
		baseTime = 3.2,
		perfect = { 0.8, 0.9 },
		over = 1,
		pop = 1.16,
		minCommit = 0.35,
		process = 2.1,
	},
	INTERACT_DIST = 9,
	COMPANION = { offset = 3.2, lerp = 5 },
	NPC_BUBBLE_EVERY = { 7, 15 },
	AI_TIER = "quick",
	NOTE = "Unidades del prototipo three.js. Escala sugerida a studs: x1 (el prototipo ya usa ~2 unidades = squishy chico).",
	-- Bono de suerte por rareza (índice 1 = Común): peso = p · (1 + L · LUCK_TIER_BOOST[tier])
	LUCK_TIER_BOOST = { 0, 0.5, 1, 1.5, 2, 2.5 },
	-- Cera: máximo de capas acumuladas y grosor por capa (relativo al radio del squishy)
	WAX = { MAX_LAYERS = 6, THICK = 0.04 },
}

return GameConfig
