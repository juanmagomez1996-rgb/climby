--!strict
-- ProximityPrompts del mundo (WorldBuilder / NpcService) → abrir la pantalla que toca.
-- También pone los letreros "Nivel N" sobre las máquinas bloqueadas (refreshMachineLocks).
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local Modal = require(script.Parent.Parent.UI.Modal)
local Theme = require(script.Parent.Parent.UI.Theme)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local Interact = {}

function Interact.init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Kind") or (prompt.Parent and prompt.Parent:GetAttribute("Kind"))
		local id = prompt:GetAttribute("Id") or (prompt.Parent and prompt.Parent:GetAttribute("Id"))
		if Modal.current then
			Modal.close()
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
			if prompt:GetAttribute("Action") == "talk" then
				State.request("npcTalk", { npc = id })
			else
				Router.open("npcTrade", id)
			end
		end
	end)

	-- letreros de nivel en máquinas bloqueadas
	local signs: { [string]: BillboardGui } = {}
	local interact = Workspace:WaitForChild("Interact", 30)
	for _, m in Config.WorldLayout.machines do
		local anchor = interact and interact:FindFirstChild("machine_" .. m.id)
		if anchor and anchor:IsA("BasePart") then
			local bb: BillboardGui = Kit.new("BillboardGui", {
				Size = UDim2.fromOffset(150, 40),
				StudsOffsetWorldSpace = Vector3.new(0, 7.5, 3),
				MaxDistance = 90,
				Enabled = false,
				Parent = anchor,
			}, {
				Kit.text("🔒 Nivel " .. m.level, 20, {
					BackgroundTransparency = 0,
					BackgroundColor3 = Theme.ink,
					TextColor3 = Theme.white,
					Font = Theme.display,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
				}),
			})
			signs[m.id] = bb
		end
	end
	State.onChange(function(d)
		for _, m in Config.WorldLayout.machines do
			local s = signs[m.id]
			if s then
				s.Enabled = d.level < m.level
			end
		end
	end)
end

return Interact
