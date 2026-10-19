--!strict
-- Événements du serveur : toutes les X minutes, un événement de quelques
-- minutes change les règles pour tout le monde (annoncé à l'écran).
--
-- Effets possibles :
--   AnomalyChance       probabilité qu'un client soit une anomalie
--   RarityLuck          multiplie les chances des raretés au-dessus de Commune
--   IncomeMultiplier    multiplie les revenus de tous les joueurs
--   SpawnDelayMultiplier  < 1 = les clients arrivent plus vite
--   TipMultiplier       multiplie les pourboires des vrais clients
-- Les anomalies et mutations avec EventOnly = <Id> ne sortent que pendant l'événement.

export type EventDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Weight: number, -- chances d'être choisi
	Color: Color3,
	AnomalyChance: number?,
	RarityLuck: number?,
	IncomeMultiplier: number?,
	SpawnDelayMultiplier: number?,
	TipMultiplier: number?,
}

local EventConfig = {
	FirstDelay = 4 * 60, -- premier événement après le démarrage du serveur (secondes)
	Interval = 10 * 60, -- temps entre la fin d'un événement et le suivant
	Duration = 3 * 60, -- durée d'un événement

	Events = {
		{
			Id = "BloodMoon",
			DisplayName = "Lune de Sang",
			Description = "Raretés x3 • mutation Lunaire x4 • le Loup-Garou rôde",
			Weight = 1,
			Color = Color3.fromRGB(255, 60, 70),
			AnomalyChance = 0.55,
			RarityLuck = 3,
		},
		{
			Id = "Blackout",
			DisplayName = "Panne de courant",
			Description = "Revenus x2 • mutation Ombre x3 • l'Ombre Vivante sort du noir",
			Weight = 1,
			Color = Color3.fromRGB(150, 160, 255),
			AnomalyChance = 0.5,
			IncomeMultiplier = 2,
		},
		{
			Id = "GhostRush",
			DisplayName = "Ruée fantôme",
			Description = "Clients 2x plus rapides • pourboires x3 • la Banshee hurle",
			Weight = 1,
			Color = Color3.fromRGB(120, 255, 170),
			AnomalyChance = 0.5,
			SpawnDelayMultiplier = 0.5,
			TipMultiplier = 3,
		},
	} :: { EventDef },
}

function EventConfig.get(id: string?): EventDef?
	if not id then
		return nil
	end
	for _, event in EventConfig.Events do
		if event.Id == id then
			return event
		end
	end
	return nil
end

return EventConfig
