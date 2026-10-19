--!strict
-- Gamepasses et produits Robux.
-- Id = 0 : pas encore créé sur le Creator Hub (le bouton est caché dans la boutique).
-- Une fois créés, colle ici les numéros (voir le README, section « Monétisation »).

local MonetizationConfig = {
	GamePasses = {
		DoubleMoney = {
			Id = 2039716573,
			DisplayName = "Argent x2",
			Description = "Tes anomalies rapportent deux fois plus, pour toujours.",
		},
		ExtraCells = {
			Id = 2036914807,
			DisplayName = "+3 cellules",
			Description = "Trois cellules de confinement en plus, pour toujours.",
			Cells = 3,
		},
	},

	Products = {
		MoneyPack = {
			Id = 3720016049,
			DisplayName = "Sac d'argent",
			Description = "15 minutes de revenus d'un coup (minimum 1 000 $).",
			IncomeSeconds = 900,
			Minimum = 1000,
		},
		LuckyNight = {
			Id = 3720016213,
			DisplayName = "Nuit chanceuse",
			Description = "Anomalies rares 3 fois plus fréquentes pendant 10 minutes.",
			Duration = 600,
			RarityLuck = 3,
		},
	},
}

return MonetizationConfig
