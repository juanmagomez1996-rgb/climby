--!strict
-- Punto de entrada del servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Catalog = require(Shared.Logic.Catalog)

Remotes.init()
print(
	string.format(
		"[Squishy World] Config cargada: %d especies, %d rarezas, %d rellenos, índice %d",
		#Config.Species,
		#Config.Rarities,
		#Config.Fillings,
		Catalog.indexTotal()
	)
)

if Config.Game.DEBUG then
	require(Shared.Logic.SelfTest)()
end

local Services = script.Parent:WaitForChild("Services")
local Net = require(Services.Net)
local DataService = require(Services.DataService)
local Economy = require(Services.Economy)
local MonetizationService = require(Services.MonetizationService)
local InventoryService = require(Services.InventoryService)
local FillService = require(Services.FillService)
local ShopService = require(Services.ShopService)
local TradeService = require(Services.TradeService)
local WorldBuilder = require(Services.WorldBuilder)
local NpcService = require(Services.NpcService)

WorldBuilder.build()
Net.init()
Economy.init()
MonetizationService.init()
InventoryService.init()
FillService.init()
ShopService.init()
TradeService.init()
NpcService.init()
DataService.init() -- al final: así todos los onLoaded ya están registrados

print("[Squishy World] Servidor listo ✅")
