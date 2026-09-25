--!strict
-- Apachurrar en el mundo — versión mínima (Opción C de ROBLOX_ARCHITECTURE §6): mantener clic
-- (o el dedo) sobre cualquier squishy a < 34 studs lo aplasta (squash & stretch) y al soltar sube
-- lento con la recuperación de 2 fases de SYSTEMS_SPEC §7 (tauS = rise/3). El dueño se detiene.
-- Los brazos de tu avatar R15 lo agarran (AvatarHands.luau). La física de espuma completa con
-- EditableMesh es la Fase 7.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Damp = require(Shared.Util.Damp)
local Modal = require(script.Parent.Parent.UI.Modal)
local Audio = require(script.Parent.Audio)
local AvatarHands = require(script.Parent.AvatarHands)
local Companion = require(script.Parent.Companion)
local State = require(script.Parent.State)

local Squish = {}

local RANGE = 34

type Target = {
	model: Model,
	offsets: { [BasePart]: { cf: CFrame, size: Vector3 } },
	pivotToBottom: number,
	basePivot: CFrame, -- pivote al empezar (Body se mueve al aplastar; no releer GetPivot)
	f: number, -- fase rápida
	s: number, -- fase lenta
	target: number,
	held: boolean,
	rise: number,
	soft: number,
}

local active: Target? = nil

local function riseOf(model: Model): (number, number)
	local sp = Catalog.SP[string.gsub(model.Name, "^Squishy_", "")]
	local rise = if sp and sp.rise then sp.rise else 3.2
	local soft = if sp and sp.soft then sp.soft else 1
	return rise, soft
end

local function capture(model: Model): Target
	local pivot = model:GetPivot()
	local offsets = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			offsets[p] = { cf = pivot:ToObjectSpace(p.CFrame), size = p.Size }
		end
	end
	local cf, size = model:GetBoundingBox()
	local rise, soft = riseOf(model)
	return {
		model = model,
		offsets = offsets,
		pivotToBottom = pivot.Y - (cf.Y - size.Y / 2),
		basePivot = pivot,
		f = 0,
		s = 0,
		target = 0,
		held = true,
		rise = rise,
		soft = soft,
	}
end

local function apply(t: Target)
	local k = t.f + t.s
	local sy = 1 - k
	local sxz = 1 + k * 0.62
	local pivot = t.basePivot
	local scale = Vector3.new(sxz, sy, sxz)
	for p, o in t.offsets do
		if p.Parent then
			-- escalar respecto a la base (se desparrama en el piso)
			local rel = o.cf.Position + Vector3.new(0, t.pivotToBottom, 0)
			local newPos = rel * scale - Vector3.new(0, t.pivotToBottom, 0)
			p.CFrame = pivot * (CFrame.new(newPos) * o.cf.Rotation)
			p.Size = o.size * scale
		end
	end
end

local function restore(t: Target)
	local pivot = t.basePivot
	for p, o in t.offsets do
		if p.Parent then
			p.CFrame = pivot * o.cf
			p.Size = o.size
		end
	end
end

local function pick(pos: Vector2): Model?
	local cam = Workspace.CurrentCamera
	local folder = Workspace:FindFirstChild("Companions")
	if not cam or not folder then
		return nil
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit then
		return nil
	end
	local m = hit.Instance:FindFirstAncestorWhichIsA("Model")
	while m and not m:GetAttribute("Squishy") do
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	if not m then
		return nil
	end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (m:GetPivot().Position - root.Position).Magnitude > RANGE then
		return nil
	end
	return m
end

local function press(pos: Vector2)
	if Modal.current then
		return
	end
	local m = pick(pos)
	if not m then
		return
	end
	if active and active.model ~= m then
		restore(active)
	end
	if not active or active.model ~= m then
		active = capture(m)
	end
	local t = active :: Target
	t.held = true
	Companion.frozen = m
	AvatarHands.grab(m)
	Audio.play(if t.soft >= 1.1 then "squish2" else "squish", 0.9 + math.random() * 0.2)
	task.spawn(State.request, "squish")
	local npc = m:GetAttribute("NpcOwner")
	if npc then
		task.spawn(State.request, "npcSquished", { npc = npc })
	end
end

local function releaseAll()
	AvatarHands.release()
	local t = active
	if t and t.held then
		t.held = false
		-- rebote al soltar si estaba muy hundido
		local depth = t.f + t.s
		if depth > 0.25 * 0.45 then
			t.f -= 0.1 * (depth / 0.45) * math.clamp(2.6 / t.rise, 0.25, 1.3)
		end
	end
end

function Squish.init()
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			press(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			releaseAll()
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local t = active
		AvatarHands.update(dt, if t then t.f + t.s else 0)
		if not t then
			return
		end
		if not t.model.Parent then
			active = nil
			Companion.frozen = nil
			return
		end
		local max = math.min(0.45, 0.3 * t.soft + 0.1)
		if t.held then
			-- rigidez progresiva: se hunde rápido al principio y cada vez cuesta más
			t.target += dt * max * (2.8 * 0.6 * (1 - t.target / max) ^ 1.25 + 0.05)
			t.target = math.min(t.target, max)
			local depth = Damp.number(t.f + t.s, t.target, 14, dt)
			t.f = 0.35 * depth
			t.s = 0.65 * depth
		else
			t.target = 0
			local tauS = math.max(0.15, t.rise / 3)
			local tauF = 0.05 + t.rise * 0.02
			t.f -= t.f * math.min(1, dt / tauF)
			t.s -= t.s * math.min(1, dt / tauS)
			if math.abs(t.f + t.s) <= 0.002 then
				restore(t)
				active = nil
				Companion.frozen = nil
				return
			end
		end
		apply(t)
	end)
end

return Squish
