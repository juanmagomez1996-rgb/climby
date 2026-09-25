--!strict
-- AUTOGENERADO desde reference/src-js/game1.js (prototipo HTML). No editar a mano los números:
-- si cambian en el prototipo, regenerar. Nombres visibles en español, ids en inglés.
local Variants: { [string]: { any } } = {
	common = {
		{ id = "classic", name = "Crema", c = "#F3E3CC", rarity = "common" },
		{ id = "pink", name = "Rosa", c = "#F7A7CD", rarity = "common" },
		{ id = "blue", name = "Azul", c = "#8BC7E8", rarity = "common" },
		{ id = "yellow", name = "Limón", c = "#F4D982", rarity = "common" },
		{ id = "green", name = "Verde", c = "#A6DB8E", rarity = "common" },
		{ id = "purple", name = "Lila", c = "#B999E8", rarity = "common" },
		{ id = "orange", name = "Naranja", c = "#F8B27C", rarity = "common" },
		{ id = "white", name = "Nieve", c = "#F8F6F2", rarity = "common" },
	},
	uncommon = {
		{ id = "mint", name = "Menta", c = "#9CE0CA", accent = "#fff", rarity = "uncommon" },
		{ id = "chocolate", name = "Chocolate", c = "#8A5A44", tex = "drizzle", rarity = "uncommon" },
		{ id = "bubblegum", name = "Chicle", c = "#FF8FC8", r = 0.38, rarity = "uncommon" },
		{ id = "cotton_candy", name = "Algodón de Azúcar", tex = "cotton", rarity = "uncommon" },
		{ id = "lavender", name = "Lavanda", c = "#CDB8F2", rarity = "uncommon" },
	},
	rare = {
		{ id = "strawberry", name = "Fresa", c = "#FF6F91", tex = "seeds", topper = "leaf", rarity = "rare" },
		{ id = "watermelon", name = "Sandía", tex = "melon", rarity = "rare" },
		{ id = "cloud", name = "Nube", c = "#FFFFFF", r = 0.95, extra = "puffs", rarity = "rare" },
		{ id = "ice", name = "Hielo", c = "#BDEBFF", r = 0.12, opacity = 0.86, rarity = "rare" },
		{ id = "honey", name = "Miel", c = "#F2B33D", r = 0.22, topper = "drip", rarity = "rare" },
	},
	epic = {
		{ id = "neon", name = "Neón", c = "#39FF9A", e = 0.85, anim = "neon", rarity = "epic" },
		{
			id = "crystal",
			name = "Cristal",
			c = "#A8E6FF",
			r = 0.04,
			m = 0.1,
			opacity = 0.74,
			flat = true,
			rarity = "epic",
		},
		{ id = "galaxy", name = "Galaxia", tex = "galaxy", e = 0.55, rarity = "epic" },
		{ id = "lava", name = "Lava", tex = "lava", e = 1, rarity = "epic" },
	},
	legendary = {
		{ id = "golden", name = "Oro", c = "#FFC93C", m = 0.8, r = 0.26, rarity = "legendary" },
		{ id = "rainbow", name = "Arcoíris", tex = "rainbow", rarity = "legendary" },
		{
			id = "celestial",
			name = "Celestial",
			c = "#EEF5FF",
			tex = "stars",
			e = 0.35,
			extra = "halo",
			rarity = "legendary",
		},
	},
	secret = {
		{ id = "glitched", name = "Glitch", tex = "glitch", anim = "glitch", e = 0.4, rarity = "secret" },
		{ id = "void", name = "Vacío", c = "#15121f", r = 0.3, extra = "aura", rarity = "secret" },
		{ id = "developer", name = "Dev", tex = "checker", e = 0.15, rarity = "secret" },
	},
}
-- 'original' (solo moldes virales, rareza común) = el look clásico definido en Species[i].orig

return Variants
