--!strict
-- Catalogue des anomalies (Anomalydex) : récompenses quand on en découvre assez.

local CatalogConfig = {
	-- Récompense versée une seule fois en atteignant Count anomalies découvertes
	Rewards = {
		{ Count = 3, Money = 500 },
		{ Count = 6, Money = 5000 },
		{ Count = 9, Money = 50000 },
		{ Count = 12, Money = 500000 },
	},
}

return CatalogConfig
