--!strict
-- Raretés des anomalies. Plus la rareté est haute, plus l'anomalie rapporte
-- (voir AnomalyConfig) et plus ses indices sont rares et discrets.
--
-- SpawnWeight : chances relatives qu'une anomalie soit de cette rareté.
-- Total = 100, donc chaque poids = pourcentage parmi les anomalies.
-- Objectif : 1re rare vers 10 min, 1re légendaire vers 1 h (voir tests/run.luau).

local Types = require(script.Parent.Parent.Types)

local RarityConfig: { [Types.RarityId]: Types.Rarity } = {
	Common = {
		DisplayName = "Commune",
		Color = Color3.fromRGB(190, 190, 190),
		Order = 1,
		SpawnWeight = 93,
		ClueCount = 2,
		SubtleChance = 0,
	},
	Rare = {
		DisplayName = "Rare",
		Color = Color3.fromRGB(70, 140, 255),
		Order = 2,
		SpawnWeight = 4,
		ClueCount = 1,
		SubtleChance = 0.2,
	},
	Epic = {
		DisplayName = "Épique",
		Color = Color3.fromRGB(170, 80, 255),
		Order = 3,
		SpawnWeight = 1.7,
		ClueCount = 1,
		SubtleChance = 0.5,
	},
	Legendary = {
		DisplayName = "Légendaire",
		Color = Color3.fromRGB(255, 190, 40),
		Order = 4,
		SpawnWeight = 1.1,
		ClueCount = 1,
		SubtleChance = 0.8,
	},
	Mythic = {
		DisplayName = "Mythique",
		Color = Color3.fromRGB(255, 60, 90),
		Order = 5,
		SpawnWeight = 0.2,
		ClueCount = 1,
		SubtleChance = 1,
	},
	-- Réservée aux événements admin (après le MVP) : n'apparaît jamais seule
	Secret = {
		DisplayName = "Secrète",
		Color = Color3.fromRGB(30, 30, 30),
		Order = 6,
		SpawnWeight = 0,
		ClueCount = 1,
		SubtleChance = 1,
	},
}

return RarityConfig
