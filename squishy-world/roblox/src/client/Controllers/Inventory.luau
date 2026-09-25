--!strict
-- Inventario (renderInventory / renderInvDetail de game5.js + #invWrap de template.html):
-- 4 columnas + detalle de 290, filtros por rareza y ⭐ Favoritos, equipar, favorito, vender,
-- "Vender repetidos" y 🖐️ Apachurrar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Profile = require(Shared.Logic.Profile)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Inventory = {}
local Inv = { filter = "all", sel = nil :: string? }
local ui: { [string]: any } = {}

local MONTHS = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic" }
--- toLocaleDateString('es-CO', { day: 'numeric', month: 'short', year: 'numeric' }) → "25 sept 2026"
local function fmtDate(t: number): string
	local d = os.date("*t", t) :: any
	return string.format("%d %s %d", d.day, MONTHS[d.month], d.year)
end

--- Chip de rareza (.rr): ancho automático, 11px, radius 7, texto blanco.
function Inventory.rarityChip(parent: Instance, rarity: string, props: { [string]: any }?): TextLabel
	local r = Catalog.R[rarity]
	local p: { [string]: any } = {
		BackgroundColor3 = Color3.fromHex(r.color),
		TextColor3 = Theme.white,
		FontFace = Theme.bodyBlack,
		TextSize = 11,
		Text = r.name,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("TextLabel", p, { Kit.corner(7), Kit.pad(8, 0) })
end

--- Carta .card (se reutiliza en intercambios): blanca, radius 18, sombra lav2, elegida = borde ink.
function Inventory.card(parent: Instance, s: any, d: any?, selected: boolean?, compact: boolean?): TextButton
	local b = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Theme.white,
		Size = if compact then UDim2.fromOffset(78, 100) else UDim2.fromOffset(120, 170),
		Parent = parent,
	}, {
		Kit.corner(if compact then 14 else 18),
		Kit.new("UIStroke", {
			Color = if compact then Theme.mintD else Theme.ink,
			Thickness = 3,
			Transparency = if selected then 0 else 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	Kit.shadow(b, Theme.lav2, 4, 18)
	local th: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -16, 1, if compact then -34 else -52),
		Parent = b,
	}, { Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Thumb.make(s, th)
	Kit.text(s.name, if compact then 10.5 else 12.5, {
		FontFace = Theme.bodyBlack,
		Position = UDim2.new(0, 4, 1, if compact then -28 else -46),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 0.95,
		Parent = b,
	})
	if not compact then
		Inventory.rarityChip(b, s.rarity, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })
	end
	if s.fav then
		Kit.star(true, 15, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Parent = b })
	end
	if d and d.equipped == s.id then
		Kit.new("TextLabel", {
			BackgroundColor3 = Theme.ink,
			TextColor3 = Theme.white,
			FontFace = Theme.bodyBlack,
			TextSize = 10,
			Text = "Equipado",
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(0, 16),
			Parent = b,
		}, { Kit.corner(7), Kit.pad(6, 0) })
	end
	return b
end

local render: () -> ()

local function kv(parent: Instance, order: number, k: string, v: string)
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.text(k, 14, { TextColor3 = Theme.ink2, Size = UDim2.fromScale(0.5, 1), Parent = row })
	Kit.text(v, 14, {
		FontFace = Theme.bodyBlack,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.6, 1),
		Parent = row,
	})
end

local function detail(d: any)
	Kit.clear(ui.detail)
	local s = Inv.sel and Profile.find(d, Inv.sel)
	if not s then
		Kit.text("Elige un squishy para verlo aquí.", 14, {
			TextColor3 = Theme.grey,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = ui.detail,
		})
		return
	end
	local th: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(190, 190),
		LayoutOrder = 1,
		Parent = ui.detail,
	})
	Thumb.make(s, th)
	Kit.text(s.name, 24, {
		FontFace = Theme.display,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = ui.detail,
	})
	Inventory.rarityChip(ui.detail, s.rarity, { LayoutOrder = 3, TextSize = 12, Size = UDim2.fromOffset(0, 20) })
	local copies = 0
	for _, x in d.inventory do
		if Profile.idxKey(x) == Profile.idxKey(s) then
			copies += 1
		end
	end
	local mut = Catalog.MUT[s.mutation]
	kv(ui.detail, 11, "Encontrado", fmtDate(s.dateFound))
	kv(ui.detail, 12, "Valor", Format.int(s.value) .. " monedas")
	kv(ui.detail, 13, "Relleno", if Catalog.FIL[s.filling] then Catalog.FIL[s.filling].name else "—")
	kv(ui.detail, 14, "Tamaño", string.format("%.2f×", s.size * ((mut and mut.size) or 1)))
	kv(ui.detail, 15, "Copias", tostring(copies))
	local sq = Kit.button("🖐️ Apachurrar", Theme.purple, { LayoutOrder = 29, Parent = ui.detail })
	sq.Activated:Connect(function()
		Modal.close()
		Router.open("studio", { squishy = s, owner = "Tuyo" })
	end)
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 30,
		Parent = ui.detail,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	local eq = Kit.button(
		if d.equipped == s.id then "Quitar" else "Equipar",
		Theme.mint,
		{ Size = UDim2.new(0.5, -4, 0, 40), Parent = row }
	)
	local fav = Kit.button(
		if s.fav then "⭐ Quitar fav" else "Favorito",
		Theme.white,
		{ Size = UDim2.new(0.5, -4, 0, 40), TextSize = 14, Parent = row }
	)
	local sell =
		Kit.button("Vender por " .. Format.int(s.value), Theme.yellow, { LayoutOrder = 31, Parent = ui.detail })
	if s.fav or d.equipped == s.id then
		Kit.setEnabled(sell, false)
	end
	eq.Activated:Connect(function()
		Audio.play("select")
		State.request("inv", { op = "equip", id = s.id })
	end)
	fav.Activated:Connect(function()
		Audio.play("toggle")
		State.request("inv", { op = "fav", id = s.id })
	end)
	sell.Activated:Connect(function()
		if s.fav or d.equipped == s.id then
			return
		end
		State.request("inv", { op = "sell", id = s.id })
	end)
end

render = function()
	local d = State.data
	if not d or Modal.current ~= "inventory" or not ui.grid then
		return
	end
	ui.count.Text = string.format("%d/%d", #d.inventory, d.capacity or 20)
	Kit.clear(ui.tabs)
	for i, id in ui.tabIds do
		local label = if id == "all" then "Todos" elseif id == "favorites" then "⭐ Favoritos" else Catalog.R[id].name
		local b = Kit.tab(label, Inv.filter == id, false, { LayoutOrder = i, Parent = ui.tabs })
		b.Activated:Connect(function()
			Inv.filter = id
			Audio.play("click")
			render()
		end)
	end
	local list = table.clone(d.inventory)
	table.sort(list, function(a: any, b: any)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.dateFound > b.dateFound
	end)
	local filtered = {}
	for _, s in list do
		if Inv.filter == "all" or (Inv.filter == "favorites" and s.fav) or s.rarity == Inv.filter then
			table.insert(filtered, s)
		end
	end
	Kit.clear(ui.grid)
	if #filtered == 0 then
		Kit.text(
			if #d.inventory > 0
				then "Nada con este filtro."
				else "Aún no tienes squishies. ¡Ve a las Máquinas y llena el primero!",
			14,
			{
				FontFace = Theme.body,
				TextColor3 = Theme.grey,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 80),
				Parent = ui.grid.Parent,
				Name = "_Empty",
			}
		)
	else
		local e = ui.grid.Parent:FindFirstChild("_Empty")
		if e then
			e:Destroy()
		end
	end
	if not Inv.sel or not Profile.find(d, Inv.sel) then
		Inv.sel = if filtered[1] then filtered[1].id else nil
	end
	for i, s in filtered do
		local b = Inventory.card(ui.grid, s, d, Inv.sel == s.id)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			Inv.sel = s.id
			Audio.play("click")
			render()
		end)
	end
	detail(d)
end

local function open()
	local content, title = Modal.open("inventory", "Inventario", {
		width = 980,
		height = 660,
		onClose = function()
			ui = {}
		end,
	})
	-- "Inventario " + #invCount en 18px con opacidad .55
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, 34)
	ui.count = Kit.text("", 18, {
		FontFace = Theme.display,
		TextTransparency = 0.45,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		Parent = title.Parent,
	})
	title:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		ui.count.Position = UDim2.fromOffset(22 + title.AbsoluteSize.X + 8, 20)
	end)
	ui.count.Position = UDim2.fromOffset(150, 20)
	local dupes = Kit.button("Vender repetidos", Theme.yellow, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, -44),
		Size = UDim2.fromOffset(150, 30),
		Parent = content,
	}, "small")
	dupes.Activated:Connect(function()
		local prev = State.request("inv", { op = "sellDupes", preview = true })
		if not prev.ok then
			return
		end
		Router.open("confirm", {
			text = string.format(
				"¿Vender %d repetido%s por %s monedas? Te quedas con la mejor copia de cada uno.",
				prev.count,
				if prev.count > 1 then "s" else "",
				Format.int(prev.total)
			),
			yes = function()
				State.request("inv", { op = "sellDupes" })
			end,
		})
	end)
	ui.tabs = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	ui.tabIds = { "all" }
	for _, r in Config.Rarities do
		table.insert(ui.tabIds, r.id)
	end
	table.insert(ui.tabIds, "favorites")
	local gridHolder = Modal.scroll(content, {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, -304, 1, -42),
	})
	local inner: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = gridHolder,
	})
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 176),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inner,
	})
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = inner })
	ui.grid = inner
	local det: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 42),
		Size = UDim2.new(0, 290, 1, -42),
		Parent = content,
	}, { Kit.corner(20), Kit.pad(16, 16) })
	local detScroll = Modal.scroll(det)
	Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = detScroll
	ui.detail = detScroll
	Audio.play("open")
	Router.open("hudPulse", { key = "inventory", on = false })
	render()
end

function Inventory.init()
	Router.register("inventory", open)
	State.onChange(function()
		render()
	end)
end

return Inventory
