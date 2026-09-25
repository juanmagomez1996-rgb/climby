--!strict
-- Confirmaciones (el confirm() del navegador en el prototipo).
local Kit = require(script.Parent.Parent.UI.Kit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Router = require(script.Parent.Router)

local Dialog = {}

function Dialog.confirm(text: string, yes: () -> ())
	local shade: Frame = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		ZIndex = 60,
		Parent = Kit.root("dialog"),
	})
	local box: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = Theme.paper,
		Parent = shade,
	}, { Kit.corner(20), Kit.pad(18, 16) })
	Kit.text(text, 16, { Size = UDim2.new(1, 0, 1, -56), TextYAlignment = Enum.TextYAlignment.Top, Parent = box })
	local ok = Kit.button(
		"Sí",
		Theme.mint,
		{ Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(0.5, -5, 0, 44), Parent = box }
	)
	local no = Kit.button(
		"Cancelar",
		Theme.white,
		{ Position = UDim2.new(0.5, 5, 1, -44), Size = UDim2.new(0.5, -5, 0, 44), Parent = box }
	)
	ok.Activated:Connect(function()
		shade:Destroy()
		yes()
	end)
	no.Activated:Connect(function()
		shade:Destroy()
	end)
end

function Dialog.init()
	Router.register("confirm", function(arg)
		Dialog.confirm(arg.text, arg.yes)
	end)
end

return Dialog
