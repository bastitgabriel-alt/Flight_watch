--!strict
-- Raretés des anomalies. Plus la rareté est haute, plus l'anomalie rapporte
-- et plus ses indices sont subtils. Les revenus sont dans AnomalyConfig.

local Types = require(script.Parent.Parent.Types)

local RarityConfig: { [Types.RarityId]: Types.Rarity } = {
	Common = { displayName = "Commune", color = Color3.fromRGB(180, 180, 180), order = 1 },
	Rare = { displayName = "Rare", color = Color3.fromRGB(70, 140, 255), order = 2 },
	Epic = { displayName = "Épique", color = Color3.fromRGB(170, 80, 255), order = 3 },
	Legendary = { displayName = "Légendaire", color = Color3.fromRGB(255, 190, 40), order = 4 },
	Mythic = { displayName = "Mythique", color = Color3.fromRGB(255, 60, 90), order = 5 },
	-- Prévue après le MVP (événements admin)
	Secret = { displayName = "Secrète", color = Color3.fromRGB(20, 20, 20), order = 6 },
}

return RarityConfig
