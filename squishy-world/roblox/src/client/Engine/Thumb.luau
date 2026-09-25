--!strict
-- Miniaturas con ViewportFrame (encuadre por medidas del modelo), como Thumbs.get() del prototipo.
local SquishyFactory = require(script.Parent.SquishyFactory)

local Thumb = {}

--- Llena `parent` con un ViewportFrame del squishy. silhouette = "???" del Índice.
function Thumb.make(d: SquishyFactory.BuildData, parent: GuiObject, silhouette: boolean?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Thumb"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(200, 195, 210)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
	local model = SquishyFactory.build({ species = d.species, variant = d.variant, mutation = "normal", size = 1 })
	model:PivotTo(CFrame.new())
	if silhouette then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromHex("#C9C4D8")
				p.Material = Enum.Material.SmoothPlastic
				if p:IsA("MeshPart") then
					(p :: MeshPart).TextureID = ""
				end
			elseif p:IsA("Light") or p:IsA("Sparkles") or p:IsA("Highlight") then
				p:Destroy()
			end
		end
	end
	model.Parent = vf
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local r = math.max(size.X, size.Y, size.Z)
	local dist = r * 2.1
	local focus = cf.Position
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(dist * 0.25, dist * 0.35, -dist), focus)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf
end

return Thumb
