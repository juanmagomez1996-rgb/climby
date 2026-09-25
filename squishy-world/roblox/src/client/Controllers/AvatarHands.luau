--!strict
-- Manos de Roblox: cuando apachurras un squishy, los brazos de TU avatar (R15) lo agarran con
-- IKControl. Las manos se pegan a los lados del squishy (vistos desde tu personaje) y se van
-- hundiendo con él. Reemplaza las manitos kawaii del prototipo (pedido de Yeison).
-- Si el squishy está lejos, el personaje camina hasta quedar a la distancia de los brazos.
-- Con avatar R6 (sin IK) se apachurra igual, solo que sin brazos.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AvatarHands = {}

local REACH = 3.2 -- distancia a la que se para frente al squishy

type Rig = {
	left: IKControl,
	right: IKControl,
	tl: Attachment,
	tr: Attachment,
	holder: Part,
	weight: number,
}

local rig: Rig? = nil
local target: Model? = nil
local walking = false

local function character(): (Model?, Humanoid?, BasePart?)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return char, hum, root
end

local function build(char: Model, hum: Humanoid): Rig?
	if hum.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local function part(name: string): BasePart?
		local p = char:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	local lu, lh, ru, rh = part("LeftUpperArm"), part("LeftHand"), part("RightUpperArm"), part("RightHand")
	if not (lu and lh and ru and rh) then
		return nil
	end
	local holder = Instance.new("Part")
	holder.Name = "SquishHandTargets"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.Parent = Workspace
	local tl = Instance.new("Attachment")
	tl.Parent = holder
	local tr = Instance.new("Attachment")
	tr.Parent = holder
	local function ik(chainRoot: BasePart, hand: BasePart, t: Attachment): IKControl
		local c = Instance.new("IKControl")
		c.Type = Enum.IKControlType.Position
		c.ChainRoot = chainRoot
		c.EndEffector = hand
		c.Target = t
		c.Weight = 0
		c.SmoothTime = 0.08
		c.Parent = hum
		return c
	end
	return {
		left = ik(lu, lh, tl),
		right = ik(ru, rh, tr),
		tl = tl,
		tr = tr,
		holder = holder,
		weight = 0,
	}
end

local function destroyRig()
	local r = rig
	if r then
		r.left:Destroy()
		r.right:Destroy()
		r.holder:Destroy()
		rig = nil
	end
end

--- Empieza a agarrar `model`. Si está lejos, camina hasta él.
function AvatarHands.grab(model: Model)
	local char, hum, root = character()
	if not char or not hum or not root then
		return
	end
	target = model
	if not rig or not rig.left.Parent then
		destroyRig()
		rig = build(char, hum)
	end
	local pos = model:GetPivot().Position
	local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	if flat.Magnitude > REACH + 1.2 and not walking then
		walking = true
		hum:MoveTo(pos - flat.Unit * REACH)
		task.spawn(function()
			hum.MoveToFinished:Wait()
			walking = false
		end)
	end
end

function AvatarHands.release()
	target = nil
end

--- k = cuánto está hundido (0..~0.45). Se llama cada frame desde Squish.
function AvatarHands.update(dt: number, k: number)
	local char, hum, root = character()
	local r = rig
	if not r then
		return
	end
	if not char or not hum or not root then
		destroyRig()
		return
	end
	local m = target
	local want = 0
	if m and m.Parent then
		local cf, size = m:GetBoundingBox()
		local toSq = Vector3.new(cf.X - root.Position.X, 0, cf.Z - root.Position.Z)
		local dist = toSq.Magnitude
		if dist < REACH + 2.5 then
			want = 1
			-- mirar al squishy
			if dist > 0.3 and not walking then
				local look = root.Position + toSq.Unit
				root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, look), math.min(1, dt * 10))
			end
			-- lados del squishy vistos desde el personaje; se meten hacia adentro al apretar
			local fwd = if dist > 0.01 then toSq.Unit else root.CFrame.LookVector
			local side = fwd:Cross(Vector3.yAxis).Unit
			local half = math.max(size.X, size.Z) * 0.5 * (1 + k * 0.62)
			local squeeze = half * (0.95 - k * 0.5)
			local y = cf.Y + size.Y * (0.1 - k * 0.3)
			local center = Vector3.new(cf.X, y, cf.Z) - fwd * 0.15
			r.holder.CFrame = CFrame.new(center)
			r.tl.WorldPosition = center + side * squeeze
			r.tr.WorldPosition = center - side * squeeze
		end
	end
	r.weight += (want - r.weight) * math.min(1, dt * 8)
	r.left.Weight = r.weight
	r.right.Weight = r.weight
	if want == 0 and r.weight < 0.02 then
		destroyRig()
	end
end

return AvatarHands
