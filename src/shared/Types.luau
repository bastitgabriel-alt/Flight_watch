--!strict
-- Types partagés entre le serveur et le client.

export type RarityId = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type MutationId = "None" | "Golden" | "Neon"

-- Indices visibles par tous + indices cachés (révélés par un outil acheté)
export type ClueType = "Registry" | "Shadow" | "Eyes" | "Photo" | "UV" | "Thermal"

-- Strong = indice évident, Subtle = indice discret (anomalies rares)
export type ClueStrength = "Strong" | "Subtle"

-- Couleurs d'un personnage (placeholder avant de vrais modèles)
export type Appearance = {
	Skin: Color3,
	Shirt: Color3,
	Pants: Color3,
}

export type Rarity = {
	DisplayName: string, -- nom affiché au joueur
	Color: Color3,
	Order: number, -- 1 = la plus commune
	SpawnWeight: number, -- poids de tirage (0 = n'apparaît jamais)
	ClueCount: number, -- nombre d'indices montrés par une anomalie de cette rareté
	SubtleChance: number, -- probabilité (0 à 1) que chaque indice soit discret
	HiddenClueChance: number, -- probabilité d'un indice caché en plus (UV ou thermique)
}

export type Mutation = {
	DisplayName: string,
	IncomeMultiplier: number,
	SpawnChance: number, -- probabilité (0 à 1) d'apparition
	Color: Color3?, -- couleur appliquée au modèle dans la cellule
	Material: string?, -- nom d'un Enum.Material, ex. "Neon"
}

export type AnomalyDef = {
	Id: string,
	DisplayName: string,
	Rarity: RarityId,
	Income: number, -- argent par seconde (avant mutation et multiplicateurs)
	Description: string,
	TrueForm: Appearance, -- apparence révélée une fois dans la cellule
	EyeColor: Color3,
	Clues: { ClueType }, -- indices que cette anomalie peut montrer
}

-- Une anomalie possédée par un joueur (sauvegardée)
export type OwnedAnomaly = {
	Id: string,
	Mutation: MutationId,
	Cell: number, -- numéro de cellule, 0 = pas de cellule
}

-- Profil d'un client généré par le serveur (jamais envoyé tel quel au client)
export type GuestProfile = {
	Name: string,
	IsAnomaly: boolean,
	AnomalyId: string?,
	Mutation: MutationId,
	Appearance: Appearance, -- apparence réelle (déguisement)
	PhotoAppearance: Appearance, -- apparence sur la photo d'identité
	Registry: { string }, -- noms écrits dans le registre des réservations
	Clues: { [ClueType]: ClueStrength },
	Temperature: number, -- °C, mesurée par le scanner thermique
}

-- Ce que le client a le droit de voir quand il reçoit un client
export type ReceptionInfo = {
	Token: number,
	Name: string,
	PhotoAppearance: Appearance,
	Registry: { string },
	Deadline: number, -- workspace:GetServerTimeNow() limite
	Guest: Model?, -- le modèle 3D du client (pour cadrer la caméra)
	-- Résultats des outils possédés (absent = outil non acheté)
	ToolResults: {
		UV: boolean?, -- true = traces fluorescentes
		Thermal: number?, -- température en °C
	},
}

return {}
