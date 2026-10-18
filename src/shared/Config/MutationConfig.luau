--!strict
-- Mutations : variante visuelle + multiplicateur de revenu.
-- D'autres mutations (Ombre x3, etc.) viendront après le MVP.

local Types = require(script.Parent.Parent.Types)

local MutationConfig: { [Types.MutationId]: Types.Mutation } = {
	None = {
		DisplayName = "Normale",
		IncomeMultiplier = 1,
		SpawnChance = 0, -- probabilité calculée : tout ce qui n'est pas muté
	},
	Golden = {
		DisplayName = "Dorée",
		IncomeMultiplier = 2,
		SpawnChance = 0.05,
		Color = Color3.fromRGB(255, 196, 48),
		Material = "Foil",
	},
	Neon = {
		DisplayName = "Néon",
		IncomeMultiplier = 5,
		SpawnChance = 0.01,
		Color = Color3.fromRGB(0, 255, 200),
		Material = "Neon",
	},
}

-- Ordre de tirage des mutations (la plus rare d'abord)
local ROLL_ORDER: { Types.MutationId } = { "Neon", "Golden" }

return {
	Mutations = MutationConfig,
	RollOrder = ROLL_ORDER,
}
