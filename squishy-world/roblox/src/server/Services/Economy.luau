--!strict
-- Monedas, XP/niveles y misiones (addCoins / addXP / questEvent de game5.js), en el servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Profile = require(Shared.Logic.Profile)
local Quests = require(Shared.Logic.Quests)
local Squishy = require(Shared.Logic.Squishy)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local Economy = {}

-- La monetización registra aquí el multiplicador de monedas ganadas (ventas y misiones).
local earnMultiplier: (Player) -> number = function()
	return 1
end
function Economy.setEarnMultiplier(fn: (Player) -> number)
	earnMultiplier = fn
end

local function leaderstats(player: Player)
	local d = DataService.get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls then
		return
	end
	local c = ls:FindFirstChild("Monedas") :: IntValue?
	local l = ls:FindFirstChild("Nivel") :: IntValue?
	if c then
		c.Value = d.coins
	end
	if l then
		l.Value = d.level
	end
end

--- Suma (o resta) monedas tal cual, sin multiplicadores.
function Economy.addCoins(player: Player, n: number)
	local d = DataService.get(player)
	if not d then
		return
	end
	d.coins = math.max(0, math.floor(d.coins + n))
	DataService.changed(player)
	leaderstats(player)
end

--- Monedas ganadas jugando (vender, misiones): aplica Monedas x2 / VIP. Devuelve lo que se sumó.
function Economy.earnCoins(player: Player, n: number): number
	local total = math.floor(n * earnMultiplier(player) + 0.5)
	Economy.addCoins(player, total)
	return total
end

--- Cobra si alcanza. true = cobrado.
function Economy.spend(player: Player, n: number): boolean
	local d = DataService.get(player)
	if not d or d.coins < n then
		return false
	end
	Economy.addCoins(player, -n)
	return true
end

function Economy.questEvent(player: Player, ev: string, amount: number, absolute: boolean?)
	local d = DataService.get(player)
	if not d then
		return
	end
	local q = Quests.current(d.quest.i)
	if q.ev ~= ev then
		return
	end
	d.quest.p = if absolute then math.max(d.quest.p, amount) else d.quest.p + amount
	if d.quest.p >= q.goal then
		local got = Economy.earnCoins(player, q.reward)
		d.quest.i += 1
		d.quest.p = 0
		task.delay(0.4, function()
			Net.toast(
				player,
				string.format("Misión completa: %s · +%s monedas", q.title, Format.int(got)),
				true,
				3200
			)
			Net.sound(player, "reward")
		end)
		-- misiones de nivel/índice que ya estaban cumplidas se completan solas
		local nq = Quests.current(d.quest.i)
		if nq.ev == "level" then
			d.quest.p = d.level
		elseif nq.ev == "index" then
			d.quest.p = Profile.discoveredCount(d)
		end
		if d.quest.p >= nq.goal then
			local g = nq.goal
			task.delay(0.6, function()
				Economy.questEvent(player, nq.ev, g, true)
			end)
		end
	end
	DataService.changed(player)
end

function Economy.addXP(player: Player, n: number)
	local d = DataService.get(player)
	if not d then
		return
	end
	d.xp += n
	while d.xp >= Squishy.xpNeed(d.level) do
		d.xp -= Squishy.xpNeed(d.level)
		d.level += 1
		local lvl = d.level
		Net.sound(player, "levelup")
		Net.toast(player, string.format("¡Subiste de nivel! Ahora eres nivel %d", lvl), true, 3200)
		for _, sp in Config.Species do
			if not sp.famous and sp.unlockLevel == lvl then
				task.delay(0.9, function()
					Net.toast(player, string.format("¡Nuevo molde desbloqueado: %s!", sp.name), true, 3200)
				end)
			end
		end
		for _, m in Config.Machines do
			if m.level == lvl then
				task.delay(1.6, function()
					Net.toast(player, string.format("¡%s (%s) ya está abierta!", m.name, m.sub), true, 3200)
				end)
			end
		end
		Economy.questEvent(player, "level", lvl, true)
	end
	DataService.changed(player)
	leaderstats(player)
end

function Economy.init()
	DataService.onLoaded(function(player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("IntValue")
		c.Name = "Monedas"
		c.Parent = ls
		local l = Instance.new("IntValue")
		l.Name = "Nivel"
		l.Parent = ls
		ls.Parent = player
		leaderstats(player)
	end)
end

return Economy
