--!strict
-- Statistiques de jeu (AnalyticsService de Roblox), visibles sur le Creator Hub
-- dans l'onglet Analytics une fois le jeu publié. Les erreurs sont ignorées :
-- les statistiques ne doivent jamais empêcher le jeu de marcher.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Événement libre (ex. « SessionLength », valeur en secondes)
function Analytics.event(player: Player, name: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

-- Étape du tutoriel (entonnoir d'accueil)
function Analytics.funnel(player: Player, step: number, stepName: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- « Première fois » (première capture, premier achat...) : enregistré une seule fois
function Analytics.first(player: Player, data: any, key: string)
	if data.Firsts[key] then
		return
	end
	data.Firsts[key] = true
	Analytics.event(player, `First{key}`)
end

return Analytics
