--!strict
-- Reglas puras de generación de squishies (porte exacto de game4.js / game2.js).
-- No toca Instances: se puede usar en servidor (autoridad) y en cliente (vista previa).
local Config = require(script.Parent.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Parent.Types)

local Squishy = {}
local LUCK_TIER_BOOST = (Config.Game :: any).LUCK_TIER_BOOST

--- Suerte total de un llenado (SYSTEMS_SPEC §4)
function Squishy.totalLuck(upgradeLuck: number, machine: any?, fillingId: string, fillResult: Types.FillResult?): number
	local fil = Catalog.FIL[fillingId] or {}
	local L = upgradeLuck * 0.06 + (machine and machine.luck or 0) + (fil.luck or 0)
	if fillResult == "perfect" then
		L += 0.25
	elseif fillResult == "under" then
		L -= 0.15
	elseif fillResult == "over" then
		L -= 0.1
	end
	return math.max(0, L)
end

function Squishy.rarityWeights(L: number, fillingId: string): { number }
	local fil = Catalog.FIL[fillingId] or {}
	local w = {}
	for i, r in Config.Rarities do
		local x = r.p * (1 + L * LUCK_TIER_BOOST[i])
		if r.id == "secret" and fil.secretX then
			x *= fil.secretX
		end
		w[i] = x
	end
	return w
end

local function weightedIndex(rng: Random, weights: { number }): number
	local tot = 0
	for _, x in weights do
		tot += x
	end
	local r = rng:NextNumber() * tot
	for i, x in weights do
		r -= x
		if r <= 0 then
			return i
		end
	end
	return #weights
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

function Squishy.value(d: any): number
	local sp, r, m = Catalog.SP[d.species], Catalog.R[d.rarity], Catalog.MUT[d.mutation]
	return math.round(sp.baseValue * r.mult * (m and m.mult or 1) * (d.size or 1))
end

--- "Gato Chicle Brillante", "Barra de Mantequilla", "Dona Glaseada Oro"
function Squishy.name(d: any): string
	local sp = Catalog.SP[d.species] or Catalog.SP.cat
	local v, m = Catalog.VAR[d.variant], Catalog.MUT[d.mutation]
	local n = sp.name
	if not (sp.famous and d.variant == "original") and v then
		n ..= " " .. v.name
	end
	if m and m.name and m.id ~= "normal" and m.name ~= "" then
		n ..= " " .. m.name
	end
	return n
end

export type GenOpts = { rarity: string?, variant: string?, mutation: string?, face: string?, machine: any? }

--- Genera un squishy nuevo. rng = Random.new() del servidor.
function Squishy.generate(
	rng: Random,
	speciesId: string,
	fillingId: string,
	L: number,
	opts: GenOpts?
): Types.SquishyData
	local o: GenOpts = opts or {}
	local rarity = o.rarity
	if not rarity then
		rarity = Config.Rarities[weightedIndex(rng, Squishy.rarityWeights(L, fillingId))].id
	end
	local fil = Catalog.FIL[fillingId] or {}
	local sp = Catalog.SP[speciesId]
	local variant = o.variant
	if not variant and sp and sp.famous and rarity == "common" then
		variant = "original"
	end
	if not variant then
		local pool = (Config.Variants :: any)[rarity]
		local biased = {}
		for _, v in pool do
			if fil.bias and table.find(fil.bias, v.id) then
				table.insert(biased, v)
			end
		end
		local chosen = (#biased > 0 and rng:NextNumber() < 0.55) and pick(rng, biased) or pick(rng, pool)
		variant = chosen.id
	end
	local mutation = o.mutation
	if not mutation then
		local mx = (o.machine and o.machine.mutX) or 1
		local w = {}
		for i, m in Config.Mutations do
			w[i] = m.id == "normal" and m.p or m.p * mx * ((fil.mut and fil.mut[m.id]) or 1)
		end
		mutation = Config.Mutations[weightedIndex(rng, w)].id
	end
	local faces = { "happy", "happy", "happy", "wink", "sleepy", "surprised" }
	local d: any = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		species = speciesId,
		rarity = rarity,
		variant = variant,
		filling = fillingId,
		mutation = mutation,
		face = o.face or pick(rng, faces),
		size = math.round((0.95 + rng:NextNumber() * 0.13) * 100) / 100,
		dateFound = os.time(),
		fav = false,
	}
	d.value = Squishy.value(d)
	d.name = Squishy.name(d)
	return d :: Types.SquishyData
end

function Squishy.xpNeed(level: number): number
	return 50 + (level - 1) * 30
end

--- Resultado del llenado a partir de p (SYSTEMS_SPEC §3). nil = todavía no cuenta.
function Squishy.fillResult(p: number): (Types.FillResult?, boolean)
	local F = Config.Game.FILL
	if p >= F.pop then
		return nil, true
	end
	if p < F.minCommit then
		return nil, false
	end
	if p < F.perfect[1] then
		return "under", false
	end
	if p <= F.perfect[2] then
		return "perfect", false
	end
	return "over", false
end

--- p después de mantener `held` segundos (integración de p += dt/time·(1 + 0.35p) a 120 Hz)
function Squishy.fillProgress(held: number, fillSpeedLevel: number): number
	local time = Config.Game.FILL.baseTime / (1 + 0.2 * (fillSpeedLevel - 1))
	local p, dt = 0, 1 / 120
	local t = 0
	while t < held do
		p += dt / time * (1 + p * 0.35)
		t += dt
	end
	return p
end

return Squishy
