--!strict
-- Índice Squishy (renderIndex de game5.js + #indexWrap): "N / 413 descubiertos — las siluetas
-- siguen siendo un misterio", pestañas por especie (con wrap), celdas con barra de color arriba.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Config = require(Shared.Config)
local Profile = require(Shared.Logic.Profile)
local Squishy = require(Shared.Logic.Squishy)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Index = {}
local current = "cat"
local ui: { [string]: any } = {}

local function render()
	local d = State.data
	if not d or Modal.current ~= "index" or not ui.grid then
		return
	end
	ui.count.Text = string.format("%d / %d", Profile.discoveredCount(d), Catalog.indexTotal())
	Kit.clear(ui.tabs)
	for i, sp in Config.Species do
		local vs = Catalog.variantsFor(sp.id)
		local c = 0
		for _, v in vs do
			if d.discovered[sp.id .. "|" .. v] then
				c += 1
			end
		end
		local b = Kit.tab(
			string.format(
				"%s%s <font transparency='0.4'>%d/%d</font>",
				if sp.famous then "✨ " else "",
				sp.name,
				c,
				#vs
			),
			current == sp.id,
			sp.famous,
			{ LayoutOrder = i, Parent = ui.tabs }
		)
		b.Activated:Connect(function()
			current = sp.id
			Audio.play("click")
			render()
		end)
	end
	Kit.clear(ui.grid)
	local gen = {}
	ui.gen = gen
	local vs = Catalog.variantsFor(current)
	-- miniaturas progresivas para que la UI no se trabe (como el prototipo)
	task.spawn(function()
		for i, vid in vs do
			if ui.gen ~= gen then
				return
			end
			local v = Catalog.VAR[vid]
			local known = d.discovered[current .. "|" .. vid] == true
			local r = Catalog.R[v.rarity]
			-- .idx: blanca, radius 15, borde superior de 5px del color de la rareza, sombra lav2
			local cell: Frame = Kit.new("Frame", {
				BackgroundColor3 = Theme.white,
				ClipsDescendants = false,
				LayoutOrder = i,
				Parent = ui.grid,
			}, { Kit.corner(15) })
			Kit.shadow(cell, Theme.lav2, 3, 15)
			Kit.new("Frame", {
				BackgroundColor3 = Color3.fromHex(r.color),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -12, 0, 5),
				Parent = cell,
			}, { Kit.corner(3) })
			local th: Frame = Kit.new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(84, 84),
				Parent = cell,
			})
			Thumb.make({ species = current, variant = vid }, th, not known)
			Kit.text(
				if known then Squishy.name({ species = current, variant = vid, mutation = "normal" }) else "???",
				11.5,
				{
					FontFace = Theme.bodyBlack,
					TextColor3 = if known then Theme.ink else Color3.fromHex("#a7abb9"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.new(0, 4, 1, -34),
					Size = UDim2.new(1, -8, 0, 30),
					LineHeight = 0.95,
					Parent = cell,
				}
			)
			if i % 6 == 0 then
				task.wait()
			end
		end
	end)
end

local function open()
	local content = Modal.open("index", "Índice Squishy", {
		width = 900,
		height = 660,
		onClose = function()
			ui = {}
		end,
	})
	local head: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 14) });
	(head:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
	ui.count = Kit.text("", 30, {
		FontFace = Theme.display,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		TextWrapped = false,
		Parent = head,
	})
	Kit.text("descubiertos — las siluetas siguen siendo un misterio", 16, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.muted,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = head,
	})
	local tabs: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = content,
	})
	local tl = Kit.list(Enum.FillDirection.Horizontal, 6)
	tl.Wraps = true
	tl.Parent = tabs
	ui.tabs = tabs
	local grid = Modal.scroll(content, { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 1, -150) })
	local function place()
		grid.Position = UDim2.fromOffset(0, 52 + tabs.AbsoluteSize.Y)
		grid.Size = UDim2.new(1, 0, 1, -(52 + tabs.AbsoluteSize.Y))
	end
	tabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local inner: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = grid,
	}, { Kit.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8) }) })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 132),
		CellPadding = UDim2.fromOffset(9, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inner,
	})
	ui.grid = inner
	Audio.play("open")
	render()
	task.defer(place)
end

function Index.init()
	Router.register("index", open)
end

return Index
