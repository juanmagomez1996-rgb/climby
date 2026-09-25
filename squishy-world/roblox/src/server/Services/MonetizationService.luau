--!strict
-- Robux: Game Passes (permanentes) y Developer Products (consumibles).
-- • ProcessReceipt es idempotente: guarda el PurchaseId en el perfil y confirma el recibo
--   (PurchaseGranted) SOLO después de guardar en el DataStore. Si algo falla → NotProcessedYet
--   y Roblox lo reintenta.
-- • Los pases se consultan al entrar y se actualizan al comprarlos en el juego.
-- • En Studio, los ítems con id 0 se simulan con la acción "devBuy" para poder probar todo.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MonetizationConfig = require(Shared.Config.Monetization)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Net = require(script.Parent.Net)

local M = Config.Monetization

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}

function MonetizationService.hasPass(player: Player, passKey: string): boolean
	local o = owned[player]
	return o ~= nil and o[passKey] == true
end

local function setPass(player: Player, passKey: string)
	local o = owned[player]
	if not o then
		o = {}
		owned[player] = o
	end
	if o[passKey] then
		return
	end
	o[passKey] = true
	if passKey == "vip" then
		player:SetAttribute("VIP", true)
	end
	DataService.changed(player)
end

local function refreshPasses(player: Player)
	owned[player] = owned[player] or {}
	for _, pass in M.PASSES do
		if pass.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and has then
				setPass(player, pass.key)
			end
		end
	end
end

--- Aplica el efecto de un producto al perfil. Devuelve el texto del toast.
local function applyProduct(player: Player, d: Types.PlayerData, product: MonetizationConfig.Product): string
	if product.coins then
		Economy.addCoins(player, product.coins)
	end
	if product.luckMinutes then
		local now = os.time()
		d.luckUntil = math.max(d.luckUntil, now) + product.luckMinutes * 60
	end
	if product.legendFills then
		d.legendFills += product.legendFills
	end
	return string.format("¡Gracias por tu compra! %s %s", product.icon, product.name)
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = M.productById[info.ProductId]
	if not product then
		warn("[Monetization] producto desconocido", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataService.waitFor(player, 20)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if table.find(d.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- ya se había entregado
	end
	local msg = applyProduct(player, d, product)
	table.insert(d.receipts, purchaseId)
	d.robuxSpent += tonumber(info.CurrencySpent) or 0
	DataService.changed(player)
	if not DataService.saveNow(player) then
		-- deshacer no es seguro con monedas ya gastadas; Roblox reintentará y el recibo evita duplicar
		warn("[Monetization] no se pudo guardar tras la compra; se reintentará", purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Net.toast(player, msg, true, 3500)
	Net.sound(player, "reward")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	Economy.setEarnMultiplier(function(player)
		local mult = 1
		if MonetizationService.hasPass(player, "coins2x") then
			mult *= M.EFFECTS.coins2xMult
		end
		if MonetizationService.hasPass(player, "vip") then
			mult *= M.EFFECTS.vipCoinMult
		end
		return mult
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = M.passById[passId]
		if purchased and pass then
			setPass(player, pass.key)
			Net.toast(player, string.format("¡%s %s activado! Gracias 💖", pass.icon, pass.name), true, 3500)
			Net.sound(player, "reward")
		end
	end)

	DataService.onLoaded(function(player)
		refreshPasses(player)
		DataService.changed(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	DataService.addViewProvider(function(player, view)
		view.passes = table.clone(owned[player] or {})
		local d = DataService.get(player)
		view.luckLeft = if d then math.max(0, d.luckUntil - os.time()) else 0
	end)

	-- Solo Studio: simular la compra de ítems que todavía no tienen id (para probar el flujo).
	Net.on("devBuy", function(player, payload)
		if not RunService:IsStudio() then
			return { ok = false, err = "solo_studio" }
		end
		local item = M.byKey[payload.key]
		if not item then
			return { ok = false, err = "no_existe" }
		end
		local d = DataService.get(player)
		if not d then
			return { ok = false }
		end
		for _, pass in M.PASSES do
			if pass.key == payload.key then
				setPass(player, pass.key)
				Net.toast(player, string.format("[Studio] %s %s activado (simulado)", pass.icon, pass.name), true)
				return { ok = true }
			end
		end
		local msg = applyProduct(player, d, item :: MonetizationConfig.Product)
		DataService.changed(player)
		Net.toast(player, "[Studio] " .. msg .. " (simulado)", true)
		return { ok = true }
	end)
end

return MonetizationService
