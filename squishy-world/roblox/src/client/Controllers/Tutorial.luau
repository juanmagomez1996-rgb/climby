--!strict
-- Tutorial de 5 pasos (Tut de game5.js) con flecha rosada que guía a la zona.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Toast = require(script.Parent.Parent.UI.Toast)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Tutorial = {}
local guideTarget: Vector3? = nil

local function guideTo(key: string?)
	if not key then
		guideTarget = nil
		return
	end
	local z = (Config.WorldLayout.zones :: any)[key]
	guideTarget = if z then z.center else nil
end
Tutorial.guideTo = guideTo

function Tutorial.init()
	local a = Instance.new("Part")
	a.Name = "GuideArrow"
	a.Shape = Enum.PartType.Ball
	a.Size = Vector3.new(1.6, 1.6, 1.6)
	a.Color = Color3.fromHex("#FF7BB5")
	a.Material = Enum.Material.Neon
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.Transparency = 1
	a.Parent = Workspace
	-- flechita con Beam desde el jugador hasta la zona
	local a0 = Instance.new("Attachment")
	a0.Parent = a
	local beamTarget = Instance.new("Part")
	beamTarget.Anchored = true
	beamTarget.CanCollide = false
	beamTarget.CanQuery = false
	beamTarget.Transparency = 1
	beamTarget.Size = Vector3.one
	beamTarget.Parent = Workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = beamTarget
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromHex("#FF7BB5"))
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureSpeed = 1
	beam.Transparency = NumberSequence.new(0.25)
	beam.Enabled = false
	beam.Parent = a

	RunService.RenderStepped:Connect(function()
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if guideTarget and root then
			local dist = (Vector3.new(guideTarget.X, root.Position.Y, guideTarget.Z) - root.Position).Magnitude
			if dist < 14 then
				beam.Enabled = false
			else
				beam.Enabled = true
				a.Position = root.Position - Vector3.new(0, 2.6, 0)
				beamTarget.Position = guideTarget + Vector3.new(0, 0.4, 0)
			end
		else
			beam.Enabled = false
		end
	end)

	local shown = -1
	State.onChange(function(d)
		if d.tutorial == shown then
			return
		end
		local prev = shown
		shown = d.tutorial
		local s = d.tutorial
		if s == 0 and prev == -1 then
			Toast.show("¡Bienvenido a Squishy World!", true, 3500)
			task.delay(1.2, function()
				Toast.show(
					"Hagamos tu primer squishy. Sigue la flecha rosada hasta las Máquinas. 🖐️ Por el camino, mantén clic sobre los squishies para apachurrarlos.",
					false,
					5500
				)
			end)
			guideTo("machines")
			State.request("tutorial", { step = 1 })
		elseif s == 1 then
			guideTo("machines")
		elseif s == 3 then
			guideTo(nil)
		elseif s == 5 and prev ~= -1 then
			Toast.show("Tu squishy ya te sigue. ¡Mantén clic encima para apachurrarlo!", false, 4500)
			task.delay(2.8, function()
				Toast.show("Las misiones de la derecha dan monedas. ¡A jugar!")
			end)
			guideTo(nil)
		end
	end)
	Router.register("tutorialEquip", function()
		Toast.show("¡Squishy nuevo! Ahora equípalo.", true, 3200)
		task.delay(1.4, function()
			Toast.show("Abre tu Inventario (I) y presiona Equipar.")
		end)
	end)
end

return Tutorial
