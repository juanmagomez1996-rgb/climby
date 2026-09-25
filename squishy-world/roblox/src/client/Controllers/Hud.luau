--!strict
-- HUD: logo, monedas, nivel + barra de XP, menú lateral, tarjeta de misión, barra de ayuda,
-- temporizador de Poción de Suerte. Fiel a #hud de template.html.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Quests = require(Shared.Logic.Quests)
local Squishy = require(Shared.Logic.Squishy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Hud = {}

local function pill(parent: Instance, order: number, width: number): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		Size = UDim2.fromOffset(width, 40),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(20), Kit.stroke(Theme.lav2, 2) })
end

function Hud.init()
	local root = Kit.root()
	local frame: Frame = Kit.new("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Hud.frame = frame

	-- barra de arriba
	local top: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28, 0, 44),
		Parent = frame,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10) })
	Kit.text("Squishy World", 30, {
		Font = Theme.display,
		TextColor3 = Theme.pinkD,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = 1,
		Parent = top,
	})
	local coinPill = pill(top, 2, 150)
	Kit.text("🪙", 22, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(28, 28), Parent = coinPill })
	local coins = Kit.text("0", 20, {
		Font = Theme.display,
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -48, 0, 28),
		Parent = coinPill,
	})
	local lvlPill = pill(top, 3, 210)
	local lvl = Kit.text("Nv 1", 18, {
		Font = Theme.display,
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.fromOffset(60, 22),
		Parent = lvlPill,
	})
	local xpTxt = Kit.text("0/50 XP", 12, {
		Position = UDim2.fromOffset(76, 4),
		Size = UDim2.new(1, -86, 0, 18),
		TextColor3 = Theme.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = lvlPill,
	})
	local xpBar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 8),
		Parent = lvlPill,
	}, { Kit.corner(4) })
	local xpFill: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.purple,
		Size = UDim2.fromScale(0, 1),
		Parent = xpBar,
	}, { Kit.corner(4) })
	local boostPill = pill(top, 4, 170)
	local boost = Kit.text("", 14, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = boostPill,
	})
	boostPill.Visible = false
	local muteBtn = Kit.button("🔊", Theme.white, { Size = UDim2.fromOffset(40, 40), LayoutOrder = 5, Parent = top })
	muteBtn.Activated:Connect(function()
		Audio.muted = not Audio.muted
		muteBtn.Text = if Audio.muted then "🔇" else "🔊"
		Audio.loop("fillLoop", false)
	end)

	-- menú lateral (Inventario, Colección, Tienda, Cambios, Robux)
	local side: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(86, 440),
		Parent = frame,
	}, { Kit.list(Enum.FillDirection.Vertical, 10) })
	local menu: { { any } } = {
		{ "🎒", "Inventario", "inventory", Theme.pink, "I" },
		{ "📖", "Colección", "index", Theme.purple, "C" },
		{ "🛒", "Tienda", "shop", Theme.yellow, "T" },
		{ "🤝", "Cambios", "tradePlayers", Theme.blue, nil },
		{ "⭐", "Robux", "robux", Theme.robux, nil },
	}
	local sideButtons: { [string]: TextButton } = {}
	for i, m in menu do
		local b = Kit.button(m[1] .. "\n<font size='12'>" .. m[2] .. "</font>", m[4], {
			Size = UDim2.fromOffset(86, 70),
			TextSize = 26,
			LayoutOrder = i,
			Parent = side,
		})
		b.Activated:Connect(function()
			Audio.play("click")
			if Modal.current == m[3] then
				Modal.close()
			else
				Router.open(m[3])
			end
		end)
		sideButtons[m[3]] = b
	end
	Hud.sideButtons = sideButtons
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		for _, m in menu do
			if m[5] and input.KeyCode == (Enum.KeyCode :: any)[m[5]] then
				if Modal.current == m[3] then
					Modal.close()
				else
					Router.open(m[3])
				end
			end
		end
	end)

	-- tarjeta de misión (derecha)
	local quest: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 70),
		Size = UDim2.fromOffset(260, 108),
		Parent = frame,
	}, { Kit.corner(18), Kit.stroke(Theme.lav2, 2), Kit.pad(14, 10) })
	Kit.text("📜 MISIÓN", 12, { TextColor3 = Theme.pinkD, Font = Theme.bodyBlack, Parent = quest })
	local qTitle = Kit.text("", 16, {
		Font = Theme.bodyBlack,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 40),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = quest,
	})
	local qBar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 10),
		Parent = quest,
	}, { Kit.corner(5) })
	local qFill: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.mint,
		Size = UDim2.fromScale(0, 1),
		Parent = qBar,
	}, { Kit.corner(5) })
	local qMeta = Kit.text("", 12, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = Theme.muted,
		Parent = quest,
	})

	-- barra de ayuda (abajo)
	Kit.text(
		"<b>E</b> usar · <b>Mantén clic</b> sobre un squishy para apachurrarlo · <b>I</b> inventario · <b>T</b> tienda",
		13,
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(640, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.ink2,
			TextStrokeColor3 = Theme.white,
			TextStrokeTransparency = 0.3,
			Parent = frame,
		}
	)

	-- mientras hay una ventana abierta se esconde la misión (como el prototipo)
	Modal.onChange(function(key)
		quest.Visible = key == nil
	end)

	local lastCoins: number? = nil
	State.onChange(function(d)
		coins.Text = Format.int(d.coins)
		if lastCoins and d.coins ~= lastCoins then
			local sc = coinPill:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = coinPill })
			sc.Scale = 1.12
			Kit.tween(sc, 0.25, { Scale = 1 })
		end
		lastCoins = d.coins
		lvl.Text = "Nv " .. d.level
		local need = Squishy.xpNeed(d.level)
		xpTxt.Text = string.format("%d/%d XP", d.xp, need)
		xpFill.Size = UDim2.fromScale(math.clamp(d.xp / need, 0, 1), 1)
		local q = Quests.current(d.quest.i)
		local p = math.min(d.quest.p, q.goal)
		qTitle.Text = q.title
		qFill.Size = UDim2.fromScale(p / q.goal, 1)
		qMeta.Text = string.format("%d / %d · Premio: %s monedas", p, q.goal, Format.int(q.reward))
	end)

	-- temporizador de poción + moldes de oro
	task.spawn(function()
		while true do
			local d = State.data
			if d then
				local left = (d.luckLeft or 0) - (os.time() - (d.serverTime or os.time()))
				local parts = {}
				if left > 0 then
					table.insert(parts, string.format("🧪 %d:%02d", left // 60, left % 60))
				end
				if (d.legendFills or 0) > 0 then
					table.insert(parts, "🌟 x" .. d.legendFills)
				end
				if d.passes and d.passes.vip then
					table.insert(parts, "👑 VIP")
				end
				boostPill.Visible = #parts > 0
				boost.Text = table.concat(parts, "  ")
			end
			task.wait(1)
		end
	end)
end

return Hud
