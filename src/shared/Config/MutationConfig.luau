--!strict
-- Mutations : variante visuelle + multiplicateur de revenu.
-- Lunaire et Ombre n'apparaissent que pendant leur événement (EventConfig).

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
	Lunar = {
		DisplayName = "Lunaire",
		IncomeMultiplier = 4,
		SpawnChance = 0.2,
		Color = Color3.fromRGB(200, 20, 40),
		Material = "Neon",
		EventOnly = "BloodMoon",
	},
	Shadow = {
		DisplayName = "Ombre",
		IncomeMultiplier = 3,
		SpawnChance = 0.15,
		Color = Color3.fromRGB(15, 10, 25),
		Material = "SmoothPlastic",
		EventOnly = "Blackout",
	},
}

-- Ordre de tirage des mutations (la plus rare d'abord)
local ROLL_ORDER: { Types.MutationId } = { "Neon", "Lunar", "Shadow", "Golden" }

return {
	Mutations = MutationConfig,
	RollOrder = ROLL_ORDER,
}
