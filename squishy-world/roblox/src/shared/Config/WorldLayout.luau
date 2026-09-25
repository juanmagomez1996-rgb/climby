--!strict
-- AUTOGENERADO desde el prototipo en ejecución: coordenadas de todos los puntos interactivos.
-- 1 unidad del prototipo = 1 stud (el personaje mide 5.4, igual que un avatar de Roblox).
-- El mapa importado (assets/world/mapa_completo.glb) coincide con estas posiciones si se ubica en el origen.

local WorldLayout = {
	spawn = Vector3.new(0, 0, 20),
	zones = {
		center = { center = Vector3.new(0, 0, 0) },
		machines = { center = Vector3.new(0, 0, 58), label = "Máquinas", color = Color3.fromHex("#F7A7CD") },
		collection = { center = Vector3.new(0, 0, -58), label = "Colección", color = Color3.fromHex("#B999E8") },
		shop = { center = Vector3.new(-58, 0, 0), label = "Tienda", color = Color3.fromHex("#F4D982") },
		trading = { center = Vector3.new(58, 0, 0), label = "Plaza de Intercambio", color = Color3.fromHex("#8BC7E8") },
	},
	machines = {
		{ id = "m1", pos = Vector3.new(0, 0, 60), dome = Vector3.new(0, 6.05, 60), level = 1 },
		{ id = "m2", pos = Vector3.new(-17, 0, 62), dome = Vector3.new(-17, 6.05, 62), level = 5 },
		{ id = "m3", pos = Vector3.new(17, 0, 62), dome = Vector3.new(17, 6.05, 62), level = 10 },
	},
	-- pedestales de la Colección (tus mejores squishies por rareza)
	pedestals = {
		{ rarity = "common", pos = Vector3.new(-11.59, 4.45, -60.08) },
		{ rarity = "uncommon", pos = Vector3.new(-7.97, 4.45, -63.11) },
		{ rarity = "rare", pos = Vector3.new(-2.84, 4.45, -64.78) },
		{ rarity = "epic", pos = Vector3.new(2.84, 4.45, -64.78) },
		{ rarity = "legendary", pos = Vector3.new(7.97, 4.45, -63.11) },
		{ rarity = "secret", pos = Vector3.new(11.59, 4.45, -60.08) },
	},
	-- Vitrina Viral: squishy de cada viral sobre su pedestal (rotY mira hacia afuera de la fuente)
	vitrina = {
		{ species = "butter", pos = Vector3.new(3.73, 1.45, 15.15), rotY = 0.242, scale = 1.05 },
		{ species = "toast", pos = Vector3.new(10.34, 1.45, 11.68), rotY = 0.725, scale = 1.05 },
		{ species = "cheese", pos = Vector3.new(14.59, 1.45, 5.53), rotY = 1.208, scale = 1.05 },
		{ species = "strawberry", pos = Vector3.new(15.49, 1.45, -1.88), rotY = 1.692, scale = 0.976 },
		{ species = "icecube", pos = Vector3.new(12.84, 1.45, -8.86), rotY = 2.175, scale = 1.05 },
		{ species = "egg", pos = Vector3.new(7.25, 1.45, -13.81), rotY = 2.658, scale = 0.944 },
		{ species = "dumpling", pos = Vector3.new(0, 1.45, -15.6), rotY = 3.142, scale = 0.847 },
		{ species = "dango", pos = Vector3.new(-7.25, 1.45, -13.81), rotY = 3.625, scale = 0.773 },
		{ species = "frogwell", pos = Vector3.new(-12.84, 1.45, -8.86), rotY = 4.108, scale = 0.882 },
		{ species = "donut", pos = Vector3.new(-15.49, 1.45, -1.88), rotY = 4.592, scale = 1.05 },
		{ species = "grapes", pos = Vector3.new(-14.59, 1.45, 5.53), rotY = 5.075, scale = 0.955 },
		{ species = "burger", pos = Vector3.new(-10.34, 1.45, 11.68), rotY = 5.558, scale = 0.82 },
		{ species = "catpaw", pos = Vector3.new(-3.73, 1.45, 15.15), rotY = 6.042, scale = 1.05 },
	},
	statue = { pos = Vector3.new(0, 6.25, 0), scale = 3.4 },
	shopCounter = Vector3.new(-60, 0, 0),
	npcHomes = {
		{ name = "SquishyMaya", home = "trading" },
		{ name = "FrogKid22", home = "trading" },
		{ name = "SoftBunny", home = "collection" },
		{ name = "PixelNoah", home = "trading" },
		{ name = "MochiStar", home = "center" },
		{ name = "CatCollector", home = "trading" },
		{ name = "LilyLoops", home = "machines" },
	},
	plazaRadius = 30,
	fountainRadius = 10.8,
	vitrinaRadius = 15.6,
	worldRadius = 92,
}

return WorldLayout
