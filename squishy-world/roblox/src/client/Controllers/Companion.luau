--!strict
-- Compañeros: el squishy equipado de CADA jugador y de cada NPC lo sigue con saltito y
-- respiración (squash idle). El servidor solo publica el atributo "Companion" (JSON); cada
-- cliente lo dibuja localmente (barato y suave, sin replicar CFrames).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Damp = require(ReplicatedStorage.Shared.Util.Damp)
local SquishyFactory = require(script.Parent.Parent.Engine.SquishyFactory)

local Companion = {}

type Entry = {
	owner: Instance, -- Player o Model (NPC)
	json: string,
	model: Model,
	pos: Vector3,
	yaw: number,
	t: number,
	height: number,
	lift: number, -- distancia del pivote a la base del modelo
	ownerName: string,
	npc: string?,
}

local entries: { [Instance]: Entry } = {}
local folder: Folder

local OFFSET = Config.Game.COMPANION.offset
local LERP = Config.Game.COMPANION.lerp

local function ownerRoot(owner: Instance): BasePart?
	local char: Instance? = if owner:IsA("Player") then owner.Character else owner
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function build(owner: Instance, json: string)
	local old = entries[owner]
	if old then
		old.model:Destroy()
		entries[owner] = nil
	end
	if json == "" then
		return
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(d) ~= "table" then
		return
	end
	local model = SquishyFactory.build(d)
	model:SetAttribute("CompanionName", d.name)
	model:SetAttribute("OwnerName", if owner:IsA("Player") then owner.DisplayName else owner.Name)
	if not owner:IsA("Player") then
		model:SetAttribute("NpcOwner", owner.Name)
	end
	model.Parent = folder
	local root = ownerRoot(owner)
	local start = if root then root.Position else Vector3.zero
	entries[owner] = {
		owner = owner,
		json = json,
		model = model,
		pos = start,
		yaw = 0,
		t = math.random() * 10,
		height = SquishyFactory.height(model),
		lift = (function()
			local cf, size = model:GetBoundingBox()
			return model:GetPivot().Y - (cf.Y - size.Y / 2)
		end)(),
		ownerName = model:GetAttribute("OwnerName") :: string,
		npc = if owner:IsA("Player") then nil else owner.Name,
	}
end

local function watch(owner: Instance)
	local function refresh()
		local v = owner:GetAttribute("Companion")
		build(owner, if type(v) == "string" then v else "")
	end
	owner:GetAttributeChangedSignal("Companion"):Connect(refresh)
	refresh()
end

--- Squishy que alguien está apachurrando: se queda quieto (lo pone Squish.luau).
Companion.frozen = nil :: Model?

function Companion.all(): { [Instance]: Entry }
	return entries
end

function Companion.init()
	folder = Instance.new("Folder")
	folder.Name = "Companions"
	folder.Parent = Workspace

	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		build(p, "")
	end)
	local npcs = Workspace:WaitForChild("NPCs", 30)
	if npcs then
		for _, m in npcs:GetChildren() do
			watch(m)
		end
		npcs.ChildAdded:Connect(watch)
		npcs.ChildRemoved:Connect(function(m)
			build(m, "")
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		for owner, e in entries do
			local root = ownerRoot(owner)
			if root and e.model.Parent then
				e.t += dt
				if Companion.frozen ~= e.model then
					local back = root.CFrame * CFrame.new(OFFSET * 0.55, 0, OFFSET)
					local target = Vector3.new(back.X, root.Position.Y - 3, back.Z)
					local moving = (target - e.pos).Magnitude > 0.4
					e.pos = Damp.vector(e.pos, target, LERP, dt)
					local _, ry, _ = root.CFrame:ToOrientation()
					e.yaw = Damp.number(e.yaw, ry, 6, dt)
					local hop = if moving then math.abs(math.sin(e.t * 9)) * 0.45 else 0
					local breathe = 1 + math.sin(e.t * 2.4) * 0.03
					e.model:PivotTo(
						CFrame.new(e.pos + Vector3.new(0, e.lift * breathe + hop, 0)) * CFrame.Angles(0, e.yaw, 0)
					)
				end
			end
		end
	end)
end

return Companion
