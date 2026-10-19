--!strict
-- Catalogue des anomalies (Anomalydex) : récompenses quand on en découvre assez.

local CatalogConfig = {
	-- Récompense versée une seule fois en atteignant Count anomalies découvertes
	Rewards = {
		{ Count = 3, Money = 500 },
		{ Count = 6, Money = 5000 },
		{ Count = 9, Money = 50000 },
		{ Count = 12, Money = 500000 },
		{ Count = 16, Money = 2000000 },
		{ Count = 20, Money = 10000000 },
		{ Count = 25, Money = 50000000 },
		{ Count = 31, Money = 500000000 },
	},
}

return CatalogConfig
