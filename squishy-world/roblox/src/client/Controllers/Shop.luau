--!strict
-- Tienda (renderShop de game5.js + #shopWrap): ✨ Moldes Virales, Rellenos (por defecto), Mejoras.
-- + ⭐ Robux (extra de monetización: pases y productos).
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

type ItemOpts = {
	order: number,
	title: string,
	desc: string,
	icon: ((Frame) -> ())?,
	price: string?, -- número con moneda
	label: string?, -- texto sin moneda ("Tuyo", "Nivel máximo", "R$ 99")
	color: Color3,
	enabled: boolean,
	levels: { number }?, -- { hechos, total } para .lv
	onBuy: () -> (),
}

-- .item: blanca, radius 18, padding 14, sombra 0 4px 0 lav2; .t Nunito 900 16; .d 12.5 700 #6d7285
local function item(o: ItemOpts): Frame
	local f: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.white,
		LayoutOrder = o.order,
		Parent = ui.grid,
	}, { Kit.corner(18), Kit.pad(14, 14) })
	Kit.shadow(f, Theme.lav2, 4, 18)
	local head: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = f,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) });
	(head:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
	if o.icon then
		local holder: Frame = Kit.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), LayoutOrder = 1, Parent = head }
		)
		o.icon(holder)
	end
	Kit.text(o.title, 16, {
		FontFace = Theme.bodyBlack,
		Size = UDim2.new(1, if o.icon then -54 else 0, 1, 0),
		LayoutOrder = 2,
		Parent = head,
	})
	Kit.text(o.desc, 12.5, {
		FontFace = Theme.bodyBold,
		TextColor3 = Theme.muted,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -100),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = f,
	})
	if o.levels then
		local lv: Frame = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -44),
			Size = UDim2.new(1, 0, 0, 7),
			Parent = f,
		}, { Kit.list(Enum.FillDirection.Horizontal, 3) })
		local total = o.levels[2]
		for i = 1, total do
			Kit.new("Frame", {
				BackgroundColor3 = if i <= o.levels[1] then Theme.mint else Theme.lav,
				Size = UDim2.new(1 / total, -3, 1, 0),
				LayoutOrder = i,
				Parent = lv,
			}, { Kit.corner(4) })
		end
	end
	local props = {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = f,
	}
	local b = if o.price then Kit.priceButton(o.price, o.color, props) else Kit.button(o.label or "", o.color, props)
	Kit.setEnabled(b, o.enabled)
	b.Activated:Connect(function()
		if o.enabled then
			o.onBuy()
		end
	end)
	return f
end

local function buy(kind: string, id: string)
	local res = State.request("shop", { kind = kind, id = id })
	if not res.ok then
		Audio.play("error")
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

local function emojiIcon(e: string): (Frame) -> ()
	return function(h: Frame)
		Kit.text(e, 30, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = h })
	end
end

local function render()
	local d = State.data
	if not d or Modal.current ~= "shop" or not ui.grid then
		return
	end
	Kit.clear(ui.tabs)
	for i, t in TABS do
		local b = Kit.tab(t[2], tab == t[1], false, { LayoutOrder = i, Parent = ui.tabs })
		b.Activated:Connect(function()
			tab = t[1]
			Audio.play("click")
			render()
		end)
	end
	Kit.clear(ui.grid)
	if tab == "molds" then
		for i, sp in Config.Species do
			if sp.famous then
				local own = table.find(d.molds, sp.id) ~= nil
				local firm = if sp.soft >= 1.2 then "súper suave" elseif sp.soft >= 1 then "suave" else "firme"
				item({
					order = i,
					title = sp.name,
					desc = string.format(
						'%s\n<font color="#282D3A"><b>Slow rise %ss · %s</b></font>',
						sp.desc,
						tostring(sp.rise),
						firm
					),
					icon = function(h)
						Thumb.make({ species = sp.id, variant = "original" }, h)
					end,
					price = if own then nil else Format.int(sp.price),
					label = if own then "Tuyo" else nil,
					color = if own then Theme.lav else Theme.pink,
					enabled = not own and d.coins >= sp.price,
					onBuy = function()
						buy("mold", sp.id)
					end,
				})
			end
		end
	elseif tab == "fillings" then
		for i, fl in Config.Fillings do
			if fl.price > 0 then
				local own = table.find(d.fillings, fl.id) ~= nil
				local col = Color3.fromHex(fl.color3 or (string.sub(fl.color, 1, 1) == "#" and fl.color) or "#ffd36e")
				item({
					order = i,
					title = fl.name,
					desc = fl.desc or "",
					icon = function(h)
						Kit.new("Frame", {
							BackgroundColor3 = col,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(26, 26),
							Parent = h,
						}, { Kit.round(), Kit.stroke(Color3.fromRGB(215, 212, 222), 1) })
					end,
					price = if own then nil else Format.int(fl.price),
					label = if own then "Tuyo" else nil,
					color = if own then Theme.lav else Theme.pink,
					enabled = not own and d.coins >= fl.price,
					onBuy = function()
						buy("filling", fl.id)
					end,
				})
			end
		end
	elseif tab == "upgrades" then
		for i, k in { "fillSpeed", "luck", "storage" } do
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
			item({
				order = i,
				title = u.name,
				desc = string.format('%s\n<font color="#282D3A"><b>%s</b></font>', u.desc, cur),
				levels = { lvl, #u.costs },
				price = if maxed then nil else Format.int(cost),
				label = if maxed then "Nivel máximo" else nil,
				color = if maxed then Theme.lav else Theme.mint,
				enabled = not maxed and d.coins >= cost,
				onBuy = function()
					buy("upgrade", k)
				end,
			})
		end
	else
		for i, p in M.PASSES do
			local own = d.passes and d.passes[p.key]
			item({
				order = i,
				title = p.name,
				desc = p.desc .. '\n<font color="#282D3A"><b>Pase: para siempre</b></font>',
				icon = emojiIcon(p.icon),
				label = if own then "¡Ya lo tienes!" else string.format("R$ %d", priceOf(p, true)),
				color = if own then Theme.lav else Theme.robux,
				enabled = not own and (p.id ~= 0 or RunService:IsStudio()),
				onBuy = function()
					buyRobux(p, true)
				end,
			})
		end
		for i, p in M.PRODUCTS do
			item({
				order = 100 + i,
				title = p.name,
				desc = p.desc,
				icon = emojiIcon(p.icon),
				label = string.format("R$ %d", priceOf(p, false)),
				color = Theme.robux,
				enabled = p.id ~= 0 or RunService:IsStudio(),
				onBuy = function()
					buyRobux(p, false)
				end,
			})
		end
	end
end

local function open(startTab: any?)
	if type(startTab) == "string" then
		tab = startTab
	end
	local content = Modal.open("shop", "Tienda", {
		width = 760,
		height = 600,
		onClose = function()
			ui = {}
		end,
	})
	ui.tabs = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local scroll = Modal.scroll(content, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) })
	local inner: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = scroll,
	}, { Kit.new("UIPadding", { PaddingBottom = UDim.new(0, 10) }) })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0, 196),
		CellPadding = UDim2.fromOffset(12, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inner,
	})
	ui.grid = inner
	Audio.play("open")
	render()
	task.delay(1.5, render) -- precios reales del Marketplace llegan async
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
