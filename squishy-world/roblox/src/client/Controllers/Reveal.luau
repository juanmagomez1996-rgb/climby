--!strict
-- Revelación (#reveal + showReveal / updateReveal / spawnRevealFx de game5.js):
-- fondo oscuro radial por rareza, "Te salió…", el squishy aparece 0→1.15→1 a los 0.55 s y se
-- mece (sin(t·0.9)·0.5), rareza en Lilita 64 con pop, glitch + pantallazo negro en el Secreto,
-- badges, partículas por rareza y Guardar / Vender.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Format = require(Shared.Util.Format)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Audio)
local Machine = require(script.Parent.Machine)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Reveal = {}
Reveal.open = false
local overlay: Frame? = nil
local conns: { RBXScriptConnection } = {}

-- radial-gradient(circle at 50% 45%, centro, borde) de template.html
local BG: { [string]: { Color3 | number } } = {
	base = { Color3.fromRGB(40, 45, 58), 0.65, Color3.fromRGB(20, 22, 30), 0.18 },
	rare = { Color3.fromRGB(92, 168, 255), 0.55, Color3.fromRGB(15, 25, 50), 0.16 },
	epic = { Color3.fromRGB(180, 92, 255), 0.5, Color3.fromRGB(30, 15, 50), 0.14 },
	legendary = { Color3.fromRGB(255, 214, 90), 0.25, Color3.fromRGB(120, 70, 10), 0.15 },
	secret = { Color3.fromHex("#07060c"), 0, Color3.fromHex("#07060c"), 0 },
}
local FX: { [string]: { n: number, cols: { string } } } = {
	rare = { n = 40, cols = { "#bfe0ff", "#ffffff", "#4C9BFF" } },
	epic = { n = 80, cols = { "#e2c6ff", "#A95CFF", "#ffffff" } },
	legendary = { n = 140, cols = { "#FFC83A", "#FF8FA3", "#8BE3A5", "#8BC7E8", "#ffffff", "#B999E8" } },
	secret = { n = 120, cols = { "#000000", "#ff2a6d", "#05d9e8" } },
}

local function Debris(inst: Instance, t: number)
	task.delay(t, function()
		if inst.Parent then
			inst:Destroy()
		end
	end)
end

local function close()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	Reveal.open = false
end

local function background(parent: Frame, rarity: string)
	local bg = BG[rarity] or BG.base
	local inner, innerT, outer, outerT = bg[1] :: Color3, bg[2] :: number, bg[3] :: Color3, bg[4] :: number
	parent.BackgroundColor3 = outer
	parent.BackgroundTransparency = outerT
	if rarity == "secret" then
		return
	end
	-- aproximación del gradiente radial con círculos concéntricos
	local rings = 7
	for i = rings, 1, -1 do
		local k = i / rings
		Kit.new("Frame", {
			BackgroundColor3 = inner:Lerp(outer, k),
			BackgroundTransparency = 1 - (1 - innerT) * (1 - k) * 0.55 - 0.45 * k,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.35 + 1.2 * k, 0.35 + 1.2 * k),
			Parent = parent,
		}, { Kit.round(), Kit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	end
end

local function particles(parent: Frame, rarity: string)
	local cfg = FX[rarity]
	if not cfg then
		return
	end
	local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local cx, cy = vp.X / 2, vp.Y * 0.45
	local ps = {}
	for i = 1, cfg.n do
		local a = math.random() * math.pi * 2
		local sp = 2 + math.random() * (if rarity == "legendary" then 11 else 6)
		local kind = if rarity == "legendary"
			then (if i % 3 ~= 0 then "confetti" else "star")
			elseif rarity == "secret" then "glitch"
			else "spark"
		local s = 4 + math.random() * 5
		local col = Color3.fromHex(cfg.cols[math.random(1, #cfg.cols)])
		local f: any
		if kind == "star" then
			f = Kit.text("⭐", s * 2, {
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(s * 2, s * 2),
				TextColor3 = col,
				Parent = parent,
			})
		else
			f = Kit.new("Frame", {
				BackgroundColor3 = col,
				BorderSizePixel = 0,
				Size = if kind == "confetti"
					then UDim2.fromOffset(s, s / 2)
					elseif kind == "glitch" then UDim2.fromOffset(s * 2, 3)
					else UDim2.fromOffset(s * 0.7, s * 0.7),
				Parent = parent,
			})
			if kind == "spark" then
				Kit.round().Parent = f
			end
		end
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(ps, {
			f = f,
			x = cx,
			y = cy,
			vx = math.cos(a) * sp,
			vy = math.sin(a) * sp - (if rarity == "legendary" then 5 else 1),
			life = 1.2 + math.random() * 1.4,
			rot = math.random() * 6,
			kind = kind,
		})
	end
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt: number)
			for i = #ps, 1, -1 do
				local p = ps[i]
				p.life -= dt
				if p.life <= 0 then
					p.f:Destroy()
					table.remove(ps, i)
					continue
				end
				p.vy += (if p.kind == "confetti" then 9 else 2) * dt
				p.vx *= 0.99
				p.x += p.vx * 60 * dt
				p.y += p.vy * 60 * dt
				p.rot += dt * 5
				p.f.Position = UDim2.fromOffset(p.x, p.y)
				p.f.Rotation = math.deg(p.rot)
				local alpha = 1 - math.min(1, p.life)
				if p.f:IsA("TextLabel") then
					p.f.TextTransparency = alpha
				else
					p.f.BackgroundTransparency = alpha
				end
			end
		end)
	)
end

local function show(arg: any)
	local d = arg.squishy
	if not d then
		return
	end
	close()
	Reveal.open = true
	local r = Catalog.R[d.rarity]
	local tier = Catalog.RTier[d.rarity]
	local secret = d.rarity == "secret"
	local rc = Color3.fromHex(r.color)
	local root = Kit.root("full")
	local ov: Frame = Kit.new("Frame", {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Parent = root,
	})
	overlay = ov
	background(ov, if tier >= 2 then d.rarity else "base")
	local fxLayer: Frame =
		Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = ov })
	local vpY = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y or 720
	local stage = math.min(420, vpY * 0.6)
	local col: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(640, 0),
		ZIndex = 2,
		Parent = ov,
	}, { Kit.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center) })
	Kit.text("Te salió…", 26, {
		FontFace = Theme.display,
		TextColor3 = Theme.white,
		TextTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = col,
	})
	local view: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(stage, stage),
		LayoutOrder = 2,
		Parent = col,
	})
	local vf = Thumb.make({ species = d.species, variant = d.variant, mutation = d.mutation }, view)
	-- rareza: Lilita 64, color de la rareza, sombra 0 5px 0 rgba(0,0,0,.25), pop
	local rarityHolder: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if vpY < 800 then 58 else 72),
		LayoutOrder = 3,
		Parent = col,
	})
	local rsize = if vpY < 800 then 50 else 64
	local rShadow = Kit.text("", rsize, {
		FontFace = Theme.display,
		TextColor3 = Color3.new(0, 0, 0),
		TextTransparency = 0.75,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		TextWrapped = false,
		Parent = rarityHolder,
	})
	local rarity = Kit.text("", rsize, {
		FontFace = Theme.display,
		TextColor3 = rc,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextWrapped = false,
		Parent = rarityHolder,
	})
	local rScale = Kit.new("UIScale", { Scale = 1, Parent = rarityHolder })
	local name = Kit.text("", 30, {
		FontFace = Theme.display,
		TextColor3 = Theme.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 4,
		Parent = col,
	})
	local badges: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 5,
		Parent = col,
	}, { Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	local btns: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 60),
		LayoutOrder = 6,
		Visible = false,
		Parent = col,
	}, { Kit.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center) })

	-- 0→1.15→1 después del "Te salió…" (0.55 s) + mecerse
	local model = vf:FindFirstChildWhichIsA("Model")
	local t = 0
	if model then
		local base = model:GetPivot()
		model:ScaleTo(0.01)
		table.insert(
			conns,
			RunService.RenderStepped:Connect(function(dt: number)
				t += dt
				local k = math.clamp((t - 0.55) / 0.55, 0, 1)
				local s = if k < 0.6 then 1.15 * (k / 0.6) else 1.15 + (1 - 1.15) * ((k - 0.6) / 0.4)
				model:ScaleTo(math.max(0.01, s))
				model:PivotTo(base * CFrame.Angles(0, math.sin(t * 0.9) * 0.5, 0))
				if d.rarity == "legendary" and vf.CurrentCamera then
					-- zoom 7.4 → 6.2
					vf.CurrentCamera.FieldOfView = 30 - 5 * math.clamp((t - 0.6) / 1.2, 0, 1)
				end
			end)
		)
	end

	if secret then
		-- .blackout: negro 0.9 s (opaco hasta el 55 %) + secretSting
		local black: Frame = Kit.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
			Parent = ov,
		})
		task.delay(0.5, function()
			Kit.tween(black, 0.4, { BackgroundTransparency = 1 })
		end)
		Debris(black, 1)
		Audio.play("secretSting")
	end
	task.delay(if secret then 0.9 else 0.65, function()
		if overlay ~= ov then
			return
		end
		local txt = if secret then "¡SECRETO ENCONTRADO!" else "¡" .. r.name .. "!"
		rarity.Text = txt
		rShadow.Text = txt
		rScale.Scale = 0
		Kit.tween(rScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
		name.Text = d.name
		if secret then
			-- glitch: copias magenta/cian ±3px y saltitos
			local g1 = rarity:Clone()
			g1.TextColor3 = Color3.fromHex("#ff2a6d")
			g1.Parent = rarityHolder
			local g2 = rarity:Clone()
			g2.TextColor3 = Color3.fromHex("#05d9e8")
			g2.Parent = rarityHolder
			rarity.ZIndex = 3
			table.insert(
				conns,
				RunService.Heartbeat:Connect(function()
					local ph = math.floor(os.clock() * 8) % 4
					local dx = if ph == 0 then 3 elseif ph == 2 then -3 else 0
					g1.Position = UDim2.fromOffset(dx, 0)
					g2.Position = UDim2.fromOffset(-dx, 0)
					rarity.Position = UDim2.fromOffset(if ph == 1 then -2 elseif ph == 3 then 2 else 0, 0)
				end)
			)
		end
		-- .badge: blanco con texto ink; .new en amarillo
		local function badge(text: string, new: boolean?)
			Kit.new("TextLabel", {
				BackgroundColor3 = if new then Theme.yellow else Theme.white,
				TextColor3 = Theme.ink,
				FontFace = Theme.bodyBlack,
				TextSize = 13,
				Text = text,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				Parent = badges,
			}, { Kit.corner(10), Kit.pad(10, 0) })
		end
		if arg.isNew then
			badge("¡Squishy nuevo descubierto!", true)
		end
		if d.mutation ~= "normal" and Catalog.MUT[d.mutation] then
			badge(Catalog.MUT[d.mutation].name)
		end
		if Catalog.SP[d.species] and Catalog.SP[d.species].famous then
			badge("✨ Viral")
		end
		badge(string.format("Vale %s monedas", Format.int(d.value)))

		local data = State.data
		local full = data and #data.inventory >= (data.capacity or 20)
		local keep = Kit.button("Guardar", Theme.mint, { Size = UDim2.fromOffset(170, 52), Parent = btns }, "big")
		local sell = Kit.button("Vender +" .. Format.int(d.value), Theme.yellow, {
			Size = UDim2.fromOffset(190, 52),
			Parent = btns,
		}, "big")
		if full then
			Kit.setEnabled(keep, false)
		end
		btns.Visible = true
		local busy = false
		local function decide(k: boolean)
			if busy then
				return
			end
			busy = true
			local res = State.request("reveal", { keep = k })
			busy = false
			if res.ok then
				close()
				Machine.revealDone()
				local st = State.data
				if st and st.tutorial == 4 then
					-- paso 4 del tutorial: cerrar la máquina y pedir que lo equipe
					Modal.close()
					Router.open("tutorialEquip")
				end
			else
				Audio.play("error")
			end
		end
		keep.Activated:Connect(function()
			if full then
				return
			end
			decide(true)
		end)
		sell.Activated:Connect(function()
			decide(false)
		end)

		if tier == 0 then
			Audio.play("reward")
		elseif tier == 1 then
			Audio.play("reward")
			Audio.play("sparkle2")
		elseif tier == 2 then
			Audio.play("rare")
			Audio.play("sparkle")
		elseif tier == 3 then
			Audio.play("epic")
			Audio.play("sparkle")
		elseif tier == 4 then
			Audio.play("fanfare")
		end
		particles(fxLayer, d.rarity)
	end)
end

function Reveal.init()
	Router.register("reveal", show)
	-- si entraste con un squishy pendiente (te fuiste en plena revelación), se muestra de nuevo
	task.spawn(function()
		local d = State.waitReady()
		if d.pending then
			show({ squishy = d.pending, isNew = false })
		end
	end)
end

return Reveal
