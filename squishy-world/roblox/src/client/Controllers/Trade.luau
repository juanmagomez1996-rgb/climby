--!strict
-- Chat con NPC (#npcWrap) y Cambio con NPC (#tradeWrap) como el original (game5.js openNPC /
-- sendChat / openTrade), + intercambio entre jugadores reales (extra multijugador, mismo estilo).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Audio = require(script.Parent.Audio)
local Inventory = require(script.Parent.Inventory)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Trade = {}
Trade.roomContent = (nil :: any) :: Frame

local GREY2 = Color3.fromHex("#8b90a3")

-- ─────────────── piezas comunes ───────────────
local function valueRow(parent: Instance, order: number, title: string, value: number): Frame
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.h3(title, { Size = UDim2.fromScale(0.6, 1), Parent = row })
	if value > 0 then
		local v: Frame = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Parent = row,
		}, { Kit.list(Enum.FillDirection.Horizontal, 5) });
		(v:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
		Kit.text(Format.int(value), 15, {
			FontFace = Theme.bodyBlack,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			TextWrapped = false,
			LayoutOrder = 1,
			Parent = v,
		})
		Kit.coin(14, { LayoutOrder = 2, Parent = v })
	end
	return row
end

-- .slot: flex 1, min-height 120, borde lav2, fondo blanco .6, 12px 900 #8b90a3
local function slots(
	parent: Instance,
	order: number,
	items: { any },
	max: number,
	emptyText: string,
	showRarity: boolean,
	onClick: ((any) -> ())?
)
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 124),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	for i = 1, max do
		local s = items[i]
		local slot = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = s ~= nil and onClick ~= nil,
			BackgroundColor3 = Theme.white,
			BackgroundTransparency = if s then 0 else 0.4,
			Size = UDim2.new(1 / max, -8 * (max - 1) / max, 1, 0),
			LayoutOrder = i,
			Parent = row,
		}, { Kit.corner(16), Kit.stroke(Theme.lav2, 3) })
		if s then
			local th: Frame = Kit.new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				Size = UDim2.fromOffset(74, 74),
				Parent = slot,
			})
			Thumb.make(s, th)
			Kit.text(s.name, 11, {
				FontFace = Theme.bodyBlack,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 4, 0, 80),
				Size = UDim2.new(1, -8, 0, 24),
				LineHeight = 0.95,
				Parent = slot,
			})
			if showRarity then
				local r = Catalog.R[s.rarity]
				Kit.text(r.name, 11, {
					FontFace = Theme.bodyBlack,
					TextColor3 = Color3.fromHex(r.color),
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.new(0, 4, 1, -18),
					Size = UDim2.new(1, -8, 0, 14),
					Parent = slot,
				})
			end
			if onClick then
				slot.Activated:Connect(function()
					onClick(s)
				end)
			end
		else
			Kit.text(emptyText, 12, {
				FontFace = Theme.bodyBlack,
				TextColor3 = GREY2,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = slot,
			})
		end
	end
end

-- .miniGrid: mínimo 78px, gap 7; elegida = borde mintD
local function miniGrid(
	parent: Instance,
	order: number,
	d: any,
	chosen: { string },
	max: number,
	onToggle: (string) -> ()
)
	local sc = Modal.scroll(parent, { Size = UDim2.new(1, 0, 1, -236), LayoutOrder = order })
	sc.AutomaticSize = Enum.AutomaticSize.None
	local inner: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		Parent = sc,
	})
	Kit.grid(UDim2.fromOffset(78, 100), 7).Parent = inner
	local avail = {}
	for _, s in d.inventory do
		if s.id ~= d.equipped then
			table.insert(avail, s)
		end
	end
	table.sort(avail, function(a: any, b: any)
		return a.value > b.value
	end)
	if #avail == 0 then
		Kit.text(
			"No tienes squishies para ofrecer (el equipado se queda contigo).",
			13,
			{ TextColor3 = Theme.grey, Size = UDim2.fromOffset(300, 50), Parent = inner }
		)
	end
	for i, s in avail do
		local b = Inventory.card(inner, s, nil, table.find(chosen, s.id) ~= nil, true)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			if not table.find(chosen, s.id) and #chosen >= max then
				Audio.play("error")
				return
			end
			Audio.play("click")
			onToggle(s.id)
		end)
	end
end

local function column(parent: Instance, x: number, w: number): Frame
	local col: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		Position = UDim2.new(x, if x > 0 then 7 else 0, 0, 0),
		Size = UDim2.new(w, -7, 1, -64),
		Parent = parent,
	}, { Kit.corner(20), Kit.pad(14, 14), Kit.list(Enum.FillDirection.Vertical, 8) })
	return col
end

local function fairness(parent: Instance, order: number, ratio: number, hasTheirs: boolean)
	Kit.text("Medidor del trato", 12, { TextColor3 = Theme.muted, LayoutOrder = order, Parent = parent })
	local bar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.white,
		Size = UDim2.new(1, 0, 0, 12),
		LayoutOrder = order + 1,
		Parent = parent,
	}, { Kit.corner(7) })
	local fill: Frame = Kit.new("Frame", {
		BackgroundColor3 = if ratio >= 1.15
			then Color3.fromHex("#FFC83A")
			elseif ratio >= 0.8 then Theme.mint
			else Color3.fromHex("#ff9aa8"),
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Kit.corner(7) })
	Kit.tween(fill, 0.3, { Size = UDim2.fromScale(math.clamp(ratio / 1.5, 0, 1), 1) })
	Kit.text(
		if not hasTheirs
			then ""
			elseif ratio >= 1.15 then "Súper trato para ellos: van a decir que sí."
			elseif ratio >= 0.8 then "Cambio justo: seguramente aceptan."
			else "Quieren más. Agrega otro squishy.",
		13,
		{ FontFace = Theme.bodyBlack, LayoutOrder = order + 2, Parent = parent }
	)
end

-- ─────────────── Cambio con NPC ───────────────
local function openNpcTrade(npcName: any)
	local res = State.request("npcTrade", { op = "open", npc = npcName })
	if not res.ok then
		if res.err then
			Toast.show(res.err)
		end
		return
	end
	local st = res
	local mine: { string } = {}
	local d0 = State.data
	local content = Modal.open("trade", "Cambio con " .. tostring(npcName), {
		width = 960,
		height = 640,
		onClose = function()
			State.request("npcTrade", { op = "close" })
		end,
	})
	local msg = if d0 and #d0.inventory > 0
		then "Elige lo que quieres ofrecer."
		else "¡Todavía no tienes nada para cambiar!"
	local function render()
		local d = State.data
		if Modal.current ~= "trade" or not d then
			return
		end
		Kit.clear(content)
		local mineItems = {}
		for _, id in mine do
			for _, s in d.inventory do
				if s.id == id then
					table.insert(mineItems, s)
				end
			end
		end
		-- columna izquierda: Tu oferta + inventario
		local left = column(content, 0, 0.5)
		valueRow(left, 1, "Tu oferta", st.myVal)
		slots(left, 2, mineItems, 3, "Vacío", false, function(s)
			table.remove(mine, table.find(mine, s.id) or 0)
			st = State.request("npcTrade", { op = "set", ids = mine })
			render()
		end)
		Kit.text("Elige hasta 3 squishies", 12, { TextColor3 = Theme.muted, LayoutOrder = 3, Parent = left })
		miniGrid(left, 4, d, mine, 3, function(id)
			local at = table.find(mine, id)
			if at then
				table.remove(mine, at)
			else
				table.insert(mine, id)
			end
			st = State.request("npcTrade", { op = "set", ids = mine })
			if st.msg then
				msg = st.msg
			end
			render()
		end)
		-- columna derecha: Su oferta + medidor
		local right = column(content, 0.5, 0.5)
		valueRow(right, 1, "Su oferta", st.theirVal)
		slots(right, 2, if st.theirs then { st.theirs } else {}, 1, "Esperando tu oferta…", true)
		local ratio = if st.theirVal > 0 then st.myVal / st.theirVal else 0
		fairness(right, 3, ratio, st.theirVal > 0)
		local reroll = Kit.button(
			"Pedir otra cosa",
			Theme.white,
			{ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 10, Parent = right },
			"small"
		)
		Kit.setEnabled(reroll, #mine > 0 and st.rerolls < 3)
		reroll.Activated:Connect(function()
			if #mine == 0 or st.rerolls >= 3 then
				return
			end
			local r = State.request("npcTrade", { op = "reroll" })
			if r.ok then
				st = r
				msg = r.msg or msg
				Audio.play("select")
				render()
			end
		end)
		-- .tradeFoot: mensaje + Cancelar + Aceptar
		local foot: Frame = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 52),
			Parent = content,
		})
		Kit.text(msg, 15, {
			FontFace = Theme.bodyBlack,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, -340, 0, 40),
			Parent = foot,
		})
		local btns: Frame = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(320, 50),
			Parent = foot,
		}, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right) })
		local cancel =
			Kit.button("Cancelar", Theme.white, { Size = UDim2.fromOffset(130, 46), LayoutOrder = 1, Parent = btns })
		local accept = Kit.button(
			"Aceptar",
			Theme.mint,
			{ Size = UDim2.fromOffset(160, 50), LayoutOrder = 2, Parent = btns },
			"big"
		)
		Kit.setEnabled(accept, #mine > 0 and st.theirs ~= nil)
		cancel.Activated:Connect(Modal.close)
		accept.Activated:Connect(function()
			if #mine == 0 or not st.theirs then
				return
			end
			local r = State.request("npcTrade", { op = "accept" })
			if r.ok and r.done then
				Modal.close()
			elseif r.ok then
				st = r
				msg = r.msg or msg
				Audio.play("error")
				render()
			end
		end)
	end
	render()
end

-- ─────────────── Chat con NPC ───────────────
type ChatMsg = { me: boolean, text: string }
local chats: { [string]: { ChatMsg } } = {}

local function npcModel(name: string): Model?
	local f = Workspace:FindFirstChild("NPCs")
	local m = f and f:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

local function openChat(npcName: any)
	local name = tostring(npcName)
	local model = npcModel(name)
	local sqd: any = nil
	if model then
		local j = model:GetAttribute("Companion")
		if type(j) == "string" then
			local ok, v = pcall(HttpService.JSONDecode, HttpService, j)
			if ok then
				sqd = v
			end
		end
	end
	task.spawn(State.request, "npcTalk", { npc = name })
	local log: { ChatMsg } = chats[name] or {}
	if not chats[name] then
		chats[name] = log
		local greet = {
			string.format("¡Holi! Soy %s 👋", name),
			"¡Hola! ¡Mucho gusto!",
			if sqd
				then string.format("¡Ey! ¿Quieres ver mi %s? Puedes apachurrarlo 😄", sqd.name)
				else "¡Hola! ¡Mucho gusto!",
		}
		table.insert(log, { me = false, text = greet[math.random(1, #greet)] })
	end
	local content, title = Modal.open("npc", name, { width = 560, height = 560 })
	title.Position = UDim2.fromOffset(84, 14)
	title.TextSize = 24
	-- .npcAv: miniatura del squishy que presume
	local av: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.fromOffset(48, 48),
		Parent = title.Parent,
	}, { Kit.corner(14) })
	if sqd then
		Thumb.make(sqd, av)
		Kit.text(
			string.format("Presumiendo: %s · %s", sqd.name, Catalog.R[sqd.rarity] and Catalog.R[sqd.rarity].name or ""),
			12.5,
			{
				TextColor3 = Theme.muted,
				Position = UDim2.fromOffset(84, 44),
				Size = UDim2.new(1, -330, 0, 16),
				Parent = title.Parent,
			}
		)
	end
	title.Size = UDim2.new(1, -330, 0, 30)
	local btns: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 18),
		Size = UDim2.fromOffset(250, 30),
		Parent = title.Parent,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
	local sqBtn = Kit.button(
		"🖐️ Apachurrar",
		Theme.purple,
		{ Size = UDim2.fromOffset(120, 30), LayoutOrder = 1, Parent = btns },
		"small"
	)
	local tradeBtn =
		Kit.button("Cambiar", Theme.mint, { Size = UDim2.fromOffset(86, 30), LayoutOrder = 2, Parent = btns }, "small")
	sqBtn.Activated:Connect(function()
		Modal.close()
		if sqd then
			Router.open("studio", { squishy = sqd, owner = "De " .. name })
		end
	end)
	tradeBtn.Activated:Connect(function()
		Modal.close()
		openNpcTrade(name)
	end)
	content.Position = UDim2.fromOffset(20, 74)
	content.Size = UDim2.new(1, -40, 1, -88)
	local logFrame = Modal.scroll(content, { Size = UDim2.new(1, 0, 1, -78) })
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = logFrame
	Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6), Parent = logFrame })
	local busy = false
	local function renderLog()
		Kit.clear(logFrame)
		local items = table.clone(log)
		if busy then
			table.insert(items, { me = false, text = "escribiendo…" })
		end
		for i, m in items do
			local holder: Frame = Kit.new("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = i,
				Parent = logFrame,
			})
			-- .msg: máx 80%, padding 9/13, radius 16, 700 14.5; NPC lav a la izquierda, tú ink a la derecha
			Kit.new("TextLabel", {
				BackgroundColor3 = if m.me then Theme.ink else Theme.lav,
				TextColor3 = if m.me then Theme.white else Theme.ink,
				TextTransparency = if busy and i == #items then 0.4 else 0,
				FontFace = Theme.bodyBold,
				TextSize = 14.5,
				TextWrapped = true,
				Text = m.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				AnchorPoint = Vector2.new(if m.me then 1 else 0, 0),
				Position = UDim2.fromScale(if m.me then 1 else 0, 0),
				Parent = holder,
			}, {
				Kit.corner(16),
				Kit.pad(13, 9),
				Kit.new("UISizeConstraint", { MaxSize = Vector2.new(390, 1000) }),
			})
		end
		task.defer(function()
			logFrame.CanvasPosition = Vector2.new(0, 1e6)
		end)
	end
	-- barra de escritura: input con borde lav2 3px + "Enviar" (purple)
	local bar: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = content,
	})
	local input: TextBox = Kit.new("TextBox", {
		BackgroundColor3 = Theme.white,
		PlaceholderText = "Escribe algo…",
		PlaceholderColor3 = Theme.grey,
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.bodyBold,
		TextSize = 15,
		TextColor3 = Theme.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -100, 1, 0),
		Parent = bar,
	}, { Kit.corner(14), Kit.stroke(Theme.lav2, 3), Kit.pad(12, 0) })
	local send = Kit.button("Enviar", Theme.purple, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Parent = bar,
	})
	Kit.text("Chat en modo offline (respuestas predefinidas).", 11, {
		FontFace = Theme.body,
		TextColor3 = GREY2,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = content,
	})
	local function sendChat()
		local text = string.sub((string.gsub(input.Text, "^%s+", "")), 1, 140)
		if text == "" or busy then
			return
		end
		input.Text = ""
		busy = true
		Audio.play("click")
		table.insert(log :: { ChatMsg }, { me = true, text = text })
		renderLog()
		local r = State.request("npcChat", { npc = name, text = text })
		busy = false
		if r.ok then
			local mine = log[#log]
			mine.text = r.mine or mine.text
			table.insert(log :: { ChatMsg }, { me = false, text = r.say })
			Audio.play("npc", nil, 0.35)
			if r.wantsTrade then
				local stroke = Kit.new("UIStroke", { Color = Theme.pink, Thickness = 0, Parent = tradeBtn })
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < 4 and stroke.Parent do
						stroke.Thickness = 0
						stroke.Transparency = 0.1
						Kit.tween(stroke, 1.1, { Thickness = 8, Transparency = 1 })
						task.wait(1.1)
					end
					stroke:Destroy()
				end)
			end
		else
			table.remove(log)
		end
		if Modal.current == "npc" then
			renderLog()
		end
	end
	send.Activated:Connect(sendChat)
	input.FocusLost:Connect(function(enter)
		if enter then
			sendChat()
		end
	end)
	renderLog()
	Audio.play("open")
	task.defer(function()
		input:CaptureFocus()
	end)
end

-- ─────────────── Jugador ↔ jugador (extra) ───────────────
local room: any = nil
local myIds: { string } = {}

local function renderRoom()
	local d = State.data
	if not room or not d or Modal.current ~= "tradeRoom" then
		return
	end
	local content = Trade.roomContent
	Kit.clear(content)
	local function total(items: { any }): number
		local v = 0
		for _, s in items do
			v += s.value
		end
		return v
	end
	local left = column(content, 0, 0.5)
	valueRow(
		left,
		1,
		"Tu oferta" .. (if room.me.confirmed then " ✅" elseif room.me.ready then " 👍" else ""),
		total(room.me.items)
	)
	slots(left, 2, room.me.items, 4, "Vacío", false)
	Kit.text("Elige hasta 6 squishies", 12, { TextColor3 = Theme.muted, LayoutOrder = 3, Parent = left })
	miniGrid(left, 4, d, myIds, 6, function(id)
		local at = table.find(myIds, id)
		if at then
			table.remove(myIds, at)
		else
			table.insert(myIds, id)
		end
		State.request("trade", { op = "set", ids = myIds })
	end)
	local right = column(content, 0.5, 0.5)
	valueRow(
		right,
		1,
		"Oferta de "
			.. room.them.name
			.. (if room.them.confirmed then " ✅" elseif room.them.ready then " 👍" else ""),
		total(room.them.items)
	)
	slots(right, 2, room.them.items, 4, "Esperando su oferta…", true)
	if room.phase == "confirm" then
		Kit.text("Revisen bien: al confirmar los dos, el cambio es definitivo.", 13, {
			FontFace = Theme.bodyBlack,
			TextColor3 = Theme.pinkD,
			LayoutOrder = 3,
			Parent = right,
		})
	end
	local foot: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(360, 50),
		Parent = content,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right) })
	local cancel =
		Kit.button("Cancelar", Theme.white, { Size = UDim2.fromOffset(130, 46), LayoutOrder = 1, Parent = foot })
	cancel.Activated:Connect(function()
		State.request("trade", { op = "cancel" })
	end)
	if room.phase == "confirm" then
		local c = Kit.button(if room.me.confirmed then "Esperando…" else "Confirmar", Theme.mint, {
			Size = UDim2.fromOffset(180, 50),
			LayoutOrder = 2,
			Parent = foot,
		}, "big")
		Kit.setEnabled(c, not room.me.confirmed)
		c.Activated:Connect(function()
			State.request("trade", { op = "confirm" })
		end)
	else
		local r = Kit.button(if room.me.ready then "Quitar listo" else "¡Listo!", Theme.mint, {
			Size = UDim2.fromOffset(180, 50),
			LayoutOrder = 2,
			Parent = foot,
		}, "big")
		r.Activated:Connect(function()
			State.request("trade", { op = "ready", v = not room.me.ready })
		end)
	end
end

local function openPlayers()
	local content = Modal.open("tradePlayers", "Cambiar con jugadores", { width = 520, height = 480 })
	local sc = Modal.scroll(content)
	Kit.list(Enum.FillDirection.Vertical, 10).Parent = sc
	Kit.new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = sc })
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			others += 1
			local b = Kit.button(
				string.format("🤝  %s  <font color='#6d7285'>@%s</font>", p.DisplayName, p.Name),
				Theme.white,
				{ Size = UDim2.new(1, 0, 0, 46), Parent = sc }
			)
			b.Activated:Connect(function()
				local r = State.request("trade", { op = "request", userId = p.UserId })
				if r.ok then
					Toast.show("Solicitud enviada a " .. p.DisplayName)
					Modal.close()
				elseif r.err then
					Toast.show(r.err)
				end
			end)
		end
	end
	if others == 0 then
		Kit.text(
			"No hay otros jugadores en este servidor. ¡Invita a tus amigos! (o cambia con los jugadores de la Plaza de Intercambio)",
			14,
			{ TextColor3 = Theme.muted, Size = UDim2.new(1, 0, 0, 60), Parent = sc }
		)
	end
end

local function incomingRequest(from: number, name: string)
	Audio.play("npc")
	local card: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -180),
		Size = UDim2.fromOffset(340, 116),
		Parent = Kit.root(),
	}, { Kit.corner(18), Kit.pad(14, 12) })
	Kit.shadow(card, Color3.fromRGB(207, 208, 214), 5, 18)
	Kit.text(
		string.format("<b>%s</b> quiere intercambiar contigo 🤝", name),
		15,
		{ Size = UDim2.new(1, 0, 0, 44), Parent = card }
	)
	local yes = Kit.button(
		"Aceptar",
		Theme.mint,
		{ Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(0.5, -5, 0, 40), Parent = card }
	)
	local no = Kit.button(
		"No",
		Theme.white,
		{ Position = UDim2.new(0.5, 5, 1, -40), Size = UDim2.new(0.5, -5, 0, 40), Parent = card }
	)
	local function answer(v: boolean)
		if card.Parent then
			card:Destroy()
			local r = State.request("trade", { op = "respond", userId = from, accept = v })
			if not r.ok and r.err then
				Toast.show(r.err)
			end
		end
	end
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)
	task.delay(20, function()
		if card.Parent then
			answer(false)
		end
	end)
end

function Trade.init()
	Modal.addGuard(function()
		return if room then "Termina o cancela el intercambio primero" else nil
	end)
	Router.register("npcTrade", openNpcTrade)
	Router.register("npcChat", openChat)
	Router.register("tradePlayers", openPlayers)
	Remotes.event("TradeEvent").OnClientEvent:Connect(function(ev)
		if ev.t == "request" then
			incomingRequest(ev.from, ev.name)
		elseif ev.t == "state" then
			local first = room == nil
			room = ev
			myIds = {}
			for _, s in ev.me.items do
				table.insert(myIds, s.id)
			end
			if first or Modal.current ~= "tradeRoom" then
				Trade.roomContent = Modal.open("tradeRoom", "Cambio con " .. ev.them.name, {
					width = 960,
					height = 640,
					onClose = function()
						if room then
							room = nil
							State.request("trade", { op = "cancel" })
						end
					end,
				})
			end
			renderRoom()
		elseif ev.t == "closed" then
			room = nil
			if Modal.current == "tradeRoom" then
				Modal.close()
			end
			if ev.reason and ev.reason ~= "done" then
				Toast.show(ev.reason)
			end
		end
	end)
	State.onChange(function()
		renderRoom()
	end)
end

return Trade
