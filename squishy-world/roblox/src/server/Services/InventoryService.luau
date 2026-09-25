--!strict
-- Inventario: equipar (compañero), favorito, vender, vender repetidos, capacidad.
-- Porte de renderInvDetail / sellItems / sellDupes de game5.js.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Profile = require(Shared.Logic.Profile)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MonetizationService = require(script.Parent.MonetizationService)
local Net = require(script.Parent.Net)

local InventoryService = {}

function InventoryService.capacity(player: Player, d: Types.PlayerData): number
	local cap = Profile.baseCapacity(d)
	if MonetizationService.hasPass(player, "bigBag") then
		cap += Config.Monetization.EFFECTS.bigBagSlots
	end
	return cap
end

function InventoryService.isFull(player: Player, d: Types.PlayerData): boolean
	return #d.inventory >= InventoryService.capacity(player, d)
end

--- Publica el compañero equipado como atributo del jugador; cada cliente lo dibuja (Companion.luau).
function InventoryService.refreshCompanion(player: Player)
	local d = DataService.get(player)
	local s = d and d.equipped and Profile.find(d, d.equipped)
	if s then
		player:SetAttribute(
			"Companion",
			HttpService:JSONEncode({
				id = s.id,
				species = s.species,
				variant = s.variant,
				mutation = s.mutation,
				rarity = s.rarity,
				size = s.size,
				name = s.name,
				face = s.face,
			})
		)
	else
		player:SetAttribute("Companion", nil)
	end
end

--- Agrega al inventario (sin revisar capacidad) y marca el Índice. Devuelve true si es nuevo.
function InventoryService.add(player: Player, d: Types.PlayerData, s: Types.SquishyData): boolean
	table.insert(d.inventory, s)
	local k = Profile.idxKey(s)
	local isNew = not d.discovered[k]
	if isNew then
		d.discovered[k] = true
		Economy.questEvent(player, "index", Profile.discoveredCount(d), true)
	end
	DataService.changed(player)
	return isNew
end

--- Quita del inventario sin pagar (intercambios). Devuelve el squishy quitado.
function InventoryService.take(player: Player, d: Types.PlayerData, id: string): Types.SquishyData?
	local s, i = Profile.find(d, id)
	if not s or not i then
		return nil
	end
	table.remove(d.inventory, i)
	if d.equipped == id then
		d.equipped = nil
		InventoryService.refreshCompanion(player)
	end
	DataService.changed(player)
	return s
end

local function countKey(d: Types.PlayerData, k: string): number
	local n = 0
	for _, x in d.inventory do
		if Profile.idxKey(x) == k then
			n += 1
		end
	end
	return n
end

--- Vende una lista de ids (se saltan favoritos y el equipado). Devuelve el total ganado.
function InventoryService.sell(player: Player, d: Types.PlayerData, ids: { string }): number
	local base, dupe = 0, false
	for _, id in ids do
		local s, i = Profile.find(d, id)
		if s and i and not s.fav and d.equipped ~= s.id then
			if countKey(d, Profile.idxKey(s)) > 1 then
				dupe = true
			end
			table.remove(d.inventory, i)
			base += s.value
			d.stats.sold += 1
		end
	end
	if base <= 0 then
		return 0
	end
	local got = Economy.earnCoins(player, base)
	Net.sound(player, "coins")
	Net.toast(player, string.format("Vendido por %s monedas", Format.int(got)))
	if dupe then
		Economy.questEvent(player, "sellDupe", 1)
	end
	DataService.changed(player)
	return got
end

local function dupesToSell(d: Types.PlayerData): { string }
	local groups: { [string]: { Types.SquishyData } } = {}
	for _, s in d.inventory do
		local k = Profile.idxKey(s)
		groups[k] = groups[k] or {}
		table.insert(groups[k], s)
	end
	local out = {}
	for _, g in groups do
		if #g >= 2 then
			table.sort(g, function(a, b)
				local af, bf = a.fav and 1 or 0, b.fav and 1 or 0
				if af ~= bf then
					return af > bf
				end
				local ae, be = (a.id == d.equipped) and 1 or 0, (b.id == d.equipped) and 1 or 0
				if ae ~= be then
					return ae > be
				end
				return a.value > b.value
			end)
			for i = 2, #g do
				if not g[i].fav and g[i].id ~= d.equipped then
					table.insert(out, g[i].id)
				end
			end
		end
	end
	return out
end

function InventoryService.init()
	DataService.onLoaded(function(player)
		InventoryService.refreshCompanion(player)
	end)
	DataService.addViewProvider(function(player, view)
		local d = DataService.get(player)
		if d then
			view.capacity = InventoryService.capacity(player, d)
		end
	end)

	Net.on("inv", function(player, payload)
		local d = DataService.get(player)
		if not d then
			return { ok = false }
		end
		local op = payload.op
		local id = payload.id
		if op == "sellDupes" then
			local ids = dupesToSell(d)
			if #ids == 0 then
				Net.toast(player, "No tienes repetidos para vender")
				Net.sound(player, "error")
				return { ok = false }
			end
			if payload.preview then
				local total = 0
				for _, x in ids do
					local s = Profile.find(d, x)
					total += if s then s.value else 0
				end
				return { ok = true, count = #ids, total = total }
			end
			return { ok = true, got = InventoryService.sell(player, d, ids) }
		end
		if type(id) ~= "string" then
			return { ok = false, err = "id" }
		end
		local s = Profile.find(d, id)
		if not s then
			return { ok = false, err = "no_existe" }
		end
		if op == "equip" then
			d.equipped = if d.equipped == id then nil else id
			InventoryService.refreshCompanion(player)
			if d.equipped then
				Net.toast(player, string.format("¡%s te está siguiendo!", s.name))
				if d.tutorial == 4 then
					d.tutorial = 5
				end
			end
			DataService.changed(player)
		elseif op == "fav" then
			s.fav = not s.fav
			DataService.changed(player)
		elseif op == "sell" then
			return { ok = InventoryService.sell(player, d, { id }) > 0 }
		else
			return { ok = false, err = "op" }
		end
		return { ok = true }
	end)

	-- Apachurrones: +2 XP cada 15 (SYSTEMS_SPEC §2). El cliente avisa cada apachurrón.
	local lastSquish: { [Player]: number } = {}
	Net.on("squish", function(player)
		local d = DataService.get(player)
		if not d then
			return { ok = false }
		end
		local now = os.clock()
		if now - (lastSquish[player] or 0) < 0.25 then
			return { ok = false, err = "rate" }
		end
		lastSquish[player] = now
		d.stats.squishes += 1
		if d.stats.squishes % 15 == 0 then
			Economy.addXP(player, 2)
		end
		DataService.changed(player)
		return { ok = true }
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastSquish[p] = nil
	end)

	Net.on("tutorial", function(player, payload)
		local d = DataService.get(player)
		local step = payload.step
		if d and type(step) == "number" and step > d.tutorial and step <= 5 then
			d.tutorial = math.floor(step)
			DataService.changed(player)
		end
		return { ok = true }
	end)
	Net.on("setMuted", function(player, payload)
		local d = DataService.get(player)
		if d then
			d.muted = payload.v == true
			DataService.changed(player)
		end
		return { ok = true }
	end)
	Net.on("tourSeen", function(player)
		local d = DataService.get(player)
		if d then
			d.tourSeen = true
			DataService.changed(player)
		end
		return { ok = true }
	end)
end

return InventoryService
