--!strict
-- Intercambios: con NPC (medidor 0.8 / 1.15, "¿y otro?") y con jugadores reales
-- (solicitud → ofertas → Listo → Confirmar; el servidor hace el cambio de una sola vez).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
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

local function slotRow(parent: Instance, items: { any }, max: number, order: number, onClick: ((any) -> ())?): Frame
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 132),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8) })
	for i = 1, max do
		local s = items[i]
		if s then
			local b = Inventory.card(row, s, nil, false)
			b.LayoutOrder = i
			if onClick then
				b.Activated:Connect(function()
					onClick(s)
				end)
			end
		else
			Kit.new("Frame", {
				BackgroundColor3 = Theme.white,
				BackgroundTransparency = 0.4,
				Size = UDim2.fromOffset(104, 128),
				LayoutOrder = i,
				Parent = row,
			}, {
				Kit.corner(14),
				Kit.stroke(Theme.lav2, 2),
				Kit.text("Vacío", 12, {
					TextColor3 = Theme.muted,
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
			})
		end
	end
	return row
end

local function pickerGrid(
	parent: Instance,
	d: any,
	chosen: { string },
	max: number,
	onToggle: (string) -> (),
	size: UDim2,
	pos: UDim2
)
	local sc = Modal.scroll(parent, { Size = size, Position = pos })
	Kit.grid(UDim2.fromOffset(104, 128), 6).Parent = sc
	local avail = {}
	for _, s in d.inventory do
		if s.id ~= d.equipped then
			table.insert(avail, s)
		end
	end
	table.sort(avail, function(a, b)
		return a.value > b.value
	end)
	if #avail == 0 then
		Kit.text(
			"No tienes squishies para ofrecer (el equipado se queda contigo).",
			13,
			{ TextColor3 = Theme.muted, Size = UDim2.fromOffset(300, 50), Parent = sc }
		)
	end
	for i, s in avail do
		local b = Inventory.card(sc, s, d, table.find(chosen, s.id) ~= nil)
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

-- ─────────────── NPC ───────────────
local function openNpc(npcName: any)
	local res = State.request("npcTrade", { op = "open", npc = npcName })
	if not res.ok then
		if res.err then
			Toast.show(res.err)
		end
		return
	end
	local st = res
	local mine: { string } = {}
	local content = Modal.open("trade", "Intercambio con " .. tostring(npcName), {
		width = 900,
		height = 600,
		onClose = function()
			State.request("npcTrade", { op = "close" })
		end,
	})
	local msg = "Elige lo que quieres ofrecer."
	local function render()
		local d = State.data
		if Modal.current ~= "trade" or not d then
			return
		end
		Kit.clear(content)
		local left: Frame = Kit.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(0, 470, 1, 0), Parent = content },
			{ Kit.list(Enum.FillDirection.Vertical, 6) }
		)
		Kit.text(msg, 14, { Font = Theme.bodyBlack, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), Parent = left })
		Kit.text(
			"Tu oferta " .. (if st.myVal > 0 then Format.int(st.myVal) .. " 🪙" else ""),
			14,
			{ Font = Theme.display, LayoutOrder = 2, Parent = left }
		)
		local mineItems = {}
		for _, id in mine do
			for _, s in d.inventory do
				if s.id == id then
					table.insert(mineItems, s)
				end
			end
		end
		slotRow(left, mineItems, 3, 3, function(s)
			table.remove(mine, table.find(mine, s.id) or 0)
			st = State.request("npcTrade", { op = "set", ids = mine })
			render()
		end)
		Kit.text(
			tostring(npcName) .. " ofrece " .. (if st.theirVal > 0 then Format.int(st.theirVal) .. " 🪙" else ""),
			14,
			{ Font = Theme.display, LayoutOrder = 4, Parent = left }
		)
		slotRow(left, if st.theirs then { st.theirs } else {}, 1, 5)
		-- medidor
		local ratio = if st.theirVal > 0 then st.myVal / st.theirVal else 0
		local bar: Frame = Kit.new(
			"Frame",
			{ BackgroundColor3 = Theme.lav, Size = UDim2.new(1, -10, 0, 12), LayoutOrder = 6, Parent = left },
			{ Kit.corner(6) }
		)
		Kit.new("Frame", {
			BackgroundColor3 = if ratio >= 1.15
				then Color3.fromHex("#FFC83A")
				elseif ratio >= 0.8 then Theme.mint
				else Color3.fromHex("#ff9aa8"),
			Size = UDim2.fromScale(math.clamp(ratio / 1.5, 0, 1), 1),
			Parent = bar,
		}, { Kit.corner(6) })
		Kit.text(
			if st.theirVal <= 0
				then ""
				elseif ratio >= 1.15 then "Súper trato para ellos: van a decir que sí."
				elseif ratio >= 0.8 then "Cambio justo: seguramente aceptan."
				else "Quieren más. Agrega otro squishy.",
			13,
			{ TextColor3 = Theme.muted, LayoutOrder = 7, Parent = left }
		)
		local btns: Frame = Kit.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 8, Parent = left },
			{ Kit.list(Enum.FillDirection.Horizontal, 8) }
		)
		local reroll = Kit.button(
			string.format("¿Y otro? (%d)", 3 - st.rerolls),
			Theme.white,
			{ Size = UDim2.new(0.5, -4, 1, 0), Parent = btns }
		)
		local accept = Kit.button("Proponer cambio", Theme.mint, { Size = UDim2.new(0.5, -4, 1, 0), Parent = btns })
		Kit.setEnabled(reroll, #mine > 0 and st.rerolls < 3)
		Kit.setEnabled(accept, #mine > 0 and st.theirs ~= nil)
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
		pickerGrid(content, d, mine, 3, function(id)
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
		end, UDim2.new(1, -490, 1, 0), UDim2.fromOffset(490, 0))
	end
	render()
end

-- ─────────────── Jugador ↔ jugador ───────────────
local room: any = nil
local myIds: { string } = {}

local function renderRoom()
	local d = State.data
	if not room or not d then
		return
	end
	if Modal.current ~= "tradeRoom" then
		return
	end
	local content = Trade.roomContent
	Kit.clear(content)
	local left: Frame = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(0, 470, 1, 0), Parent = content },
		{ Kit.list(Enum.FillDirection.Vertical, 6) }
	)
	local function total(items: { any }): number
		local v = 0
		for _, s in items do
			v += s.value
		end
		return v
	end
	Kit.text(
		string.format(
			"Tú ofreces · %s 🪙 %s",
			Format.int(total(room.me.items)),
			if room.me.confirmed then "✅" elseif room.me.ready then "👍" else ""
		),
		14,
		{ Font = Theme.display, LayoutOrder = 1, Parent = left }
	)
	slotRow(left, room.me.items, 4, 2)
	Kit.text(
		string.format(
			"%s ofrece · %s 🪙 %s",
			room.them.name,
			Format.int(total(room.them.items)),
			if room.them.confirmed then "✅" elseif room.them.ready then "👍" else ""
		),
		14,
		{ Font = Theme.display, LayoutOrder = 3, Parent = left }
	)
	slotRow(left, room.them.items, 4, 4)
	local btns: Frame = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 5, Parent = left },
		{ Kit.list(Enum.FillDirection.Horizontal, 8) }
	)
	if room.phase == "confirm" then
		Kit.text(
			"Revisen bien: al confirmar los dos, el cambio es definitivo.",
			13,
			{ TextColor3 = Theme.pinkD, LayoutOrder = 6, Parent = left }
		)
		local c = Kit.button(
			if room.me.confirmed then "Esperando…" else "✅ Confirmar",
			Theme.mint,
			{ Size = UDim2.new(0.5, -4, 1, 0), Parent = btns }
		)
		Kit.setEnabled(c, not room.me.confirmed)
		c.Activated:Connect(function()
			State.request("trade", { op = "confirm" })
		end)
	else
		local r = Kit.button(
			if room.me.ready then "Quitar listo" else "👍 Listo",
			Theme.mint,
			{ Size = UDim2.new(0.5, -4, 1, 0), Parent = btns }
		)
		r.Activated:Connect(function()
			State.request("trade", { op = "ready", v = not room.me.ready })
		end)
	end
	local cancel = Kit.button("Cancelar", Theme.white, { Size = UDim2.new(0.5, -4, 1, 0), Parent = btns })
	cancel.Activated:Connect(function()
		State.request("trade", { op = "cancel" })
	end)
	pickerGrid(content, d, myIds, 6, function(id)
		local at = table.find(myIds, id)
		if at then
			table.remove(myIds, at)
		else
			table.insert(myIds, id)
		end
		State.request("trade", { op = "set", ids = myIds })
	end, UDim2.new(1, -490, 1, 0), UDim2.fromOffset(490, 0))
end

local function openPlayers()
	local content = Modal.open("tradePlayers", "Cambiar con jugadores", { width = 520, height = 480 })
	local sc = Modal.scroll(content)
	Kit.list(Enum.FillDirection.Vertical, 8).Parent = sc
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			others += 1
			local b = Kit.button(
				"🤝  " .. p.DisplayName .. "  <font color='#6d7285'>@" .. p.Name .. "</font>",
				Theme.white,
				{ Size = UDim2.new(1, -8, 0, 46), Parent = sc }
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
			"No hay otros jugadores en este servidor. ¡Invita a tus amigos! (o cambia con los NPCs de la Plaza de Intercambio)",
			14,
			{ TextColor3 = Theme.muted, Size = UDim2.new(1, 0, 0, 60), Parent = sc }
		)
	end
end

local function incomingRequest(from: number, name: string)
	Audio.play("npc")
	local card: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -60),
		Size = UDim2.fromOffset(320, 110),
		Parent = Kit.root(),
	}, { Kit.corner(18), Kit.stroke(Theme.blue, 3), Kit.pad(12, 10) })
	Kit.text(
		string.format("<b>%s</b> quiere intercambiar contigo 🤝", name),
		15,
		{ Size = UDim2.new(1, 0, 0, 44), Parent = card }
	)
	local yes = Kit.button(
		"Aceptar",
		Theme.mint,
		{ Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(0.5, -4, 0, 40), Parent = card }
	)
	local no = Kit.button(
		"No",
		Theme.white,
		{ Position = UDim2.new(0.5, 4, 1, -40), Size = UDim2.new(0.5, -4, 0, 40), Parent = card }
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
	Router.register("npcTrade", openNpc)
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
				Trade.roomContent = Modal.open("tradeRoom", "Intercambio con " .. ev.them.name, {
					width = 900,
					height = 620,
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
