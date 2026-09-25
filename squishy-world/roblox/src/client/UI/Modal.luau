--!strict
-- Ventanas (.overlay + .panel del prototipo): una a la vez, fondo oscurecido con blur (menos el
-- panel de la máquina, que va sin overlay), radius 26, título Lilita 28 y botón cerrar lav "×".
local Lighting = game:GetService("Lighting")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Modal = {}
Modal.current = nil :: string?

local frame: GuiObject? = nil
local shade: Frame? = nil
local blur: BlurEffect? = nil
local fitConn: RBXScriptConnection? = nil
local onCloseFn: (() -> ())? = nil
local changed: { (string?) -> () } = {}

function Modal.onChange(fn: (string?) -> ())
	table.insert(changed, fn)
end

--- Si algo en curso no se puede interrumpir (un intercambio, un llenado), devuelve el motivo.
local guards: { () -> string? } = {}
function Modal.addGuard(fn: () -> string?)
	table.insert(guards, fn)
end
function Modal.blocked(): string?
	for _, g in guards do
		local why = g()
		if why then
			return why
		end
	end
	return nil
end

function Modal.close()
	if fitConn then
		fitConn:Disconnect()
		fitConn = nil
	end
	if frame then
		frame:Destroy()
		frame = nil
	end
	if shade then
		shade:Destroy()
		shade = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
	local cb = onCloseFn
	onCloseFn = nil
	local was = Modal.current
	Modal.current = nil
	if cb then
		cb()
	end
	if was then
		for _, fn in changed do
			task.spawn(fn, nil)
		end
	end
end

export type Opts = {
	width: number?,
	height: number?,
	anchor: Vector2?,
	position: UDim2?,
	onClose: (() -> ())?,
	noOverlay: boolean?,
	titleRight: boolean?,
}

--- Botón cerrar .close: 40x40, radius 13, fondo lav, "×" (el "✕" sale en cuadrito en Roblox).
function Modal.closeButton(parent: Instance, onClick: () -> ()): TextButton
	local x = Kit.button("×", Theme.lav, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(40, 40),
		TextSize = 30,
		FontFace = Theme.bodyBlack,
		Parent = parent,
	})
	Kit.shadow(x, Theme.lav2, 3, 13);
	(x:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 13)
	x.Activated:Connect(onClick)
	return x
end

--- Abre una ventana y devuelve el contenedor de contenido.
function Modal.open(key: string, title: string, opts: Opts?): (Frame, TextLabel)
	Modal.close()
	local o: Opts = opts or {}
	local w, h = o.width or 760, o.height or 560
	local root = Kit.root("modal")
	if not o.noOverlay then
		local s: Frame = Kit.new("TextButton", {
			Name = "Overlay",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.ink,
			BackgroundTransparency = 0.65,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		});
		(s :: any).Activated:Connect(Modal.close) -- clic afuera cierra
		shade = s
		local b = Instance.new("BlurEffect")
		b.Size = 4
		b.Parent = Lighting
		blur = b
	end
	local holder: Frame = Kit.new("Frame", {
		Name = "Modal_" .. key,
		BackgroundTransparency = 1,
		AnchorPoint = o.anchor or Vector2.new(0.5, 0.5),
		Position = o.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		Parent = root,
	})
	local f: Frame = Kit.new("Frame", {
		Name = "Panel",
		BackgroundColor3 = Theme.paper,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Parent = holder,
	}, { Kit.corner(26) })
	Kit.shadow(f, Color3.fromRGB(207, 208, 214), 8, 26)
	-- en pantallas chicas (celular) que no se salga
	local scaler = Instance.new("UIScale")
	scaler.Parent = holder
	local function fit()
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scaler.Scale = math.min(1, (vp.X - 24) / w, (vp.Y * 0.9) / h)
	end
	fit()
	if workspace.CurrentCamera then
		fitConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local titleLabel: TextLabel = Kit.text(title, 28, {
		FontFace = Theme.display,
		Position = UDim2.fromOffset(22, 16),
		Size = UDim2.new(1, -90, 0, 34),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = f,
	})
	Modal.closeButton(f, Modal.close)
	local content: Frame = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 1, -80),
		Parent = f,
	})
	frame = holder
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
