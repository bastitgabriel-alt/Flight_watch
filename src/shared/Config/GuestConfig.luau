--!strict
-- Réglages des clients qui arrivent à la réception.

local GuestConfig = {
	-- Probabilité qu'un client soit une anomalie déguisée
	AnomalyChance = 0.4,

	-- Attente entre deux clients (secondes, tirée au hasard entre min et max)
	SpawnDelayMin = 2,
	SpawnDelayMax = 4,

	-- Temps pour décider avant que le client perde patience (secondes)
	Patience = 25,

	-- Nombre de noms dans le registre des réservations
	RegistrySize = 5,

	FirstNames = {
		"Léa", "Hugo", "Emma", "Louis", "Chloé", "Lucas", "Manon", "Jules", "Camille", "Arthur",
		"Inès", "Nathan", "Sarah", "Tom", "Jade", "Théo", "Lina", "Gabriel", "Zoé", "Raphaël",
		"Alice", "Adam", "Rose", "Noah", "Anna", "Paul", "Eva", "Victor", "Nina", "Sacha",
	},
	LastNames = {
		"Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy",
		"Moreau", "Simon", "Laurent", "Lefebvre", "Michel", "Garcia", "David", "Bertrand", "Roux",
		"Vincent", "Fournier", "Morel", "Girard", "Andre", "Mercier", "Dupont", "Lambert", "Bonnet",
		"Francois", "Martinez", "Legrand",
	},

	SkinTones = {
		Color3.fromRGB(255, 224, 189),
		Color3.fromRGB(241, 194, 125),
		Color3.fromRGB(224, 172, 105),
		Color3.fromRGB(198, 134, 66),
		Color3.fromRGB(141, 85, 36),
		Color3.fromRGB(92, 56, 29),
	},
	ClothColors = {
		Color3.fromRGB(196, 40, 28),
		Color3.fromRGB(13, 105, 172),
		Color3.fromRGB(40, 127, 71),
		Color3.fromRGB(245, 205, 48),
		Color3.fromRGB(107, 50, 124),
		Color3.fromRGB(218, 133, 65),
		Color3.fromRGB(27, 42, 53),
		Color3.fromRGB(242, 243, 243),
		Color3.fromRGB(99, 95, 98),
		Color3.fromRGB(255, 102, 204),
		Color3.fromRGB(4, 175, 236),
		Color3.fromRGB(124, 92, 70),
	},
}

return GuestConfig
