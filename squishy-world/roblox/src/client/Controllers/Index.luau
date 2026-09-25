--!strict
-- Índice Squishy (renderIndex de game5.js): 413 entradas, siluetas "???" hasta descubrirlas.
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
	ui.count.Text = string.format(
		"%d / %d  <font size='13' color='#6d7285'>descubiertos — las siluetas siguen siendo un misterio</font>",
		Profile.discoveredCount(d),
		Catalog.indexTotal()
	)
	Kit.clear(ui.tabs)
	for i, sp in Config.Species do
		local vs = Catalog.variantsFor(sp.id)
		local c = 0
		for _, v in vs do
			if d.discovered[sp.id .. "|" .. v] then
				c += 1
			end
		end
		local b = Kit.button(
			string.format(
				"%s%s <font transparency='0.4'>%d/%d</font>",
				if sp.famous then "✨ " else "",
				sp.name,
				c,
				#vs
			),
			if current == sp.id then Theme.purple else Theme.white,
			{
				Size = UDim2.new(1, -8, 0, 30),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
				Parent = ui.tabs,
			}
		)
		Kit.pad(8, 0).Parent = b
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
			local cell: Frame = Kit.new("Frame", {
				BackgroundColor3 = Theme.white,
				LayoutOrder = i,
				Parent = ui.grid,
			}, { Kit.corner(12), Kit.stroke(Color3.fromHex(r.color), 2) })
			local th: Frame = Kit.new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.new(1, -12, 0, 70),
				Parent = cell,
			})
			Thumb.make({ species = current, variant = vid }, th, not known)
			Kit.text(
				if known then Squishy.name({ species = current, variant = vid, mutation = "normal" }) else "???",
				11,
				{
					Font = Theme.bodyBlack,
					TextColor3 = if known then Theme.ink else Color3.fromHex("#a7abb9"),
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.new(0, 4, 1, -32),
					Size = UDim2.new(1, -8, 0, 28),
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
		height = 580,
		onClose = function()
			ui = {}
		end,
	})
	ui.count = Kit.text("", 20, { Font = Theme.display, Size = UDim2.new(1, 0, 0, 26), Parent = content })
	local tabs = Modal.scroll(content, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(0, 230, 1, -34) })
	Kit.list(Enum.FillDirection.Vertical, 4).Parent = tabs
	ui.tabs = tabs
	local grid = Modal.scroll(content, { Position = UDim2.fromOffset(240, 34), Size = UDim2.new(1, -240, 1, -34) })
	Kit.grid(UDim2.fromOffset(100, 112), 8).Parent = grid
	Kit.pad(2, 4).Parent = grid
	ui.grid = grid
	Audio.play("open")
	render()
end

function Index.init()
	Router.register("index", open)
end

return Index
