--!strict
-- Tipos compartidos. Mismo formato de datos que el prototipo (ver docs/ROBLOX_ARCHITECTURE.md §4).

export type WaxLayer = { c: string, s: number, b: { number } }
export type WaxState = { list: { WaxLayer } }

export type SquishyData = {
	id: string,
	species: string,
	rarity: string,
	variant: string,
	filling: string,
	mutation: string,
	face: string,
	size: number,
	value: number,
	name: string,
	dateFound: number,
	fav: boolean,
	wax: WaxState?,
}

export type PlayerData = {
	version: number,
	coins: number,
	xp: number,
	level: number,
	inventory: { SquishyData },
	equipped: string?,
	fillings: { string },
	molds: { string },
	upgrades: { fillSpeed: number, luck: number, storage: number },
	discovered: { [string]: boolean },
	quest: { i: number, p: number },
	stats: { [string]: number },
	tutorial: number,
	tourSeen: boolean,
	tipSquish: boolean,
	lastMold: string,
	lastFill: string,
	firstDone: boolean,
	-- monetización (ver Config/Monetization.luau)
	luckUntil: number, -- os.time() hasta cuando dura la Poción de Suerte
	legendFills: number, -- llenados Legendarios garantizados pendientes (producto "Molde de Oro")
	receipts: { string }, -- últimos PurchaseId procesados (evita dar dos veces la misma compra)
	robuxSpent: number,
	-- squishy que salió de la máquina y espera Guardar / Vender
	pending: SquishyData?,
}

export type FillResult = "under" | "perfect" | "over"

-- Lo que el servidor le manda al cliente en DataSync
export type ProfileView = PlayerData & {
	capacity: number,
	passes: { [string]: boolean },
	luckLeft: number,
	serverTime: number,
}

return {}
