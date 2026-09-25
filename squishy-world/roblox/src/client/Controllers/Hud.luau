--!strict
-- HUD (#hud de template.html): logo arriba a la izquierda, #stats (monedas, nivel+XP, sonido)
-- arriba a la derecha en píldoras oscuras, #sideMenu con los íconos del juego, #questCard,
-- #helpBar abajo a la izquierda. Teclas: I, C, B, T, Esc (game4.js keydown).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Quests = require(Shared.Logic.Quests)
local Squishy = require(Shared.Logic.Squishy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local Tutorial = require(script.Parent.Tutorial)

local Hud = {}
Hud.sideButtons = {} :: { [string]: any }

local PILL_BG = Theme.ink
local PILL_T = 0.18

local function pill(parent: Instance, order: number): Frame
	return Kit.new("Frame", {
		BackgroundColor3 = PILL_BG,
		BackgroundTransparency = PILL_T,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(16), Kit.pad(14, 8) })
end

--- Anillo rosado que late (.side.pulse) sobre un botón.
function Hud.pulse(key: string, on: boolean)
	local b = Hud.sideButtons[key]
	if not b then
		return
	end
	local old = b:FindFirstChild("_Pulse")
	if old then
		old:Destroy()
	end
	if not on then
		return
	end
	local ring = Kit.new("UIStroke", {
		Name = "_Pulse",
		Color = Theme.pink,
		Thickness = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = b,
	})
	task.spawn(function()
		while ring.Parent do
			ring.Thickness = 0
			ring.Transparency = 0.1
			Kit.tween(ring, 1.1, { Thickness = 10, Transparency = 1 })
			task.wait(1.1)
		end
	end)
end

local function sideAction(key: string)
	if key == "trade" then
		Tutorial.guideTo("trading")
		Toast.show("Sigue la flecha hasta la Plaza de Intercambio")
	elseif key == "tour" then
		Router.open("tour")
	else
		Router.open(key)
	end
end

function Hud.init()
	-- el chat de Roblox va abajo a la derecha (esa esquina está libre en el original)
	pcall(function()
		local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if cfg then
			cfg.HorizontalAlignment = Enum.HorizontalAlignment.Right
			cfg.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end)

	local root = Kit.root()
	local frame: Frame = Kit.new("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Hud.frame = frame

	-- #logo: Lilita 22 blanco con sombra rosada 0 3px 0 #E57AAE
	local logo = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(200, 30),
		Parent = frame,
	})
	Kit.text("Squishy World", 22, {
		FontFace = Theme.display,
		TextColor3 = Theme.pinkD,
		Position = UDim2.fromOffset(0, 3),
		TextWrapped = false,
		Parent = logo,
	})
	Kit.text(
		"Squishy World",
		22,
		{ FontFace = Theme.display, TextColor3 = Theme.white, TextWrapped = false, Parent = logo }
	)

	-- #stats: monedas, nivel, sonido (arriba a la derecha)
	local stats: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(600, 46),
		Parent = frame,
	})
	local sl = Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center
	sl.Parent = stats

	local boostPill = pill(stats, 0)
	local boost = Kit.text("", 15, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.white,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextWrapped = false,
		Parent = boostPill,
	})
	boostPill.Visible = false

	local coinPill = pill(stats, 1)
	local cl = Kit.list(Enum.FillDirection.Horizontal, 8)
	cl.VerticalAlignment = Enum.VerticalAlignment.Center
	cl.Parent = coinPill
	Kit.coin(22, { LayoutOrder = 1, Parent = coinPill })
	local coins = Kit.text("0", 17, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.white,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = coinPill,
	})

	local lvlPill = pill(stats, 2)
	local lvlCol: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(130, 30),
		Parent = lvlPill,
	})
	local lvl = Kit.text("Nivel 1", 14, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.white,
		Size = UDim2.fromOffset(70, 16),
		Parent = lvlCol,
	})
	local xpTxt = Kit.text("0/50 XP", 12, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.white,
		TextTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = lvlCol,
	})
	local xpBar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.white,
		BackgroundTransparency = 0.82,
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 7),
		Parent = lvlCol,
	}, { Kit.corner(5) })
	local xpFill: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.white,
		Size = UDim2.fromScale(0, 1),
		Parent = xpBar,
	}, {
		Kit.corner(5),
		Kit.new("UIGradient", { Color = ColorSequence.new(Theme.mint, Theme.blue) }),
	})

	-- .iconBtn 40x40 🔊/🔇
	local muteBtn = Kit.button(
		"🔊",
		Theme.paper,
		{ Size = UDim2.fromOffset(40, 40), TextSize = 18, LayoutOrder = 3, Parent = stats }
	);
	(muteBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 13)
	muteBtn.Activated:Connect(function()
		Audio.setMuted(not Audio.muted)
	end)
	Audio.onMuted(function(m)
		muteBtn.Text = if m then "🔇" else "🔊"
	end)

	-- #sideMenu: fondo paper igual para todos, ícono 30x30 + etiqueta 11px, atajo en la esquina
	local side: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(74, 480),
		Parent = frame,
	}, { Kit.list(Enum.FillDirection.Vertical, 10) });
	(side:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
	local menu: { { any } } = {
		{ "inv", "Inventario", "inventory", "I", "🎒" },
		{ "col", "Colección", "index", "C", "📖" },
		{ "shop", "Tienda", "shop", "B", "🛒" },
		{ "tour", "Tour", "tour", "🎬", "🎬" },
		{ "trade", "Cambios", "trade", "T", "🤝" },
		{ "", "Robux", "robux", "", "⭐" }, -- extra: monetización (no está en el original)
	}
	for i, m in menu do
		local b = Kit.button("", Theme.paper, { Size = UDim2.fromOffset(74, 70), LayoutOrder = i, Parent = side });
		(b:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 20)
		Kit.shadow(b, Color3.fromRGB(207, 208, 214), 5, 20)
		b.BackgroundTransparency = 0.08
		local iconId = (Config.AssetIds.icons :: any)[m[1]]
		if iconId and iconId ~= "" then
			Kit.new("ImageLabel", {
				BackgroundTransparency = 1,
				Image = iconId,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(30, 30),
				Parent = b,
			})
		else
			Kit.text(m[5], 24, {
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 8),
				Size = UDim2.new(1, 0, 0, 30),
				Parent = b,
			})
		end
		Kit.text(m[2], 11, {
			FontFace = Theme.bodyBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -24),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = b,
		})
		if m[4] ~= "" then
			Kit.text(m[4], 10, {
				FontFace = Theme.bodyBlack,
				TextTransparency = 0.55,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(20, 12),
				Parent = b,
			})
		end
		b.Activated:Connect(function()
			if Modal.current then
				return -- como el original: solo si no hay ventana abierta
			end
			Audio.play("click")
			sideAction(m[3])
		end)
		Hud.sideButtons[m[3]] = b
	end

	Router.register("hudPulse", function(arg)
		Hud.pulse(arg.key, arg.on)
	end)

	-- #questCard (right 16, top 92, ancho 250)
	local quest: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		BackgroundTransparency = 0.07,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 76),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, { Kit.corner(18), Kit.list(Enum.FillDirection.Vertical, 4) })
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 13),
		Parent = quest,
	})
	Kit.shadow(quest, Color3.fromRGB(207, 208, 214), 5, 18)
	Kit.text("Misión", 15, { FontFace = Theme.display, TextColor3 = Theme.purpleD, LayoutOrder = 1, Parent = quest })
	local qTitle = Kit.text("", 15, {
		FontFace = Theme.bodyBlack,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = quest,
	})
	local qBar: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.lav,
		Size = UDim2.new(1, 0, 0, 9),
		LayoutOrder = 3,
		Parent = quest,
	}, { Kit.corner(6) })
	local qFill: Frame = Kit.new(
		"Frame",
		{ BackgroundColor3 = Theme.mint, Size = UDim2.fromScale(0, 1), Parent = qBar },
		{ Kit.corner(6) }
	)
	local meta: Frame =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4, Parent = quest })
	local qProg = Kit.text("", 12, { TextColor3 = Theme.muted, Size = UDim2.fromScale(0.4, 1), Parent = meta })
	local qReward = Kit.text("", 12, {
		TextColor3 = Theme.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.6, 1),
		Parent = meta,
	})
	local guideBtn = Kit.button(
		"Muéstrame",
		Theme.lav,
		{ Size = UDim2.fromOffset(110, 30), LayoutOrder = 5, Parent = quest },
		"small"
	)
	local currentTarget: string? = nil
	guideBtn.Activated:Connect(function()
		if currentTarget then
			Audio.play("click")
			Tutorial.guideTo(currentTarget)
		end
	end)

	-- #helpBar (abajo a la izquierda)
	local help: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		BackgroundTransparency = 0.3,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = frame,
	}, { Kit.corner(10), Kit.pad(10, 5) })
	Kit.text(
		"WASD moverse · Shift correr · Mouse / ← → cámara · E interactuar · Clic sostenido = apachurrar",
		12,
		{
			TextColor3 = Theme.ink,
			TextTransparency = 0.3,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextWrapped = false,
			Parent = help,
		}
	)

	local lastCoins: number? = nil
	State.onChange(function(d)
		coins.Text = Format.int(d.coins)
		if lastCoins and d.coins ~= lastCoins then
			local sc = coinPill:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = coinPill })
			sc.Scale = 1.12
			Kit.tween(sc, 0.35, { Scale = 1 })
		end
		lastCoins = d.coins
		lvl.Text = "Nivel " .. d.level
		local need = Squishy.xpNeed(d.level)
		xpTxt.Text = string.format("%d/%d XP", d.xp, need)
		Kit.tween(xpFill, 0.4, { Size = UDim2.fromScale(math.clamp(d.xp / need, 0, 1), 1) })
		local q = Quests.current(d.quest.i)
		local p = math.min(d.quest.p, q.goal)
		qTitle.Text = q.title
		Kit.tween(qFill, 0.3, { Size = UDim2.fromScale(p / q.goal, 1) })
		qProg.Text = string.format("%d / %d", p, q.goal)
		qReward.Text = string.format("Premio: %s monedas", Format.int(q.reward))
		currentTarget = q.target
		guideBtn.Visible = q.target ~= nil
		if d.muted ~= nil and d.muted ~= Audio.muted then
			Audio.setMuted(d.muted, true)
		end
	end)

	-- teclas del original (solo si no hay ventana abierta); Esc cierra la ventana
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or UserInputService:GetFocusedTextBox() then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Escape then
			if Modal.current and not Modal.blocked() then
				Modal.close()
			end
			return
		end
		if Modal.current then
			return
		end
		if k == Enum.KeyCode.I then
			Router.open("inventory")
		elseif k == Enum.KeyCode.C then
			Router.open("index")
		elseif k == Enum.KeyCode.B then
			Router.open("shop")
		elseif k == Enum.KeyCode.T then
			Tutorial.guideTo("trading")
			Toast.show("Ve a la Plaza de Intercambio")
		end
	end)

	-- Poción de suerte / Molde de Oro / VIP (extra de monetización)
	task.spawn(function()
		while true do
			local d = State.data
			if d then
				local left = (d.luckLeft or 0) - (os.time() - (d.serverTime or os.time()))
				local parts = {}
				if left > 0 then
					table.insert(parts, string.format("🍀 %d:%02d", left // 60, left % 60))
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
