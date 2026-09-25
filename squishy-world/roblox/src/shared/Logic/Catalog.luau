--!strict
-- Índices rápidos sobre Config (equivalen a SP, R, VAR, FIL, MUT, variantsFor del prototipo).
local Config = require(script.Parent.Parent.Config)

local Catalog = {}

Catalog.SP = {} :: { [string]: any }
for _, s in Config.Species do
	Catalog.SP[s.id] = s
end

Catalog.R = {} :: { [string]: any }
Catalog.RTier = {} :: { [string]: number } -- 0 = Común … 5 = Secreto
for i, r in Config.Rarities do
	Catalog.R[r.id] = r
	Catalog.RTier[r.id] = i - 1
end

Catalog.VAR = {} :: { [string]: any }
for rarity, list in Config.Variants :: any do
	for _, v in list do
		v.rarity = rarity
		Catalog.VAR[v.id] = v
	end
end
-- look clásico de los virales (solo rareza común)
Catalog.VAR.original = { id = "original", name = "Original", rarity = "common", famousOnly = true }

Catalog.FIL = {} :: { [string]: any }
for _, f in Config.Fillings do
	Catalog.FIL[f.id] = f
end

Catalog.MUT = {} :: { [string]: any }
for _, m in Config.Mutations do
	Catalog.MUT[m.id] = m
end

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "secret" }

function Catalog.variantsFor(speciesId: string): { string }
	local sp = Catalog.SP[speciesId]
	local out = {}
	if sp and sp.famous then
		table.insert(out, "original")
		for i = 2, #RARITY_ORDER do
			for _, v in (Config.Variants :: any)[RARITY_ORDER[i]] do
				table.insert(out, v.id)
			end
		end
	else
		for _, rid in RARITY_ORDER do
			for _, v in (Config.Variants :: any)[rid] do
				table.insert(out, v.id)
			end
		end
	end
	return out
end

function Catalog.indexTotal(): number
	local n = 0
	for _, s in Config.Species do
		n += #Catalog.variantsFor(s.id)
	end
	return n -- debe dar 413
end

return Catalog
