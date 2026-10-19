--!strict
-- Boutique, verrou et vol. Tous les prix et durées sont ici.

local ShopConfig = {
	-- Cellules supplémentaires : prix = BasePrice x PriceGrowth ^ (nombre déjà achetées)
	Cells = {
		BasePrice = 150,
		PriceGrowth = 1.9,
		MaxPurchasable = 5, -- 8 de base + 5 achetées (+ 3 avec le gamepass) = 16 max
	},

	-- Outils de détection (achat unique). Chacun révèle un indice caché.
	Tools = {
		UVLamp = {
			DisplayName = "Lampe UV",
			Description = "Révèle les traces fluorescentes laissées par certaines anomalies.",
			Price = 400,
			Order = 1,
		},
		ThermalScanner = {
			DisplayName = "Scanner thermique",
			Description = "Mesure la température du client. Une anomalie est glacée.",
			Price = 2500,
			Order = 2,
		},
	},

	-- Améliorations de sécurité (plusieurs niveaux)
	Security = {
		LockPlus = {
			DisplayName = "Verrou renforcé",
			Description = "Ta porte reste verrouillée 20 s de plus par niveau.",
			Prices = { 800, 5000 },
			Order = 1,
		},
		SlowTrap = {
			DisplayName = "Piège ralentisseur",
			Description = "Les voleurs qui emportent tes anomalies avancent plus lentement.",
			Prices = { 1200, 7000 },
			Order = 2,
		},
	},

	Lock = {
		BaseDuration = 60, -- secondes de verrouillage
		BonusPerLevel = 20, -- + par niveau de « Verrou renforcé »
		Cooldown = 60, -- attente avant de pouvoir reverrouiller
	},

	Steal = {
		HoldDuration = 1.5, -- secondes à maintenir pour voler
		CarrySpeed = 11, -- vitesse du voleur chargé (normale : 16)
		TrapSpeeds = { 8, 6 }, -- vitesse selon le niveau du « Piège ralentisseur » de la victime
		Timeout = 90, -- l'anomalie retourne dans sa cellule après ce délai
	},
}

-- Prix de la prochaine cellule, ou nil si le maximum est atteint
function ShopConfig.nextCellPrice(purchased: number): number?
	if purchased >= ShopConfig.Cells.MaxPurchasable then
		return nil
	end
	return math.floor(ShopConfig.Cells.BasePrice * ShopConfig.Cells.PriceGrowth ^ purchased)
end

-- Prix du prochain niveau d'une amélioration, ou nil si niveau max
function ShopConfig.nextSecurityPrice(upgradeId: string, level: number): number?
	local upgrade = (ShopConfig.Security :: any)[upgradeId]
	if not upgrade then
		return nil
	end
	return upgrade.Prices[level + 1]
end

function ShopConfig.lockDuration(lockPlusLevel: number): number
	return ShopConfig.Lock.BaseDuration + ShopConfig.Lock.BonusPerLevel * lockPlusLevel
end

function ShopConfig.carrySpeed(slowTrapLevel: number): number
	return ShopConfig.Steal.TrapSpeeds[slowTrapLevel] or ShopConfig.Steal.CarrySpeed
end

return ShopConfig
