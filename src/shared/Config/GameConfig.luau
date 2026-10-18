--!strict
-- Réglages généraux du jeu.

local GameConfig = {
	-- UserIds Roblox autorisés à utiliser les commandes debug/admin
	AdminUserIds = {} :: { number },

	-- Dans Roblox Studio, tout le monde peut utiliser les commandes debug
	DebugInStudio = true,

	-- Nom du DataStore. Le changer = tout le monde repart de zéro !
	DataStoreName = "PlayerData_v1",

	-- Nombre d'hôtels sur la carte = nombre max de joueurs par serveur
	HotelCount = 6,

	-- Cellules de confinement
	BaseCells = 8, -- cellules au départ
	MaxCells = 16, -- emplacements construits dans chaque hôtel
}

return GameConfig
