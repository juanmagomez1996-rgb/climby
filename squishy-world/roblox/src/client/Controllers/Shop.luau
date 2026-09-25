--!strict
-- Tienda (renderShop de game5.js): ✨ Moldes Virales, Rellenos, Mejoras + ⭐ Robux (pases y productos).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local M = Config.Monetization
local Shop = {}
local tab = "fillings"
local ui: { [string]: any } = {}
local realPrice: { [string]: number } = {}

local TABS = {
	{ "molds", "✨ Moldes Virales" },
	{ "fillings", "Rellenos" },
	{ "upgrades", "Mejoras" },
	{ "robux", "⭐ Robux" },
}

local function item(
	parent: Instance,
	order: number,
	title: string,
	desc: string,
	buttonText: string,
	color: Color3,
	enabled: boolean,
	onBuy: () -> ()
): Frame
	local f: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.white,
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(16), Kit.stroke(Theme.lav2, 2), Kit.pad(12, 10) })
	Kit.text(
		title,
		16,
		{ Font = Theme.display, Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -62, 0, 22), Parent = f }
	)
	Kit.text(desc, 12, {
		TextColor3 = Theme.muted,
		Position = UDim2.fromOffset(62, 24),
		Size = UDim2.new(1, -62, 1, -70),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = f,
	})
	local b = Kit.button(buttonText, color, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 15,
		Parent = f,
	})
	Kit.setEnabled(b, enabled)
	b.Activated:Connect(function()
		if enabled then
			onBuy()
		end
	end)
	return f
end

local function icon(f: Frame, text: string?, bg: Color3?)
	local holder: Frame = Kit.new("Frame", {
		BackgroundColor3 = bg or Theme.lav,
		BackgroundTransparency = if bg then 0 else 1,
		Size = UDim2.fromOffset(54, 54),
		Parent = f,
	}, { Kit.corner(14) })
	if text then
		Kit.text(
			text,
			30,
			{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = holder }
		)
	end
	return holder
end

local function buy(kind: string, id: string)
	local res = State.request("shop", { kind = kind, id = id })
	if not res.ok then
		Audio.play("error")
		if res.err == "monedas" then
			Toast.show("No te alcanzan las monedas")
		end
	end
end

local function buyRobux(entry: any, isPass: boolean)
	if entry.id == 0 then
		if RunService:IsStudio() then
			State.request("devBuy", { key = entry.key })
		else
			Toast.show("¡Muy pronto!")
		end
		return
	end
	local lp = Players.LocalPlayer
	if isPass then
		MarketplaceService:PromptGamePassPurchase(lp, entry.id)
	else
		MarketplaceService:PromptProductPurchase(lp, entry.id)
	end
end

local function priceOf(entry: any, isPass: boolean): number
	if entry.id == 0 then
		return entry.robux
	end
	local k = (if isPass then "p" else "d") .. entry.id
	if realPrice[k] then
		return realPrice[k]
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(
				entry.id,
				if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		if ok and info and info.PriceInRobux then
			realPrice[k] = info.PriceInRobux
		end
	end)
	return entry.robux
end

local function render()
	local d = State.data
	if not d or Modal.current ~= "shop" or not ui.grid then
		return
	end
	for id, b in ui.tabs do
		b.BackgroundColor3 = if tab == id then (if id == "robux" then Theme.robux else Theme.pink) else Theme.white
		b.TextColor3 = if tab == id then Theme.white else Theme.ink
	end
	Kit.clear(ui.grid)
	if tab == "molds" then
		for i, sp in Config.Species do
			if sp.famous then
				local own = table.find(d.molds, sp.id) ~= nil
				local firm = if sp.soft >= 1.2 then "súper suave" elseif sp.soft >= 1 then "suave" else "firme"
				local f = item(
					ui.grid,
					i,
					sp.name,
					string.format("%s\n<b>Slow rise %ss · %s</b>", sp.desc, tostring(sp.rise), firm),
					if own then "Tuyo" else "🪙 " .. Format.int(sp.price),
					if own then Theme.white else Theme.pink,
					not own and d.coins >= sp.price,
					function()
						buy("mold", sp.id)
					end
				)
				Thumb.make({ species = sp.id, variant = "original" }, icon(f))
			end
		end
	elseif tab == "fillings" then
		for i, fl in Config.Fillings do
			if fl.price > 0 then
				local own = table.find(d.fillings, fl.id) ~= nil
				local f = item(
					ui.grid,
					i,
					fl.name,
					fl.desc or "",
					if own then "Tuyo" else "🪙 " .. Format.int(fl.price),
					if own then Theme.white else Theme.pink,
					not own and d.coins >= fl.price,
					function()
						buy("filling", fl.id)
					end
				)
				local col = Color3.fromHex(fl.color3 or (string.sub(fl.color, 1, 1) == "#" and fl.color) or "#ffd36e")
				icon(f, nil, col)
			end
		end
	elseif tab == "upgrades" then
		local order = { "fillSpeed", "luck", "storage" }
		for i, k in order do
			local u = (Config.Upgrades :: any)[k]
			local lvl = if k == "fillSpeed" then d.upgrades.fillSpeed - 1 else d.upgrades[k]
			local maxed = lvl >= #u.costs
			local cost = u.costs[lvl + 1]
			local cur
			if k == "storage" then
				cur = string.format("Guarda %d", u.caps[lvl + 1])
					.. (if maxed then "" else string.format(" → %d", u.caps[lvl + 2]))
			elseif k == "luck" then
				cur = string.format("+%d%% suerte", lvl * 6)
					.. (if maxed then "" else string.format(" → +%d%%", (lvl + 1) * 6))
			else
				cur = string.format("Velocidad %d", lvl + 1)
					.. (if maxed then "" else string.format(" → %d", lvl + 2))
			end
			local dots = string.rep("●", lvl) .. string.rep("○", #u.costs - lvl)
			local f = item(
				ui.grid,
				i,
				u.name,
				string.format("%s\n<b>%s</b>\n%s", u.desc, cur, dots),
				if maxed then "Nivel máximo" else "🪙 " .. Format.int(cost),
				if maxed then Theme.white else Theme.mint,
				not maxed and d.coins >= cost,
				function()
					buy("upgrade", k)
				end
			)
			icon(f, ({ fillSpeed = "⚡", luck = "🍀", storage = "🎒" })[k])
		end
	else
		Kit.text(
			"Pases (para siempre)",
			16,
			{ Font = Theme.display, LayoutOrder = 0, Size = UDim2.fromOffset(300, 24), Parent = ui.grid }
		)
		for i, p in M.PASSES do
			local own = d.passes and d.passes[p.key]
			local f = item(
				ui.grid,
				i,
				p.name,
				p.desc,
				if own then "¡Ya lo tienes!" else string.format("R$ %d", priceOf(p, true)),
				if own then Theme.white else Theme.robux,
				not own and (p.id ~= 0 or RunService:IsStudio()),
				function()
					buyRobux(p, true)
				end
			)
			icon(f, p.icon)
		end
		for i, p in M.PRODUCTS do
			local f = item(
				ui.grid,
				100 + i,
				p.name,
				p.desc,
				string.format("R$ %d", priceOf(p, false)),
				Theme.robux,
				p.id ~= 0 or RunService:IsStudio(),
				function()
					buyRobux(p, false)
				end
			)
			icon(f, p.icon)
		end
	end
end

local function open(startTab: any?)
	if type(startTab) == "string" then
		tab = startTab
	end
	local content = Modal.open("shop", "Tienda", {
		width = 860,
		height = 560,
		onClose = function()
			ui = {}
		end,
	})
	local tabs: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	ui.tabs = {}
	for i, t in TABS do
		local b = Kit.button(t[2], Theme.white, {
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 14,
			LayoutOrder = i,
			Parent = tabs,
		})
		Kit.pad(12, 0).Parent = b
		ui.tabs[t[1]] = b
		b.Activated:Connect(function()
			tab = t[1]
			Audio.play("click")
			render()
		end)
	end
	local grid = Modal.scroll(content, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
	Kit.grid(UDim2.fromOffset(260, 150), 10).Parent = grid
	Kit.pad(2, 4).Parent = grid
	ui.grid = grid
	Audio.play("open")
	render()
	-- precios reales del Marketplace llegan async
	task.delay(1.5, render)
end

function Shop.init()
	Router.register("shop", open)
	Router.register("robux", function()
		open("robux")
	end)
	State.onChange(function()
		render()
	end)
end

return Shop
