--!strict
-- Punto de entrada del cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local State = require(Controllers.State)
local Audio = require(Controllers.Audio)
local Toast = require(UI.Toast)
local Hud = require(Controllers.Hud)
local Dialog = require(Controllers.Dialog)
local Machine = require(Controllers.Machine)
local Reveal = require(Controllers.Reveal)
local Inventory = require(Controllers.Inventory)
local Shop = require(Controllers.Shop)
local Index = require(Controllers.Index)
local Trade = require(Controllers.Trade)
local Interact = require(Controllers.Interact)
local Companion = require(Controllers.Companion)
local Squish = require(Controllers.Squish)
local Tutorial = require(Controllers.Tutorial)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

State.init()
Audio.init()
Toast.init()
Hud.init()
Dialog.init()
Machine.init()
Reveal.init()
Inventory.init()
Shop.init()
Index.init()
Trade.init()
Companion.init()
Squish.init()
Tutorial.init()
task.spawn(Interact.init)

print("[Squishy World] Cliente listo —", #Config.Species, "moldes cargados")
-- TODO Fase 7: manos que rodean el contorno + EditableMesh (DeformEngine), apuntar, fantasma
-- TODO Fase 8–10: Estudio Squish, Cera de vela, Tour de bienvenida
