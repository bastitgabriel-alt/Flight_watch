--!strict
-- Calcul du revenu par seconde d'un joueur. Module pur, testable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Types = require(Shared:WaitForChild("Types"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local MutationConfig = require(Config:WaitForChild("MutationConfig"))

local IncomeCalculator = {}

-- Revenu d'une seule anomalie (sans les multiplicateurs du joueur)
function IncomeCalculator.anomalyIncome(anomalyId: string, mutation: Types.MutationId): number
	local def = AnomalyConfig.ById[anomalyId]
	if not def then
		return 0
	end
	local mutationDef = MutationConfig.Mutations[mutation]
	local multiplier = if mutationDef then mutationDef.IncomeMultiplier else 1
	return def.Income * multiplier
end

-- Revenu total : somme des anomalies placées dans une cellule x multiplicateur
function IncomeCalculator.total(anomalies: { [string]: Types.OwnedAnomaly }, multiplier: number): number
	local sum = 0
	for _, owned in anomalies do
		if owned.Cell > 0 then
			sum += IncomeCalculator.anomalyIncome(owned.Id, owned.Mutation)
		end
	end
	return sum * multiplier
end

return IncomeCalculator
