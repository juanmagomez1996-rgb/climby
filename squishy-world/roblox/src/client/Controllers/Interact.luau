--!strict
-- Interacción (#prompt de template.html + interact() de game5.js): los ProximityPrompt del mundo
-- van en estilo Custom y se dibujan como el aviso del original, abajo al centro:
--   [E] Usar la Máquina Squishy · "Máquina 02 — requiere nivel 5" (bloqueado, fondo rojizo)
-- Al tocar el aviso (celular) también se activa.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local Audio = require(script.Parent.Audio)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Interact = {}

local machineDefs: { [string]: any } = {}
for _, m in Config.Machines do
	machineDefs[m.id] = m
end

local function lockedText(prompt: ProximityPrompt): string?
	local d = State.data
	if not d then
		return nil
	end
	if prompt:GetAttribute("Kind") == nil and prompt.Parent then
		local kind = prompt.Parent:GetAttribute("Kind")
		local id = prompt.Parent:GetAttribute("Id")
		if kind == "machine" then
			local def = machineDefs[tostring(id)]
			if def and d.level < def.level then
				return string.format("%s — requiere nivel %d", def.name, def.level)
			end
		end
	end
	return nil
end

local function trigger(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind") or (prompt.Parent and prompt.Parent:GetAttribute("Kind"))
	local id = prompt:GetAttribute("Id") or (prompt.Parent and prompt.Parent:GetAttribute("Id"))
	if Modal.current then
		return
	end
	local why = Modal.blocked()
	if why then
		Toast.show(why)
		return
	end
	if lockedText(prompt) then
		Audio.play("error")
		return
	end
	if kind == "machine" then
		Router.open("machine", id)
	elseif kind == "shop" then
		Router.open("shop")
	elseif kind == "index" then
		Router.open("index")
	elseif kind == "tradeBoard" then
		Router.open("tradePlayers")
	elseif kind == "npc" then
		Router.open("npcChat", id)
	end
end

function Interact.init()
	-- #prompt: bottom 120, fondo rgba(40,45,58,.88), radius 14, Nunito 900 16 blanco, tecla en ficha blanca
	local pill: TextButton = Kit.new("TextButton", {
		Name = "Prompt",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.ink,
		BackgroundTransparency = 0.12,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = Kit.root(),
	}, { Kit.corner(14), Kit.pad(16, 10) })
	local row: Frame = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = pill,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10) });
	(row:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
	local key: TextLabel = Kit.new("TextLabel", {
		BackgroundColor3 = Theme.white,
		TextColor3 = Theme.ink,
		FontFace = Theme.display,
		TextSize = 16,
		Text = "E",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = 1,
		Parent = row,
	}, { Kit.corner(8), Kit.pad(9, 0) })
	Kit.shadow(key, Color3.fromHex("#b7bccb"), 3, 8)
	local label = Kit.text("", 16, {
		FontFace = Theme.bodyBlack,
		TextColor3 = Theme.white,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = row,
	})

	local current: ProximityPrompt? = nil
	local function refresh()
		local p = current
		if not p or Modal.current then
			pill.Visible = false
			return
		end
		local locked = lockedText(p)
		label.Text = locked or p.ActionText
		key.Visible = locked == nil
		pill.BackgroundColor3 = if locked then Color3.fromRGB(120, 70, 80) else Theme.ink
		key.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "👆" else "E"
		pill.Visible = true
	end
	ProximityPromptService.PromptShown:Connect(function(prompt)
		current = prompt
		refresh()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if current == prompt then
			current = nil
			refresh()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(trigger)
	pill.Activated:Connect(function()
		local p = current
		if p then
			trigger(p)
		end
	end)
	Modal.onChange(refresh)
	State.onChange(refresh)

	-- letreros "Requiere nivel N" en máquinas bloqueadas (LockSign del original)
	local signs: { [string]: BillboardGui } = {}
	local interact = Workspace:WaitForChild("Interact", 60)
	local function applyLocks()
		local d = State.data
		if not d then
			return
		end
		for _, m in Config.WorldLayout.machines do
			local s = signs[m.id]
			if s then
				s.Enabled = d.level < m.level
			end
		end
	end
	for _, m in Config.WorldLayout.machines do
		task.spawn(function()
			-- con StreamingEnabled el ancla puede llegar después
			local anchor = interact and interact:WaitForChild("machine_" .. m.id, 120)
			if not anchor or not anchor:IsA("BasePart") then
				return
			end
			signs[m.id] = Kit.new("BillboardGui", {
				Size = UDim2.fromOffset(190, 40),
				StudsOffsetWorldSpace = Vector3.new(0, 7.5, 3),
				MaxDistance = 90,
				Enabled = false,
				Parent = anchor,
			}, {
				Kit.new("TextLabel", {
					BackgroundColor3 = Theme.ink,
					TextColor3 = Theme.white,
					FontFace = Theme.display,
					TextSize = 20,
					Text = "🔒 Requiere nivel " .. m.level,
					Size = UDim2.fromScale(1, 1),
				}, { Kit.corner(10) }),
			})
			applyLocks()
		end)
	end
	State.onChange(applyLocks)
end

return Interact
