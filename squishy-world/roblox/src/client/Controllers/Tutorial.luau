--!strict
-- Tutorial de 5 pasos (Tut de game5.js) + marcador de guía (chevron rosado que gira y flota
-- sobre el objetivo + flecha en el piso que orbita al jugador apuntando al objetivo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Quests = require(ReplicatedStorage.Shared.Logic.Quests)
local Toast = require(script.Parent.Parent.UI.Toast)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Tutorial = {}
local L = Config.WorldLayout
local PINK = Color3.fromHex("#FF7BB5")

local guide: { key: string?, target: Vector3? } = { key = nil, target = nil }

-- zoneTarget(key) del original
local function zoneTarget(key: string): Vector3?
	if key == "machines" then
		local m = L.machines[1].pos
		return Vector3.new(m.X, 13, m.Z)
	elseif key == "shop" then
		return Vector3.new(L.shopCounter.X, 9, L.shopCounter.Z)
	elseif key == "trading" then
		local z = L.zones.trading.center
		return Vector3.new(z.X, 10, z.Z)
	elseif key == "collection" then
		return Vector3.new(0, 12, -76.9)
	end
	return nil
end

function Tutorial.guideTo(key: string?, msg: string?)
	guide.key = key
	guide.target = if key then zoneTarget(key) else nil
	if msg then
		Toast.show(msg)
	end
end

-- Punta de flecha "V" hecha con dos barras (2D, sin glifos): apunta hacia abajo de su contenedor.
local function chevronGui(parent: GuiObject, thickness: number)
	for side = -1, 1, 2 do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = PINK
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5 + side * 0.18, 0.45)
		bar.Size = UDim2.new(0.62, 0, 0, thickness)
		bar.Rotation = if side < 0 then 50 else -50
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = bar
		bar.Parent = parent
	end
end

function Tutorial.init()
	local folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = Workspace
	local function anchorPart(name: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 0.1, 1)
		p.Parent = folder
		return p
	end
	-- chevron sobre el objetivo (sube y baja)
	local chev = anchorPart("Chevron")
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(3.2, 3.2)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = chev
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bb
	chevronGui(holder, 16)
	-- flecha en el piso que orbita al jugador apuntando al objetivo
	local arrowPart = anchorPart("GroundArrow")
	arrowPart.Size = Vector3.new(2.2, 0.1, 2.2)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.LightInfluence = 0
	sg.CanvasSize = Vector2.new(200, 200)
	sg.Enabled = false
	sg.Parent = arrowPart
	local ah = Instance.new("Frame")
	ah.BackgroundTransparency = 1
	ah.Size = UDim2.fromScale(1, 1)
	ah.Rotation = 180 -- la "V" apunta hacia el frente de la parte
	ah.Parent = sg
	chevronGui(ah, 30)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local tg = guide.target
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not tg or not root then
			bb.Enabled = false
			sg.Enabled = false
			return
		end
		local p = root.Position
		local d = Vector2.new(p.X - tg.X, p.Z - tg.Z).Magnitude
		if d < 12 and guide.key ~= "machines" then
			guide.target = nil
			guide.key = nil
			return
		end
		chev.CFrame = CFrame.new(tg.X, tg.Y + math.sin(t * 3) * 0.8, tg.Z)
		bb.Enabled = true
		sg.Enabled = d > 14
		if d > 14 then
			local yaw = math.atan2(tg.X - p.X, tg.Z - p.Z)
			local fwd = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
			local pos = Vector3.new(p.X, p.Y - 2.8, p.Z) + fwd * (4.2 + math.sin(t * 5) * 0.4)
			arrowPart.CFrame = CFrame.lookAt(pos, pos + fwd)
		end
	end)

	local shown = -1
	local startPos = L.spawn
	State.onChange(function(d)
		if d.tutorial == shown then
			return
		end
		local prev = shown
		shown = d.tutorial
		local s = d.tutorial
		if prev == -1 then
			if s == 0 then
				Toast.show("¡Bienvenido a Squishy World!", true, 3500)
				task.delay(1.2, function()
					Toast.show(
						"Hagamos tu primer squishy. Sigue la flecha rosada hasta las Máquinas. 🖐️ Por el camino, mantén clic sobre los squishies de la Vitrina Viral para apachurrarlos.",
						false,
						5500
					)
				end)
				Tutorial.guideTo("machines")
			else
				Toast.show("¡Bienvenido de vuelta a Squishy World!", true)
				local q = Quests.current(d.quest.i)
				if q.target and s < 5 then
					Tutorial.guideTo("machines")
				end
			end
			return
		end
		if s == 1 then
			Tutorial.guideTo("machines")
		elseif s == 3 then
			guide.target = nil
		elseif s == 5 then
			Toast.show("Tu squishy ya te sigue. ¡Mantén clic encima para apachurrarlo!", false, 4500)
			task.delay(2.8, function()
				Toast.show("Las misiones de la derecha dan monedas. ¡A jugar!")
			end)
			guide.target = nil
		end
	end)
	-- paso 0 → 1 cuando el jugador se mueve más de 4 del inicio
	task.spawn(function()
		while true do
			task.wait(0.5)
			local d = State.data
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if d and d.tutorial == 0 and root then
				local p = root.Position
				if Vector2.new(p.X - startPos.X, p.Z - startPos.Z).Magnitude > 4 then
					State.request("tutorial", { step = 1 })
				end
			elseif d and d.tutorial > 0 then
				break
			end
		end
	end)
	Router.register("tutorialEquip", function()
		Toast.show("¡Squishy nuevo! Ahora equípalo.", true, 3200)
		task.delay(1.4, function()
			Toast.show("Abre tu Inventario (I) y presiona Equipar.")
		end)
		Router.open("hudPulse", { key = "inventory", on = true })
	end)
end

return Tutorial
