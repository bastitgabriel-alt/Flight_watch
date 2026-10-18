--!strict
-- Mutations : variante visuelle + multiplicateur de revenu.
-- D'autres mutations (Ombre x3, etc.) viendront après le MVP.

local Types = require(script.Parent.Parent.Types)

local MutationConfig: { [Types.MutationId]: Types.Mutation } = {
	None = { displayName = "Normale", incomeMultiplier = 1, spawnChance = 0 },
	Golden = { displayName = "Dorée", incomeMultiplier = 2, spawnChance = 0.05 },
	Neon = { displayName = "Néon", incomeMultiplier = 5, spawnChance = 0.01 },
}

return MutationConfig
