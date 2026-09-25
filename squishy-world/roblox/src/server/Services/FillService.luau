--!strict
-- Máquina de llenado, AUTORITATIVA (SYSTEMS_SPEC §3–4). El cliente solo dice "empecé a mantener"
-- y "solté"; el servidor mide el tiempo con os.clock(), calcula p, decide under/perfect/over/POP y
-- tira la rareza. El cliente anima el medidor con la misma fórmula y muestra lo que diga el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Logic.Catalog)
local Format = require(Shared.Util.Format)
local Profile = require(Shared.Logic.Profile)
local Squishy = require(Shared.Logic.Squishy)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local InventoryService = require(script.Parent.InventoryService)
local MonetizationService = require(script.Parent.MonetizationService)
local Net = require(script.Parent.Net)

local FILL = Config.Game.FILL
local MACHINE_RANGE = 28 -- studs desde la máquina (margen sobre INTERACT_DIST por lag)
-- Tolerancia por lag: se acepta el tiempo del cliente solo si está MUY cerca del medido aquí.
-- Debe ser bastante menor que la ventana PERFECTO (~0.12 s a velocidad 6) para que no se pueda
-- "elegir" el resultado con un cliente modificado.
local LATENCY_TOL = 0.04

type Session = {
	machine: any,
	species: string,
	filling: string,
	held: number,
	since: number?,
}

local FillService = {}
local sessions: { [Player]: Session } = {}
local rng = Random.new()

local machineById: { [string]: any } = {}
for _, m in Config.Machines do
	machineById[m.id] = m
end
local machinePos: { [string]: Vector3 } = {}
for _, m in Config.WorldLayout.machines do
	machinePos[m.id] = m.pos
end

local function nearMachine(player: Player, id: string): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = machinePos[id]
	if not root or not pos then
		return false
	end
	local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
	return flat.Magnitude <= MACHINE_RANGE
end

--- Suerte total, incluyendo pases/pociones de Robux.
function FillService.luck(
	player: Player,
	d: Types.PlayerData,
	machine: any,
	fillingId: string,
	res: Types.FillResult?
): number
	local L = Squishy.totalLuck(d.upgrades.luck, machine, fillingId, res)
	local E = Config.Monetization.EFFECTS
	if MonetizationService.hasPass(player, "luckPlus") then
		L += E.luckPlus
	end
	if d.luckUntil > os.time() then
		L += E.luckPotion
	end
	return L
end

local function start(player: Player, payload: { [string]: any }): { [string]: any }
	local d = DataService.get(player)
	if not d then
		return { ok = false }
	end
	if d.pending then
		return { ok = false, err = "pending", squishy = d.pending }
	end
	local s = sessions[player]
	if s then
		-- volver a mantener después de soltar muy pronto ("Sigue manteniendo…")
		if not s.since then
			s.since = os.clock()
		end
		return { ok = true, held = s.held }
	end
	local machine = machineById[payload.machine]
	local sp = Catalog.SP[payload.species]
	local fil = Catalog.FIL[payload.filling]
	if not machine or not sp or not fil then
		return { ok = false, err = "datos" }
	end
	if d.level < machine.level then
		return { ok = false, err = string.format("Esta máquina se abre en el nivel %d", machine.level) }
	end
	if not nearMachine(player, machine.id) then
		return { ok = false, err = "Acércate a la máquina" }
	end
	if not Profile.moldAvailable(d, sp.id) then
		return { ok = false, err = "molde" }
	end
	if not table.find(d.fillings, fil.id) then
		return { ok = false, err = "relleno" }
	end
	if InventoryService.isFull(player, d) then
		return {
			ok = false,
			err = string.format(
				"Inventario lleno (%d). Vende algunos squishies primero.",
				InventoryService.capacity(player, d)
			),
		}
	end
	if fil.perUse and not MonetizationService.hasPass(player, "vip") then
		if not Economy.spend(player, fil.perUse) then
			return { ok = false, err = string.format("El relleno Misterio cuesta %d monedas por llenado", fil.perUse) }
		end
	end
	d.lastMold = sp.id
	d.lastFill = fil.id
	sessions[player] = { machine = machine, species = sp.id, filling = fil.id, held = 0, since = os.clock() }
	DataService.changed(player)
	return { ok = true, held = 0 }
end

local function release(player: Player, payload: { [string]: any }): { [string]: any }
	local d = DataService.get(player)
	local s = sessions[player]
	if not d or not s or not s.since then
		return { ok = false, err = "no_fill" }
	end
	local serverHeld = s.held + (os.clock() - s.since)
	local held = serverHeld
	local clientHeld = payload.held
	if type(clientHeld) == "number" and clientHeld == clientHeld then
		local tol = LATENCY_TOL + math.min(0.03, player:GetNetworkPing() * 0.25)
		if math.abs(clientHeld - serverHeld) <= tol then
			held = clientHeld
		end
	end
	s.held = held
	s.since = nil
	local speed = d.upgrades.fillSpeed
	local p = Squishy.fillProgress(held, speed)
	local res, popped = Squishy.fillResult(p)

	if popped then
		sessions[player] = nil
		d.stats.fills += 1
		Economy.addXP(player, 1)
		DataService.changed(player)
		return { ok = true, result = "pop", p = p }
	end
	if not res then
		return { ok = true, result = "short", p = p, held = held }
	end

	sessions[player] = nil
	if res == "perfect" then
		d.stats.perfect += 1
		Economy.questEvent(player, "perfect", 1)
	end

	local sq: Types.SquishyData
	if not d.firstDone then
		d.firstDone = true
		sq = Squishy.generate(
			rng,
			s.species,
			s.filling,
			0,
			{ rarity = "uncommon", variant = "bubblegum", mutation = "normal", face = "happy" }
		)
	elseif d.legendFills > 0 then
		d.legendFills -= 1
		sq = Squishy.generate(
			rng,
			s.species,
			s.filling,
			FillService.luck(player, d, s.machine, s.filling, res :: Types.FillResult),
			{ rarity = "legendary", machine = s.machine }
		)
	else
		sq = Squishy.generate(
			rng,
			s.species,
			s.filling,
			FillService.luck(player, d, s.machine, s.filling, res :: Types.FillResult),
			{ machine = s.machine }
		)
	end

	local k = Profile.idxKey(sq)
	local isNew = not d.discovered[k]
	d.discovered[k] = true
	d.pending = sq
	d.stats.fills += 1
	DataService.changed(player)

	-- XP y misiones cuando termina el procesado (así los toasts salen junto con la revelación)
	local tier = Catalog.RTier[sq.rarity]
	task.delay(FILL.process, function()
		if not DataService.get(player) then
			return
		end
		Economy.questEvent(player, "fill", 1)
		if tier >= 1 then
			Economy.questEvent(player, "getUncommon", 1)
		end
		if tier >= 2 then
			Economy.questEvent(player, "getRare", 1)
		end
		if tier >= 3 then
			Economy.questEvent(player, "getEpic", 1)
		end
		if isNew then
			Economy.questEvent(player, "index", Profile.discoveredCount(d), true)
		end
		Economy.addXP(player, Catalog.R[sq.rarity].xp)
	end)
	return { ok = true, result = res, p = p, squishy = sq, isNew = isNew }
end

--- Guardar o vender el squishy que salió de la máquina.
local function decide(player: Player, payload: { [string]: any }): { [string]: any }
	local d = DataService.get(player)
	if not d or not d.pending then
		return { ok = false }
	end
	local sq = d.pending :: Types.SquishyData
	if payload.keep == true then
		if InventoryService.isFull(player, d) then
			return { ok = false, err = "Inventario lleno" }
		end
		d.pending = nil
		InventoryService.add(player, d, sq)
		Net.sound(player, "keep")
		Net.toast(player, string.format("%s guardado en tu inventario", sq.name))
		if d.tutorial <= 3 then
			d.tutorial = 4
		end
	else
		d.pending = nil
		local dupe = false
		for _, x in d.inventory do
			if Profile.idxKey(x) == Profile.idxKey(sq) then
				dupe = true
				break
			end
		end
		local got = Economy.earnCoins(player, sq.value)
		d.stats.sold += 1
		Net.sound(player, "coins")
		Net.toast(player, string.format("Vendido por %s monedas", Format.int(got)))
		if dupe then
			Economy.questEvent(player, "sellDupe", 1)
		end
		if d.tutorial <= 3 then
			Net.toast(player, "Tip: ¡guarda el primero para poder equiparlo!")
			local gift = Squishy.generate(
				rng,
				sq.species,
				sq.filling,
				0,
				{ rarity = "uncommon", variant = "bubblegum", mutation = "normal", face = "happy" }
			)
			InventoryService.add(player, d, gift)
			d.tutorial = 4
		end
	end
	DataService.changed(player)
	return { ok = true }
end

function FillService.init()
	Net.on("fillStart", start)
	Net.on("fillRelease", release)
	Net.on("fillCancel", function(player)
		sessions[player] = nil
		return { ok = true }
	end)
	Net.on("reveal", decide)

	-- Si se va con un squishy pendiente: se guarda si cabe, si no se vende.
	DataService.onReleasing(function(player, d)
		sessions[player] = nil
		local sq = d.pending
		if sq then
			d.pending = nil
			if #d.inventory < InventoryService.capacity(player, d) then
				table.insert(d.inventory, sq)
			else
				d.coins += sq.value
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

return FillService
