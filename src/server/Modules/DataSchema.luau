--!strict
-- Structure des données sauvegardées de chaque joueur + migrations.
--
-- Pour changer la structure plus tard :
--   1. augmenter VERSION de 1
--   2. ajouter une fonction dans MIGRATIONS[ancienne version] qui transforme
--      les anciennes données vers la nouvelle forme
-- Les nouveaux champs simples sont ajoutés automatiquement (Reconcile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))

local VERSION = 1

local TEMPLATE = {
	DataVersion = VERSION,

	Money = EconomyConfig.StartingMoney,
	Rebirths = 0,
	RebirthMultiplier = 1,

	-- Anomalies possédées : { [uid] = { Id, Mutation, Cell } }, uid = "a1", "a2"...
	Anomalies = {},
	NextAnomalyUid = 1,
	CellsUnlocked = GameConfig.BaseCells,

	Tools = {}, -- { [toolId] = true }
	SecurityUpgrades = {}, -- { [upgradeId] = niveau }
	Discovered = {}, -- { [anomalyId] = true } pour le catalogue

	Stats = {
		Captures = 0,
		WrongCaptures = 0,
		Escaped = 0,
		GuestsServed = 0,
		StealsSucceeded = 0,
		StealsSuffered = 0,
	},

	LastLogin = 0, -- os.time() de la dernière connexion
	LastSeen = 0, -- os.time() de la dernière présence (gains hors ligne)
	LoginStreak = 0, -- jours de connexion d'affilée
	LastDailyDay = 0, -- jour (os.time() // 86400) de la dernière récompense quotidienne
	GamepassCache = {}, -- { [gamepassId en texte] = true }
	ProcessedReceipts = {}, -- { [purchaseId] = true } achats Robux déjà traités
	ReceiptOrder = {}, -- ordre des achats (pour ne garder que les derniers)
	LuckyUntil = 0, -- os.time() de fin de la « Nuit chanceuse »
	CatalogRewards = {}, -- { [palier en texte] = true } récompenses du catalogue reçues
	Firsts = {}, -- { [nom] = true } « premières fois » déjà envoyées aux statistiques
	InvitedUsers = {}, -- { [UserId en texte] = true } amis venus grâce à une invitation
	TutorialDone = false,
}

-- MIGRATIONS[n] transforme des données de la version n vers la version n + 1
local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- [1] = function(data) data.NouveauChamp = data.AncienChamp end,
}

local DataSchema = {}

DataSchema.VERSION = VERSION
DataSchema.TEMPLATE = TEMPLATE

function DataSchema.migrate(data: any)
	if type(data.DataVersion) ~= "number" then
		data.DataVersion = VERSION
	end
	while data.DataVersion < VERSION do
		local migration = MIGRATIONS[data.DataVersion]
		if migration then
			migration(data)
		end
		data.DataVersion += 1
	end
end

return DataSchema
