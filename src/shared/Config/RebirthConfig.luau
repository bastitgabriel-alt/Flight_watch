--!strict
-- Renaissance : on repart de zéro (argent et anomalies) contre des bonus
-- permanents. Outils, sécurité, cellules achetées par Robux et catalogue sont gardés.

local RebirthConfig = {
	BaseCost = 500000, -- prix de la 1re renaissance
	CostGrowth = 4, -- chaque renaissance coûte X fois plus cher que la précédente
	IncomeBonus = 0.5, -- +50 % de revenus par renaissance
	LuckBonus = 0.25, -- +25 % de chances de raretés hautes par renaissance
	StartMoneyPerRebirth = 2000, -- argent de départ offert après chaque renaissance
	MaxRebirths = 20,
}

-- Prix de la prochaine renaissance (rebirths = nombre déjà faites)
function RebirthConfig.cost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirths)
end

function RebirthConfig.incomeMultiplier(rebirths: number): number
	return 1 + RebirthConfig.IncomeBonus * rebirths
end

function RebirthConfig.luck(rebirths: number): number
	return 1 + RebirthConfig.LuckBonus * rebirths
end

return RebirthConfig
