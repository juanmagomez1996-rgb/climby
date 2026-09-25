--!strict
-- Panel "Crea un Squishy" + llenado (Fase 4). Porte de openMachine / renderMachinePanel /
-- holdStart / holdEnd de game5.js. El medidor se anima aquí con la MISMA fórmula, pero el resultado
-- (under/perfect/over/POP y la rareza) lo decide el servidor (FillService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Profile = require(Shared.Logic.Profile)
local Squishy = require(Shared.Logic.Squishy)
local SquishyFactory = require(script.Parent.Parent.Engine.SquishyFactory)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local FILL = Config.Game.FILL
local M = Config.Monetization

local Machine = {}

type FillState = {
	state: string, -- idle | filling | processing | reveal
	machine: any?,
	species: string,
	filling: string,
	p: number,
	held: number,
	holding: boolean,
	started: boolean,
}

local Fill: FillState = {
	state = "idle",
	machine = nil,
	species = "cat",
	filling = "pink_foam",
	p = 0,
	held = 0,
	holding = false,
	started = false,
}

local ui: { [string]: any } = {}
local inside: Model? = nil

local function machineDef(id: string): any
	for _, m in Config.Machines do
		if m.id == id then
			return m
		end
	end
	return nil
end

local function domePos(id: string): Vector3
	for _, m in Config.WorldLayout.machines do
		if m.id == id then
			return m.dome
		end
	end
	return Vector3.zero
end

--- Suerte que ve el cliente (misma cuenta que FillService.luck en el servidor, solo para mostrar).
local function clientLuck(d: any, res: string?): number
	local L = Squishy.totalLuck(d.upgrades.luck, Fill.machine, Fill.filling, res :: any)
	if d.passes and d.passes.luckPlus then
		L += M.EFFECTS.luckPlus
	end
	if (d.luckLeft or 0) > 0 then
		L += M.EFFECTS.luckPotion
	end
	return L
end

local function clearInside()
	if inside then
		inside:Destroy()
		inside = nil
	end
end

local function setInside()
	clearInside()
	if not Fill.machine then
		return
	end
	local fil = Catalog.FIL[Fill.filling]
	local sp = Catalog.SP[Fill.species]
	local m = SquishyFactory.build({
		species = Fill.species,
		variant = if sp and sp.famous then "original" else "classic",
		mutation = "normal",
		size = 1,
	})
	-- tiñe con el color del relleno mientras se llena
	local body = m:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") and fil then
		body.Color = Color3.fromHex(fil.color3 or (string.sub(fil.color, 1, 1) == "#" and fil.color) or "#F7A7CD")
	end
	m:ScaleTo(0.35)
	m:PivotTo(CFrame.new(domePos(Fill.machine.id)))
	m.Parent = Workspace
	inside = m
end

local function setGauge(p: number)
	if not ui.needle then
		return
	end
	local x = math.clamp(p, 0, FILL.pop) / FILL.pop
	ui.needle.Position = UDim2.new(x, 0, 0.5, 0)
	ui.prog.Size = UDim2.fromScale(x, 1)
end

local function resultText(txt: string, color: Color3)
	if ui.result then
		ui.result.Text = txt
		ui.result.TextColor3 = color
	end
end

local render: () -> ()

local function moldButton(parent: Instance, sp: any, d: any, locked: boolean)
	local avail = Profile.moldAvailable(d, sp.id)
	local b = Kit.button("", if Fill.species == sp.id then Theme.pink else Theme.white, {
		Size = UDim2.fromOffset(92, 92),
		Parent = parent,
	})
	local thumbHolder: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 2),
		Size = UDim2.fromOffset(68, 60),
		Parent = b,
	})
	Thumb.make({ species = sp.id, variant = if sp.famous then "original" else "classic" }, thumbHolder)
	Kit.text(sp.name, 11, {
		Position = UDim2.new(0, 4, 1, -30),
		Size = UDim2.new(1, -8, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.bodyBlack,
		Parent = b,
	})
	if not avail then
		Kit.text(if sp.famous then "🛒 " .. Format.int(sp.price) else "Nv " .. sp.unlockLevel, 11, {
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.ink,
			TextColor3 = Theme.white,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Position = UDim2.fromOffset(4, 4),
			Parent = b,
		})
		b.BackgroundTransparency = 0.35
	end
	b.Activated:Connect(function()
		if locked or Fill.state ~= "idle" then
			return
		end
		if not avail then
			Audio.play("error")
			Toast.show(
				if sp.famous
					then string.format("El molde %s se compra en la Tienda (%s monedas)", sp.name, Format.int(sp.price))
					else string.format("El molde %s se desbloquea en el nivel %d", sp.name, sp.unlockLevel)
			)
			return
		end
		Fill.species = sp.id
		Audio.play("click")
		render()
		setInside()
	end)
end

render = function()
	local d = State.data
	if not d or Modal.current ~= "machine" or not ui.body then
		return
	end
	local locked = Fill.state ~= "idle"
	-- moldes
	Kit.clear(ui.molds)
	Kit.clear(ui.virals)
	local virals = {}
	for _, sp in Config.Species do
		if sp.famous then
			table.insert(virals, sp)
		else
			moldButton(ui.molds, sp, d, locked)
		end
	end
	table.sort(virals, function(a, b)
		local aa, bb = Profile.moldAvailable(d, a.id), Profile.moldAvailable(d, b.id)
		if aa ~= bb then
			return aa
		end
		return a.price < b.price
	end)
	for _, sp in virals do
		moldButton(ui.virals, sp, d, locked)
	end
	-- rellenos
	Kit.clear(ui.fills)
	for _, f in Config.Fillings do
		local own = table.find(d.fillings, f.id) ~= nil
		local label = f.name
		if own and f.perUse then
			label ..= if d.passes and d.passes.vip then " (gratis 👑)" else string.format(" (%d)", f.perUse)
		elseif not own then
			label ..= " 🔒"
		end
		local b = Kit.button(label, if Fill.filling == f.id then Theme.pink else Theme.white, {
			Size = UDim2.fromOffset(128, 34),
			TextSize = 12,
			Parent = ui.fills,
		})
		local sw = Color3.fromHex(f.color3 or (string.sub(f.color, 1, 1) == "#" and f.color) or "#ffd36e")
		Kit.new("Frame", {
			BackgroundColor3 = sw,
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(0, 6, 0.5, -6),
			Parent = b,
		}, { Kit.corner(6) })
		b.Activated:Connect(function()
			if Fill.state ~= "idle" then
				return
			end
			if not own then
				Audio.play("error")
				Toast.show(string.format("%s se vende en la Tienda (%s monedas)", f.name, Format.int(f.price)))
				return
			end
			Fill.filling = f.id
			Audio.play("click")
			render()
			setInside()
		end)
	end
	-- probabilidades (normal y con Perfecto)
	Kit.clear(ui.odds)
	local w = Squishy.rarityWeights(clientLuck(d, nil), Fill.filling)
	local tot = 0
	for _, x in w do
		tot += x
	end
	for i, r in Config.Rarities do
		local pct = w[i] / tot * 100
		Kit.text(
			string.format(
				"%s %s%%",
				string.sub(r.name, 1, 4),
				if i > 3 then string.format("%.1f", pct) else string.format("%d", math.round(pct))
			),
			11,
			{
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromHex(r.color),
				TextColor3 = Theme.white,
				Font = Theme.bodyBlack,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(62, 20),
				Parent = ui.odds,
			}
		)
	end
	-- botón
	local full = #d.inventory >= (d.capacity or 20)
	ui.hold.Text = if Fill.state == "filling" and Fill.holding then "Llenando… ¡suelta!" else "Mantén para llenar"
	Kit.setEnabled(ui.hold, Fill.state == "idle" or Fill.state == "filling")
	if full and Fill.state == "idle" then
		resultText(
			string.format("Inventario lleno (%d). Vende algunos squishies primero.", d.capacity or 20),
			Theme.red
		)
		Kit.setEnabled(ui.hold, false)
	elseif Fill.state == "idle" and ui.result.Text ~= "" and not ui.keepResult then
		resultText("", Theme.muted)
	end
end

local function processing(res: { [string]: any })
	Fill.state = "processing"
	render()
	local labels: { [string]: { any } } = {
		under = { "Le faltó", Theme.muted },
		perfect = { "¡PERFECTO!", Theme.green },
		over = { "Se pasó", Theme.orange },
	}
	local l = labels[res.result]
	resultText(l[1], l[2])
	if res.result == "perfect" then
		Audio.play("sparkle")
	end
	Audio.play("whirr")
	task.delay(FILL.process, function()
		clearInside()
		Fill.state = "reveal"
		Router.open("reveal", { squishy = res.squishy, isNew = res.isNew, fromMachine = true })
	end)
end

local function popped()
	Fill.state = "processing"
	Audio.play("pop")
	clearInside()
	resultText("¡POP! Se reventó — demasiado lleno.", Theme.red)
	task.delay(1.4, function()
		Fill.state = "idle"
		Fill.p = 0
		Fill.held = 0
		Fill.started = false
		setGauge(0)
		ui.keepResult = false
		render()
		setInside()
	end)
end

local function holdEnd()
	if not Fill.holding then
		return
	end
	Fill.holding = false
	Audio.loop("fillLoop", false)
	if Fill.state ~= "filling" then
		return
	end
	-- espera a que el servidor haya registrado el inicio
	local t0 = os.clock()
	while not Fill.started and os.clock() - t0 < 3 and Fill.state == "filling" do
		task.wait()
	end
	if Fill.state ~= "filling" then
		return
	end
	local res = State.request("fillRelease", { held = Fill.held })
	if not res.ok then
		Fill.state = "idle"
		Fill.p = 0
		Fill.held = 0
		Fill.started = false
		setGauge(0)
		render()
		return
	end
	Fill.held = res.held or Fill.held
	Fill.p = res.p or Fill.p
	setGauge(Fill.p)
	if res.result == "short" then
		resultText("Sigue manteniendo…", Theme.muted)
		ui.keepResult = true
		render()
	elseif res.result == "pop" then
		ui.keepResult = true
		popped()
	else
		ui.keepResult = true
		processing(res)
	end
end

local function holdStart()
	if Modal.current ~= "machine" or not Fill.machine then
		return
	end
	local d = State.data
	if not d then
		return
	end
	if Fill.state == "idle" then
		if #d.inventory >= (d.capacity or 20) then
			Audio.play("error")
			return
		end
		Fill.state = "filling"
		Fill.p = 0
		Fill.held = 0
		Fill.started = false
		ui.keepResult = false
		resultText("", Theme.muted)
	elseif Fill.state ~= "filling" then
		return
	end
	Fill.holding = true
	Audio.loop("fillLoop", true)
	render()
	task.spawn(function()
		local res = State.request("fillStart", {
			machine = Fill.machine.id,
			species = Fill.species,
			filling = Fill.filling,
		})
		if not res.ok then
			Fill.holding = false
			Fill.state = "idle"
			Fill.p = 0
			Fill.held = 0
			setGauge(0)
			Audio.loop("fillLoop", false)
			Audio.play("error")
			if res.err == "pending" and res.squishy then
				Router.open("reveal", { squishy = res.squishy, isNew = false, fromMachine = true })
			elseif type(res.err) == "string" and #res.err > 12 then
				Toast.show(res.err)
			end
			render()
			return
		end
		Fill.started = true
	end)
end

local function open(machineId: string)
	local d = State.data
	local def = machineDef(machineId)
	if not d or not def then
		return
	end
	if d.level < def.level then
		Audio.play("error")
		Toast.show(string.format("%s se abre en el nivel %d", def.name, def.level))
		return
	end
	Fill.machine = def
	Fill.state = "idle"
	Fill.p = 0
	Fill.held = 0
	Fill.started = false
	Fill.species = if Profile.moldAvailable(d, d.lastMold) then d.lastMold else "cat"
	Fill.filling = if table.find(d.fillings, d.lastFill) then d.lastFill else "classic_foam"
	if d.tutorial <= 2 then
		Fill.species = "cat"
		Fill.filling = "pink_foam"
	end
	local content = Modal.open("machine", if def.id == "m1" then "Crea un Squishy" else def.name, {
		width = 470,
		height = 660,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -16, 0.5, 10),
		onClose = function()
			if Fill.holding then
				Fill.holding = false
				Audio.loop("fillLoop", false)
			end
			if Fill.state == "filling" then
				State.request("fillCancel")
			end
			if Fill.state ~= "reveal" then
				Fill.state = "idle"
			end
			clearInside()
			ui = {}
		end,
	})
	local scroll = Modal.scroll(content)
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	ui.body = scroll
	local info = string.format("%s · %s", def.name, def.sub)
	if def.luck and def.luck > 0 then
		info ..= string.format(" · +%d%% suerte", math.round(def.luck * 100))
	end
	if def.mutX then
		info ..= " · más mutaciones"
	end
	Kit.text(info, 13, { TextColor3 = Theme.muted, LayoutOrder = 1, Parent = scroll })

	local function section(title: string, order: number, color: Color3?): Frame
		Kit.text(
			title,
			15,
			{ Font = Theme.display, TextColor3 = color or Theme.ink, LayoutOrder = order, Parent = scroll }
		)
		local f: Frame = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -8, 0, 0),
			LayoutOrder = order + 1,
			Parent = scroll,
		})
		local g = Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(92, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = f,
		})
		ui["grid" .. order] = g
		return f
	end
	ui.molds = section("Moldes", 10)
	ui.virals = section("✨ Moldes virales", 20, Color3.fromHex("#a86ad0"))
	ui.fills = section("Relleno", 30)
	ui["grid30"].CellSize = UDim2.fromOffset(128, 34)

	Kit.text("Probabilidades", 13, { TextColor3 = Theme.muted, LayoutOrder = 40, Parent = scroll })
	ui.odds = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 22),
		LayoutOrder = 41,
		Parent = scroll,
	}, { Kit.list(Enum.FillDirection.Horizontal, 4) })

	-- medidor con zonas (gauge del prototipo)
	local gauge: Frame = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromHex("#e9e4f2"),
		Size = UDim2.new(1, -8, 0, 30),
		ClipsDescendants = true,
		LayoutOrder = 50,
		Parent = scroll,
	}, { Kit.corner(15) })
	local span = FILL.pop
	local function zone(a: number, b: number, col: string)
		Kit.new("Frame", {
			BackgroundColor3 = Color3.fromHex(col),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(a / span, 0),
			Size = UDim2.fromScale((b - a) / span, 1),
			Parent = gauge,
		})
	end
	zone(FILL.perfect[1], FILL.perfect[2], "#9CE0CA")
	zone(FILL.perfect[2], span * 0.97, "#ffd9a8")
	zone(span * 0.97, span, "#ff9aa8")
	ui.prog = Kit.new("Frame", {
		BackgroundColor3 = Theme.pink,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = gauge,
	})
	ui.needle = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.ink,
		Size = UDim2.new(0, 4, 1, 4),
		Position = UDim2.fromScale(0, 0.5),
		Parent = gauge,
	})
	local lbl: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 16),
		LayoutOrder = 51,
		Parent = scroll,
	})
	local gaugeLabels: { { any } } = {
		{ "Le falta", 0 },
		{ "Perfecto", FILL.perfect[1] / span },
		{ "Se pasa", FILL.perfect[2] / span },
		{ "¡POP!", 0.97 },
	}
	for _, info2 in gaugeLabels do
		Kit.text(info2[1] :: string, 11, {
			Position = UDim2.fromScale(info2[2] :: number, 0),
			Size = UDim2.fromOffset(70, 16),
			TextColor3 = Theme.muted,
			Font = Theme.bodyBlack,
			Parent = lbl,
		})
	end

	ui.hold = Kit.button("Mantén para llenar", Theme.pink, {
		Size = UDim2.new(1, -8, 0, 56),
		TextSize = 20,
		Font = Theme.display,
		LayoutOrder = 60,
		Parent = scroll,
	})
	ui.hold.MouseButton1Down:Connect(holdStart)
	ui.hold.MouseButton1Up:Connect(function()
		task.spawn(holdEnd)
	end)
	ui.hold.MouseLeave:Connect(function()
		if Fill.holding then
			task.spawn(holdEnd)
		end
	end)
	ui.result = Kit.text("", 18, {
		Font = Theme.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -8, 0, 44),
		LayoutOrder = 61,
		Parent = scroll,
	})
	Audio.play("open")
	render()
	setGauge(0)
	setInside()
	if d.tutorial < 3 then
		State.request("tutorial", { step = 3 })
		Toast.show(
			"El molde Gato y la Espuma Rosa están listos. ¡Mantén el botón y suelta en la zona verde Perfecto!",
			false,
			5000
		)
	end
end

--- La revelación terminó (guardado o vendido): la máquina vuelve a estar lista.
function Machine.revealDone()
	Fill.state = "idle"
	Fill.p = 0
	Fill.held = 0
	Fill.started = false
	ui.keepResult = false
	setGauge(0)
	if Modal.current == "machine" then
		render()
		setInside()
	end
end

function Machine.reopen()
	if Fill.machine then
		open(Fill.machine.id)
	end
end

function Machine.init()
	Router.register("machine", function(id)
		open(tostring(id))
	end)
	State.onChange(function()
		if Fill.state == "idle" then
			render()
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		if Fill.holding and Fill.state == "filling" then
			local d = State.data
			local speed = if d then d.upgrades.fillSpeed else 1
			local time = FILL.baseTime / (1 + 0.2 * (speed - 1))
			Fill.p += dt / time * (1 + Fill.p * 0.35)
			Fill.held += dt
			setGauge(Fill.p)
			if inside then
				inside:ScaleTo(0.35 + 0.65 * math.min(1.1, Fill.p))
			end
			if Fill.p >= FILL.pop then
				task.spawn(holdEnd)
			end
		end
	end)
end

return Machine
