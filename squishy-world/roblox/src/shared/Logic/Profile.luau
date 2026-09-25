--!strict
-- Perfil del jugador: estado inicial (freshState() de game4.js) y migraciones.
local Config = require(script.Parent.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Squishy = require(script.Parent.Squishy)
local Types = require(script.Parent.Parent.Types)

local Profile = {}

Profile.VERSION = 1

function Profile.fresh(): Types.PlayerData
	local START = Config.Game.START
	return {
		version = Profile.VERSION,
		coins = START.coins,
		xp = 0,
		level = START.level,
		inventory = {},
		equipped = nil,
		fillings = { "classic_foam", "pink_foam", "blue_foam" },
		molds = { "butter" },
		upgrades = { fillSpeed = 1, luck = 0, storage = 0 },
		discovered = {},
		quest = { i = 1, p = 0 },
		stats = { fills = 0, perfect = 0, sold = 0, trades = 0, squishes = 0, bestRise = 0, waxCracked = 0 },
		tutorial = 0,
		tourSeen = false,
		tipSquish = false,
		muted = false,
		lastMold = "cat",
		lastFill = "pink_foam",
		firstDone = false,
		luckUntil = 0,
		legendFills = 0,
		receipts = {},
		robuxSpent = 0,
		pending = nil,
	}
end

--- Completa campos que falten (datos viejos) y corrige ids desconocidos, como loadGame() del prototipo.
function Profile.migrate(raw: any): Types.PlayerData
	local fresh: any = Profile.fresh()
	if type(raw) ~= "table" then
		return fresh
	end
	local d: any = raw
	for k, v in fresh do
		if d[k] == nil then
			d[k] = v
		end
	end
	for k, v in fresh.upgrades do
		if type(d.upgrades[k]) ~= "number" then
			d.upgrades[k] = v
		end
	end
	for k, v in fresh.stats do
		if type(d.stats[k]) ~= "number" then
			d.stats[k] = v
		end
	end
	if not table.find(d.molds, "butter") then
		table.insert(d.molds, "butter")
	end
	for _, q in d.inventory do
		if not Catalog.SP[q.species] then
			q.species = "cat"
		end
		if not Catalog.VAR[q.variant] then
			q.variant = "classic"
		end
		q.name = Squishy.name(q)
	end
	d.version = Profile.VERSION
	return d :: Types.PlayerData
end

function Profile.idxKey(d: { species: string, variant: string }): string
	return d.species .. "|" .. d.variant
end

function Profile.discoveredCount(d: Types.PlayerData): number
	local n = 0
	for _ in d.discovered do
		n += 1
	end
	return n
end

function Profile.baseCapacity(d: Types.PlayerData): number
	return Config.Upgrades.storage.caps[d.upgrades.storage + 1]
end

function Profile.moldAvailable(d: Types.PlayerData, speciesId: string): boolean
	local sp = Catalog.SP[speciesId]
	if not sp then
		return false
	end
	if sp.famous then
		return table.find(d.molds, speciesId) ~= nil
	end
	return d.level >= sp.unlockLevel
end

function Profile.find(d: Types.PlayerData, id: string): (Types.SquishyData?, number?)
	for i, s in d.inventory do
		if s.id == id then
			return s, i
		end
	end
	return nil, nil
end

return Profile
