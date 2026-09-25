--!strict
-- Inventario (renderInventory / renderInvDetail de game5.js): filtros por rareza y favoritos,
-- detalle, equipar, favorito, vender y "Vender repetidos".
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

--- Tarjeta con miniatura (se reutiliza en intercambios).
function Inventory.card(parent: Instance, s: any, d: any?, selected: boolean?): TextButton
	local r = Catalog.R[s.rarity]
	local b = Kit.button("", if selected then Theme.lav else Theme.white, {
		Size = UDim2.fromOffset(104, 128),
		Parent = parent,
	})
	local th: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(88, 70),
		Parent = b,
	})
	Thumb.make(s, th)
	Kit.text(s.name, 11, {
		Font = Theme.bodyBlack,
		Position = UDim2.fromOffset(4, 76),
		Size = UDim2.new(1, -8, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = b,
	})
	Kit.text(r.name, 10, {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromHex(r.color),
		TextColor3 = Theme.white,
		Font = Theme.bodyBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 8, 1, -22),
		Size = UDim2.new(1, -16, 0, 16),
		Parent = b,
	})
	if s.fav then
		Kit.text("★", 16, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(20, 20),
			TextColor3 = Theme.yellowD,
			Parent = b,
		})
	end
	if d and d.equipped == s.id then
		Kit.text("Equipado", 10, {
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.mintD,
			TextColor3 = Theme.white,
			Font = Theme.bodyBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(58, 16),
			Parent = b,
		})
	end
	return b
end

local render: () -> ()

local function detail(d: any)
	Kit.clear(ui.detail)
	local s = Inv.sel and Profile.find(d, Inv.sel)
	if not s then
		Kit.text("Elige un squishy para verlo aquí.", 14, {
			TextColor3 = Theme.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = ui.detail,
		})
		return
	end
	local r = Catalog.R[s.rarity]
	local th: Frame = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 1, Parent = ui.detail }
	)
	Thumb.make(s, th)
	Kit.text(s.name, 20, { Font = Theme.display, LayoutOrder = 2, Parent = ui.detail })
	Kit.text(r.name, 12, {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromHex(r.color),
		TextColor3 = Theme.white,
		Font = Theme.bodyBlack,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 3,
		Parent = ui.detail,
	})
	local copies = 0
	for _, x in d.inventory do
		if Profile.idxKey(x) == Profile.idxKey(s) then
			copies += 1
		end
	end
	local mut = Catalog.MUT[s.mutation]
	local rows = {
		{ "Encontrado", os.date("%d/%m/%Y", s.dateFound) :: string },
		{ "Valor", Format.int(s.value) .. " monedas" },
		{ "Relleno", if Catalog.FIL[s.filling] then Catalog.FIL[s.filling].name else "—" },
		{ "Tamaño", string.format("%.2f×", s.size * ((mut and mut.size) or 1)) },
		{ "Copias", tostring(copies) },
	}
	for i, kv in rows do
		Kit.text(
			string.format('<font color="#6d7285">%s</font>   <b>%s</b>', kv[1], kv[2]),
			13,
			{ LayoutOrder = 10 + i, Parent = ui.detail }
		)
	end
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 30,
		Parent = ui.detail,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local eq = Kit.button(
		if d.equipped == s.id then "Quitar" else "Equipar",
		Theme.mint,
		{ Size = UDim2.new(0.5, -3, 1, 0), Parent = row }
	)
	local fav = Kit.button(
		if s.fav then "★ Quitar fav" else "☆ Favorito",
		Theme.white,
		{ Size = UDim2.new(0.5, -3, 1, 0), TextSize = 14, Parent = row }
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
	for id, b in ui.tabs do
		b.BackgroundColor3 = if Inv.filter == id then Theme.pink else Theme.white
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
			{ TextColor3 = Theme.muted, Size = UDim2.fromOffset(400, 60), Parent = ui.grid }
		)
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
	local content = Modal.open("inventory", "Inventario", {
		width = 900,
		height = 580,
		onClose = function()
			ui = {}
		end,
	})
	ui.count = Kit.text("", 16, {
		Font = Theme.display,
		TextColor3 = Theme.muted,
		Position = UDim2.new(0, 150, 0, -46),
		Size = UDim2.fromOffset(100, 30),
		Parent = content,
	})
	local dupes = Kit.button("Vender repetidos", Theme.yellow, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -50, 0, -48),
		Size = UDim2.fromOffset(170, 36),
		TextSize = 14,
		Parent = content,
	})
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
	local tabs: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	ui.tabs = {}
	local ids = { "all" }
	for _, r in Config.Rarities do
		table.insert(ids, r.id)
	end
	table.insert(ids, "favorites")
	for i, id in ids do
		local label = if id == "all" then "Todos" elseif id == "favorites" then "★ Favoritos" else Catalog.R[id].name
		local b = Kit.button(label, Theme.white, {
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 13,
			LayoutOrder = i,
			Parent = tabs,
		})
		Kit.pad(10, 0).Parent = b
		ui.tabs[id] = b
		b.Activated:Connect(function()
			Inv.filter = id
			Audio.play("click")
			render()
		end)
	end
	local gridHolder = Modal.scroll(content, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, -280, 1, -40),
	})
	Kit.grid(UDim2.fromOffset(104, 128), 8).Parent = gridHolder
	Kit.pad(2, 4).Parent = gridHolder
	ui.grid = gridHolder
	local det: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(0, 266, 1, -40),
		Parent = content,
	}, { Kit.corner(16), Kit.pad(12, 10) })
	local detScroll = Modal.scroll(det)
	Kit.list(Enum.FillDirection.Vertical, 6).Parent = detScroll
	ui.detail = detScroll
	Audio.play("open")
	render()
end

function Inventory.init()
	Router.register("inventory", open)
	State.onChange(function()
		render()
	end)
end

return Inventory
