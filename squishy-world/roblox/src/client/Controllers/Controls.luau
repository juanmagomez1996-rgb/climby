--!strict
-- Movimiento y cámara como el original (game1.js CONFIG.PLAYER / CONFIG.CAM):
-- caminar 13, Shift = correr 22, sin salto; cámara FOV 58, distancia 14 (zoom 7–24).
-- Velocidad base, salto y zoom min/max están en default.project.json (StarterPlayer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Controls = {}

local P = Config.Game.PLAYER
local C = Config.Game.CAM
local FOV = 58

local running = false

local function humanoid(): Humanoid?
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local h = humanoid()
	if h then
		h.WalkSpeed = if running then P.run else P.walk
	end
end

local function onCharacter(char: Model)
	local h = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not h then
		return
	end
	h.UseJumpPower = false
	h.JumpHeight = 0
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	applySpeed()
	-- empezar a la distancia del original (14): forzar el zoom un instante
	local lp = Players.LocalPlayer
	lp.CameraMinZoomDistance = C.dist
	lp.CameraMaxZoomDistance = C.dist
	task.delay(0.2, function()
		lp.CameraMinZoomDistance = C.min
		lp.CameraMaxZoomDistance = C.max
	end)
end

function Controls.init()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = FOV
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Workspace.CurrentCamera then
			Workspace.CurrentCamera.FieldOfView = FOV
		end
	end)
	local lp = Players.LocalPlayer
	if lp.Character then
		task.spawn(onCharacter, lp.Character)
	end
	lp.CharacterAdded:Connect(onCharacter)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			running = true
			applySpeed()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			running = false
			applySpeed()
		end
	end)
end

return Controls
