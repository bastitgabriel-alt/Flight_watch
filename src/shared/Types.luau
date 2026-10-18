--!strict
-- Types partagés entre le serveur et le client.

export type RarityId = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type MutationId = "None" | "Golden" | "Neon"

export type Rarity = {
	displayName: string, -- nom affiché au joueur (français)
	color: Color3,
	order: number, -- 1 = la plus commune
}

export type Mutation = {
	displayName: string,
	incomeMultiplier: number,
	spawnChance: number, -- probabilité (0 à 1) qu'une anomalie apparaisse avec cette mutation
}

return {}
