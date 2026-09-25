--!strict
-- Intercambios (SYSTEMS_SPEC §5):
--   • Con NPC: igual que el prototipo (trade de game5.js): tú ofreces hasta 3, el NPC propone uno
--     de valor ≈ tu oferta · random(0.85, 1.35); acepta si valorMío ≥ 0.8 · valorSuyo; 3 "¿y otro?".
--   • Jugador ↔ jugador: solicitud → sala → cada uno pone hasta 6 → "Listo" los dos → "Confirmar"
--     los dos (doble confirmación). Cualquier cambio reinicia las confirmaciones. Al final el servidor
--     re-valida todo (dueño, capacidad) y hace el cambio de una sola vez: nada se duplica ni se pierde.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Logic.Catalog)
local Profile = require(Shared.Logic.Profile)
local Remotes = require(Shared.Remotes)
local Squishy = require(Shared.Logic.Squishy)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local InventoryService = require(script.Parent.InventoryService)
local Net = require(script.Parent.Net)

local TradeService = {}
local rng = Random.new()

-- NpcService registra aquí cómo encontrar a un NPC (para validar distancia y hacerlo hablar).
local npcLookup: (name: string) -> Model? = function()
	return nil
end
local npcSay: (name: string, text: string) -> () = function() end
function TradeService.setNpcHooks(lookup: (string) -> Model?, say: (string, string) -> ())
	npcLookup = lookup
	npcSay = say
end

local NPC_RANGE = 24
local P2P_MAX = 6
local REQUEST_TTL = 25

--- Lista de ids limpia: solo strings, sin repetidos, que existan, no equipados, máximo `max`.
--- (No confiar en #ids: una tabla con claves de texto tiene # = 0 pero igual se recorre.)
local function cleanIds(d: Types.PlayerData, ids: any, max: number): { string }?
	if type(ids) ~= "table" then
		return nil
	end
	local n = 0
	for _ in ids do
		n += 1
		if n > max then
			return nil
		end
	end
	local clean = {}
	for i = 1, n do
		local id = ids[i]
		if type(id) == "string" and id ~= d.equipped and Profile.find(d, id) and not table.find(clean, id) then
			table.insert(clean, id)
		end
	end
	return clean
end

local npcDefByName: { [string]: any } = {}
for _, n in Config.NpcDefs do
	npcDefByName[n.name] = n
end

-- ─────────────────────────── NPC ───────────────────────────
type NpcSession = { npc: string, mine: { string }, theirs: Types.SquishyData?, rerolls: number }
local npcSessions: { [Player]: NpcSession } = {}

local function near(player: Player, model: Model?, range: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not model then
		return false
	end
	return (model:GetPivot().Position - root.Position).Magnitude <= range
end

local function valueOf(d: Types.PlayerData, ids: { string }): number
	local v = 0
	for _, id in ids do
		local s = Profile.find(d, id)
		v += if s then s.value else 0
	end
	return v
end

local function npcOffer(d: Types.PlayerData, sess: NpcSession)
	local myVal = valueOf(d, sess.mine)
	if myVal <= 0 then
		sess.theirs = nil
		return
	end
	local def = npcDefByName[sess.npc]
	local target = myVal * (0.85 + rng:NextNumber() * 0.5)
	local best: Types.SquishyData? = nil
	local bd = math.huge
	local catBase = Catalog.SP.cat.baseValue
	for _ = 1, 60 do
		-- rareza con peso 1 si su valor típico está cerca del objetivo, 0.02 si no
		local weights = {}
		local tot = 0
		for i, r in Config.Rarities do
			local w = if math.abs(math.log((catBase * r.mult) / target)) < 1.6 then 1 else 0.02
			weights[i] = w
			tot += w
		end
		local x = rng:NextNumber() * tot
		local rar = Config.Rarities[#Config.Rarities].id
		for i, w in weights do
			x -= w
			if x <= 0 then
				rar = Config.Rarities[i].id
				break
			end
		end
		local species = if rng:NextNumber() < 0.5 and def
			then def.fav
			else Config.Species[rng:NextInteger(1, #Config.Species)].id
		local cand = Squishy.generate(rng, species, "classic_foam", 0, { rarity = rar })
		local diff = math.abs(cand.value - target)
		if diff < bd then
			bd = diff
			best = cand
		end
	end
	sess.theirs = best
end

local function npcState(d: Types.PlayerData, sess: NpcSession, msg: string?): { [string]: any }
	return {
		ok = true,
		npc = sess.npc,
		mine = sess.mine,
		theirs = sess.theirs,
		myVal = valueOf(d, sess.mine),
		theirVal = if sess.theirs then sess.theirs.value else 0,
		rerolls = sess.rerolls,
		msg = msg,
	}
end

local NPC_YES = { "¡Trato hecho! 🤝", "¡Un gusto cambiar contigo!", "GG, ¡buen cambio!" }

local function npcTrade(player: Player, payload: { [string]: any }): { [string]: any }
	local d = DataService.get(player)
	if not d then
		return { ok = false }
	end
	local op = payload.op
	if op == "open" then
		local name = payload.npc
		if type(name) ~= "string" or not npcDefByName[name] then
			return { ok = false }
		end
		if not near(player, npcLookup(name), NPC_RANGE) then
			return { ok = false, err = "Acércate más" }
		end
		local sess = { npc = name, mine = {}, theirs = nil, rerolls = 0 }
		npcSessions[player] = sess
		return npcState(d, sess)
	end
	local sess = npcSessions[player]
	if not sess then
		return { ok = false, err = "no_session" }
	end
	if op == "set" then
		local clean = cleanIds(d, payload.ids, 3)
		if not clean then
			return { ok = false }
		end
		sess.mine = clean
		npcOffer(d, sess)
		local msg = if sess.theirs then string.format('%s: "¿Qué tal mi %s?"', sess.npc, sess.theirs.name) else nil
		return npcState(d, sess, msg)
	elseif op == "reroll" then
		if sess.rerolls >= 3 or #sess.mine == 0 then
			return { ok = false }
		end
		sess.rerolls += 1
		npcOffer(d, sess)
		return npcState(d, sess, string.format('%s: "Bueno, ¿y este?"', sess.npc))
	elseif op == "accept" then
		local theirs = sess.theirs
		if not theirs or #sess.mine == 0 then
			return { ok = false }
		end
		for _, id in sess.mine do
			if not Profile.find(d, id) or id == d.equipped then
				return { ok = false, err = "Ese squishy ya no está" }
			end
		end
		local myVal = valueOf(d, sess.mine)
		if myVal < theirs.value * 0.8 then
			npcSay(sess.npc, "Mmm…")
			return npcState(d, sess, string.format('%s: "Mmm, eso no alcanza para mi %s."', sess.npc, theirs.name))
		end
		for _, id in sess.mine do
			InventoryService.take(player, d, id)
		end
		theirs.id = HttpService:GenerateGUID(false)
		theirs.dateFound = os.time()
		if InventoryService.add(player, d, theirs) then
			Net.toast(player, string.format("Nuevo en tu Índice: %s", theirs.name))
		end
		d.stats.trades += 1
		Economy.questEvent(player, "trade", 1)
		Net.sound(player, "reward")
		Net.sound(player, "coins")
		npcSay(sess.npc, NPC_YES[rng:NextInteger(1, #NPC_YES)])
		Net.toast(player, string.format("¡Intercambio listo! Recibiste %s", theirs.name), true)
		npcSessions[player] = nil
		DataService.changed(player)
		return { ok = true, done = true }
	elseif op == "close" then
		npcSessions[player] = nil
		return { ok = true }
	end
	return { ok = false }
end

-- ─────────────────────────── Jugador ↔ jugador ───────────────────────────
type Side = { player: Player, items: { string }, ready: boolean, confirmed: boolean }
type Room = { a: Side, b: Side, phase: string }

local rooms: { [Player]: Room } = {}
local requests: { [Player]: { [Player]: number } } = {} -- requests[destino][origen] = hora

local function sideOf(room: Room, p: Player): (Side, Side)
	if room.a.player == p then
		return room.a, room.b
	end
	return room.b, room.a
end

local function itemsData(p: Player, ids: { string }): { Types.SquishyData }
	local d = DataService.get(p)
	local out = {}
	if d then
		for _, id in ids do
			local s = Profile.find(d, id)
			if s then
				table.insert(out, s)
			end
		end
	end
	return out
end

local function push(room: Room)
	for _, p in { room.a.player, room.b.player } do
		local me, them = sideOf(room, p)
		Remotes.event("TradeEvent"):FireClient(p, {
			t = "state",
			phase = room.phase,
			me = { items = itemsData(p, me.items), ready = me.ready, confirmed = me.confirmed },
			them = {
				name = them.player.DisplayName,
				userId = them.player.UserId,
				items = itemsData(them.player, them.items),
				ready = them.ready,
				confirmed = them.confirmed,
			},
		})
	end
end

local function closeRoom(room: Room, reason: string?)
	for _, p in { room.a.player, room.b.player } do
		if rooms[p] == room then
			rooms[p] = nil
		end
		if p.Parent then
			Remotes.event("TradeEvent"):FireClient(p, { t = "closed", reason = reason })
		end
	end
end

local function resetConfirms(room: Room)
	room.a.ready, room.b.ready = false, false
	room.a.confirmed, room.b.confirmed = false, false
	room.phase = "offer"
end

local function execute(room: Room): (boolean, string?)
	local pa, pb = room.a.player, room.b.player
	local da, db = DataService.get(pa), DataService.get(pb)
	if not da or not db then
		return false, "Un jugador no está disponible"
	end
	-- re-validar dueño y que no esté equipado
	local function valid(d: Types.PlayerData, ids: { string }): boolean
		for _, id in ids do
			if not Profile.find(d, id) or d.equipped == id then
				return false
			end
		end
		return true
	end
	if not valid(da, room.a.items) or not valid(db, room.b.items) then
		return false, "Un squishy de la oferta ya no está"
	end
	if #room.a.items == 0 and #room.b.items == 0 then
		return false, "La oferta está vacía"
	end
	-- capacidad
	if #da.inventory - #room.a.items + #room.b.items > InventoryService.capacity(pa, da) then
		return false, pa.DisplayName .. " no tiene espacio"
	end
	if #db.inventory - #room.b.items + #room.a.items > InventoryService.capacity(pb, db) then
		return false, pb.DisplayName .. " no tiene espacio"
	end
	-- cambio atómico (todo en el mismo frame, sin yields)
	local fromA: { Types.SquishyData } = {}
	local fromB: { Types.SquishyData } = {}
	for _, id in room.a.items do
		local s = InventoryService.take(pa, da, id)
		if s then
			table.insert(fromA, s)
		end
	end
	for _, id in room.b.items do
		local s = InventoryService.take(pb, db, id)
		if s then
			table.insert(fromB, s)
		end
	end
	for _, s in fromA do
		s.fav = false
		InventoryService.add(pb, db, s)
	end
	for _, s in fromB do
		s.fav = false
		InventoryService.add(pa, da, s)
	end
	local function finish(p: Player, d: Types.PlayerData)
		d.stats.trades += 1
		Economy.questEvent(p, "trade", 1)
		DataService.changed(p)
		Net.sound(p, "reward")
		Net.toast(p, "¡Intercambio listo! 🤝", true)
	end
	finish(pa, da)
	finish(pb, db)
	-- guardar ya a los dos para que un crash no deshaga solo la mitad
	task.spawn(DataService.saveNow, pa)
	task.spawn(DataService.saveNow, pb)
	return true, nil
end

local function p2p(player: Player, payload: { [string]: any }): { [string]: any }
	local d = DataService.get(player)
	if not d then
		return { ok = false }
	end
	local op = payload.op
	if op == "request" then
		local target = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
		if not target or target == player or not DataService.isLoaded(target) then
			return { ok = false, err = "Ese jugador no está disponible" }
		end
		if rooms[player] or rooms[target] then
			return { ok = false, err = "Ya hay un intercambio en curso" }
		end
		requests[target] = requests[target] or {};
		(requests[target] :: any)[player] = os.clock()
		Remotes.event("TradeEvent"):FireClient(target, {
			t = "request",
			from = player.UserId,
			name = player.DisplayName,
		})
		return { ok = true }
	elseif op == "respond" then
		local from = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
		local reqs = requests[player]
		local t = from and reqs and reqs[from]
		if not from or not reqs or not t then
			return { ok = false, err = "La solicitud ya no existe" }
		end
		reqs[from] = nil
		if os.clock() - t > REQUEST_TTL then
			return { ok = false, err = "La solicitud venció" }
		end
		if payload.accept ~= true then
			Net.toast(from, player.DisplayName .. " no quiso cambiar esta vez")
			return { ok = true }
		end
		if rooms[player] or rooms[from] then
			return { ok = false, err = "Ya hay un intercambio en curso" }
		end
		local room: Room = {
			a = { player = from, items = {}, ready = false, confirmed = false },
			b = { player = player, items = {}, ready = false, confirmed = false },
			phase = "offer",
		}
		rooms[from] = room
		rooms[player] = room
		push(room)
		return { ok = true }
	end

	local room = rooms[player]
	if not room then
		return { ok = false, err = "no_room" }
	end
	local me, them = sideOf(room, player)
	if op == "set" then
		local clean = cleanIds(d, payload.ids, P2P_MAX)
		if not clean then
			return { ok = false }
		end
		me.items = clean
		resetConfirms(room)
		push(room)
	elseif op == "ready" then
		me.ready = payload.v == true
		me.confirmed = false
		them.confirmed = false
		room.phase = if room.a.ready and room.b.ready then "confirm" else "offer"
		push(room)
	elseif op == "confirm" then
		if room.phase ~= "confirm" then
			return { ok = false }
		end
		me.confirmed = true
		if them.confirmed then
			local ok, err = execute(room)
			if ok then
				closeRoom(room, "done")
			else
				resetConfirms(room)
				push(room)
				Net.toast(player, err or "No se pudo")
				Net.toast(them.player, err or "No se pudo")
			end
		else
			push(room)
		end
	elseif op == "cancel" then
		closeRoom(room, player.DisplayName .. " canceló el intercambio")
	else
		return { ok = false }
	end
	return { ok = true }
end

function TradeService.init()
	Net.on("npcTrade", npcTrade)
	Net.on("trade", p2p)
	Players.PlayerRemoving:Connect(function(p)
		npcSessions[p] = nil
		requests[p] = nil
		for _, r in requests do
			r[p] = nil
		end
		local room = rooms[p]
		if room then
			closeRoom(room, p.DisplayName .. " se fue")
		end
	end)
end

return TradeService
