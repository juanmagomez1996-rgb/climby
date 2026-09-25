--!strict
-- MONETIZACIÓN (Robux). Los ids se crean en el Creator Dashboard:
--   Game Passes:        Creator Dashboard → tu experiencia → Monetization → Passes → Create
--   Developer Products: Creator Dashboard → tu experiencia → Monetization → Developer Products
-- Pega cada id aquí. Mientras el id sea 0, en Studio la compra se SIMULA (se entrega sin cobrar)
-- para que puedas probar todo; en el juego publicado un id 0 simplemente no se muestra.
-- `robux` es solo el precio que se muestra en la UI si no se puede leer el real del Marketplace.

export type Pass = {
	id: number,
	key: string,
	name: string,
	desc: string,
	robux: number,
	icon: string,
}
export type Product = {
	id: number,
	key: string,
	name: string,
	desc: string,
	robux: number,
	icon: string,
	coins: number?,
	luckMinutes: number?,
	legendFills: number?,
}

local Monetization = {}

Monetization.PASSES = {
	{
		id = 0,
		key = "coins2x",
		name = "Monedas x2",
		desc = "Ganas el doble de monedas al vender y en las misiones. Para siempre.",
		robux = 199,
		icon = "🪙",
	},
	{
		id = 0,
		key = "luckPlus",
		name = "Súper Suerte",
		desc = "+25% de suerte permanente en todas las máquinas (como un Perfecto extra).",
		robux = 349,
		icon = "🍀",
	},
	{
		id = 0,
		key = "bigBag",
		name = "Mochila Gigante",
		desc = "+50 espacios de inventario para guardar más squishies.",
		robux = 149,
		icon = "🎒",
	},
	{
		id = 0,
		key = "vip",
		name = "VIP",
		desc = "Relleno Misterio gratis (sin pagar 100 por llenado), +10% monedas y etiqueta VIP.",
		robux = 399,
		icon = "👑",
	},
} :: { Pass }

Monetization.PRODUCTS = {
	{
		id = 0,
		key = "coinsS",
		name = "Bolsita de Monedas",
		desc = "+2.500 monedas",
		robux = 49,
		icon = "🪙",
		coins = 2500,
	},
	{
		id = 0,
		key = "coinsM",
		name = "Cofre de Monedas",
		desc = "+12.000 monedas",
		robux = 199,
		icon = "💰",
		coins = 12000,
	},
	{
		id = 0,
		key = "coinsL",
		name = "Montaña de Monedas",
		desc = "+60.000 monedas",
		robux = 799,
		icon = "🏦",
		coins = 60000,
	},
	{
		id = 0,
		key = "luck15",
		name = "Poción de Suerte",
		desc = "+50% de suerte por 15 minutos (se acumula).",
		robux = 99,
		icon = "🍀",
		luckMinutes = 15,
	},
	{
		id = 0,
		key = "legend1",
		name = "Molde de Oro",
		desc = "Tu próximo llenado sale Legendario sí o sí.",
		robux = 249,
		icon = "🌟",
		legendFills = 1,
	},
} :: { Product }

-- Efectos (el servidor los aplica; no cambiar sin avisar en PROGRESS.md → Decisiones)
Monetization.EFFECTS = {
	coins2xMult = 2, -- ventas + premios de misión
	vipCoinMult = 1.1,
	luckPlus = 0.25, -- se suma a L
	luckPotion = 0.5, -- se suma a L mientras dure
	bigBagSlots = 50,
}

Monetization.byKey = {} :: { [string]: Pass | Product }
Monetization.productById = {} :: { [number]: Product }
Monetization.passById = {} :: { [number]: Pass }
for _, p in Monetization.PASSES do
	Monetization.byKey[p.key] = p
	if p.id ~= 0 then
		Monetization.passById[p.id] = p
	end
end
for _, p in Monetization.PRODUCTS do
	Monetization.byKey[p.key] = p
	if p.id ~= 0 then
		Monetization.productById[p.id] = p
	end
end

return Monetization
