--!strict
-- Tienda con monedas: moldes virales, rellenos y mejoras (renderShop / shopGrid de game5.js).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Logic.Catalog)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Net = require(script.Parent.Net)

local ShopService = {}

function ShopService.init()
	Net.on("shop", function(player, payload)
		local d = DataService.get(player)
		if not d then
			return { ok = false }
		end
		local kind, id = payload.kind, payload.id
		if kind == "filling" then
			local f = Catalog.FIL[id]
			if not f or f.price <= 0 or table.find(d.fillings, f.id) then
				return { ok = false }
			end
			if not Economy.spend(player, f.price) then
				return { ok = false, err = "monedas" }
			end
			table.insert(d.fillings, f.id)
			Net.sound(player, "coins")
			Net.toast(player, string.format("¡Relleno %s desbloqueado!", f.name), true)
		elseif kind == "mold" then
			local sp = Catalog.SP[id]
			if not sp or not sp.famous or table.find(d.molds, sp.id) then
				return { ok = false }
			end
			if not Economy.spend(player, sp.price) then
				return { ok = false, err = "monedas" }
			end
			table.insert(d.molds, sp.id)
			Net.sound(player, "coins")
			Net.sound(player, "sparkle")
			Net.toast(
				player,
				string.format("¡Molde viral %s desbloqueado! Úsalo en cualquier máquina.", sp.name),
				true,
				3200
			)
		elseif kind == "upgrade" then
			local u = (Config.Upgrades :: any)[id]
			if not u then
				return { ok = false }
			end
			local lvl = if id == "fillSpeed" then d.upgrades.fillSpeed - 1 else (d.upgrades :: any)[id]
			local cost = u.costs[lvl + 1]
			if not cost then
				return { ok = false, err = "max" }
			end
			if not Economy.spend(player, cost) then
				return { ok = false, err = "monedas" }
			end
			if id == "fillSpeed" then
				d.upgrades.fillSpeed += 1
				Economy.questEvent(player, "upFill", 1)
			else
				(d.upgrades :: any)[id] += 1
			end
			Net.sound(player, "levelup")
			Net.toast(player, string.format("¡%s mejorada!", u.name), true)
		else
			return { ok = false, err = "kind" }
		end
		DataService.changed(player)
		return { ok = true }
	end)
end

return ShopService
