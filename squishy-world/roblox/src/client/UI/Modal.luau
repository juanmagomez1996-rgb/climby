--!strict
-- Ventanas (overlays) del prototipo: una a la vez, con título y botón de cerrar.
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Modal = {}
Modal.current = nil :: string?

local frame: Frame? = nil
local onCloseFn: (() -> ())? = nil
local changed: { (string?) -> () } = {}

function Modal.onChange(fn: (string?) -> ())
	table.insert(changed, fn)
end

function Modal.close()
	if frame then
		frame:Destroy()
		frame = nil
	end
	local cb = onCloseFn
	onCloseFn = nil
	Modal.current = nil
	if cb then
		cb()
	end
	for _, fn in changed do
		task.spawn(fn, nil)
	end
end

export type Opts = { width: number?, height: number?, anchor: Vector2?, position: UDim2?, onClose: (() -> ())? }

--- Abre una ventana y devuelve el contenedor de contenido (con scroll opcional por el llamador).
function Modal.open(key: string, title: string, opts: Opts?): (Frame, TextLabel)
	Modal.close()
	local o: Opts = opts or {}
	local w, h = o.width or 760, o.height or 520
	local f: Frame = Kit.new("Frame", {
		Name = "Modal_" .. key,
		AnchorPoint = o.anchor or Vector2.new(0.5, 0.5),
		Position = o.position or UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Theme.paper,
		ZIndex = 20,
		Parent = Kit.root(),
	}, {
		Kit.corner(22),
		Kit.stroke(Theme.lav2, 3),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(w, h) }),
	})
	-- en pantallas chicas (celular) que no se salga
	local scaler = Instance.new("UIScale")
	scaler.Parent = f
	local function fit()
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scaler.Scale = math.min(1, (vp.X - 20) / w, (vp.Y - 60) / h)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local titleLabel: TextLabel = Kit.text(title, 28, {
		Font = Theme.display,
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -80, 0, 34),
		ZIndex = 21,
		Parent = f,
	})
	local x = Kit.button("✕", Theme.white, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(38, 38),
		TextSize = 18,
		ZIndex = 22,
		Parent = f,
	})
	x.Activated:Connect(Modal.close)
	local content: Frame = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 1, -72),
		ZIndex = 21,
		Parent = f,
	})
	frame = f
	onCloseFn = o.onClose
	Modal.current = key
	for _, fn in changed do
		task.spawn(fn, key)
	end
	return content, titleLabel
end

--- Contenedor con scroll vertical automático.
function Modal.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.lav2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 21,
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("ScrollingFrame", p)
end

return Modal
