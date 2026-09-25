--!strict
-- Punto de entrada de toda la configuración del juego.
local Config = {
	Game = require(script.GameConfig),
	Rarities = require(script.Rarities),
	Species = require(script.Species),
	Variants = require(script.Variants),
	Mutations = require(script.Mutations),
	Fillings = require(script.Fillings),
	Machines = require(script.Machines),
	Upgrades = require(script.Upgrades),
	Quests = require(script.Quests),
	NpcDefs = require(script.NpcDefs),
	WaxColors = require(script.WaxColors),
	WorldLayout = require(script.WorldLayout),
	Monetization = require(script.Monetization),
	AssetIds = require(script.AssetIds),
}
return Config
