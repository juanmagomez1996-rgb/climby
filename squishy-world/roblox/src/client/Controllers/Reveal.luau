--!strict
-- Revelación (showReveal / endReveal de game5.js): "Te salió…", rareza con su color, nombre,
-- badges (nuevo, mutación, viral, valor) y Guardar / Vender. Pantalla negra para el Secreto.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Format = require(Shared.Util.Format)
local Thumb = require(script.Parent.Parent.Engine.Thumb)
local Kit = require(script.Parent.Parent.UI.Kit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Audio = require(script.Parent.Audio)
local Machine = require(script.Parent.Machine)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Reveal = {}
local overlay: Frame? = nil
local spinConn: RBXScriptConnection? = nil

local function close()
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function show(arg: any)
	local d = arg.squishy
	if not d then
		return
	end
	close()
	local r = Catalog.R[d.rarity]
	local tier = Catalog.RTier[d.rarity]
	local secret = d.rarity == "secret"
	local rc = Color3.fromHex(r.color)
	local ov: Frame = Kit.new("Frame", {
		Name = "Reveal",
		BackgroundColor3 = if secret then Color3.fromHex("#07060c") else Color3.fromHex("#FFF6FB"),
		BackgroundTransparency = if secret then 0 else 0.08,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Active = true,
		Parent = Kit.root(),
	})
	overlay = ov
	local col: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 640),
		Parent = ov,
	}, { Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center) })
	Kit.new("UIScale", { Parent = col, Scale = 1 })
	local txtColor = if secret then Theme.white else Theme.ink
	Kit.text("Te salió…", 22, {
		Font = Theme.display,
		TextColor3 = txtColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = col,
	})
	local view: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 340),
		LayoutOrder = 2,
		Parent = col,
	})
	local vf = Thumb.make({ species = d.species, variant = d.variant, mutation = d.mutation }, view)
	local rarity = Kit.text("", 44, {
		Font = Theme.display,
		TextColor3 = rc,
		TextStrokeColor3 = Theme.white,
		TextStrokeTransparency = if secret then 1 else 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 3,
		Parent = col,
	})
	local name = Kit.text("", 24, {
		Font = Theme.display,
		TextColor3 = txtColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		Parent = col,
	})
	local badges: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 5,
		Parent = col,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	local btns: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 56),
		LayoutOrder = 6,
		Visible = false,
		Parent = col,
	}, { Kit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })

	-- giro + aparición del squishy
	local cam = vf.CurrentCamera
	local model = vf:FindFirstChildWhichIsA("Model")
	local t = 0
	if model and cam then
		local base = model:GetPivot()
		model:ScaleTo(0.01)
		spinConn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local grow = math.min(1, t / 0.5)
			local e = 1 - (1 - grow) ^ 3
			model:ScaleTo(math.max(0.01, e * (1 + 0.08 * math.sin(t * 9) * (1 - grow))))
			model:PivotTo(base * CFrame.Angles(0, t * 0.9, 0))
		end)
	end

	if secret then
		Audio.play("secretSting")
	end
	task.delay(if secret then 0.9 else 0.65, function()
		if overlay ~= ov then
			return
		end
		rarity.Text = if secret then "¡SECRETO ENCONTRADO!" else "¡" .. r.name .. "!"
		name.Text = d.name
		local function badge(text: string, color: Color3?)
			Kit.text(text, 13, {
				BackgroundTransparency = 0,
				BackgroundColor3 = color or Theme.paper,
				TextColor3 = if color then Theme.white else Theme.ink,
				Font = Theme.bodyBlack,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = badges,
			}).Parent =
				badges
		end
		if arg.isNew then
			badge("¡Squishy nuevo descubierto!", Theme.pinkD)
		end
		if d.mutation ~= "normal" and Catalog.MUT[d.mutation] then
			badge(Catalog.MUT[d.mutation].name, Theme.purple)
		end
		if Catalog.SP[d.species] and Catalog.SP[d.species].famous then
			badge("✨ Viral", Theme.yellowD)
		end
		badge(string.format("Vale %s monedas", Format.int(d.value)))
		for _, ch in badges:GetChildren() do
			if ch:IsA("TextLabel") then
				Kit.pad(10, 3).Parent = ch
				Kit.corner(10).Parent = ch
			end
		end

		local data = State.data
		local full = data and #data.inventory >= (data.capacity or 20)
		local keep =
			Kit.button("Guardar", Theme.mint, { Size = UDim2.fromOffset(190, 52), TextSize = 20, Parent = btns })
		local sell = Kit.button("Vender +" .. Format.int(d.value), Theme.yellow, {
			Size = UDim2.fromOffset(190, 52),
			TextSize = 20,
			Parent = btns,
		})
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
				if k and st and st.tutorial == 4 then
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
		elseif tier >= 4 then
			Audio.play("fanfare")
		end
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
