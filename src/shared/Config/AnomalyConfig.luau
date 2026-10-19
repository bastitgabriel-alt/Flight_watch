--!strict
-- Liste des anomalies. Pour en ajouter une : copier un bloc, changer l'Id
-- (unique, sans espace ni accent, ne plus jamais le changer une fois publié :
-- il est sauvegardé dans les données des joueurs).
--
-- Income   : argent par seconde
-- TrueForm : couleurs révélées dans la cellule (peau, haut, bas)
-- Look     : traits monstrueux visibles dans la cellule (liste dans AnomalyLooks)
-- Scale    : taille dans la cellule (1 = normale)
-- Clues    : indices possibles ("Registry", "Shadow", "Eyes", "Photo").
--            Le nombre d'indices montrés dépend de la rareté (RarityConfig).

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local list: { Types.AnomalyDef } = {
	-- Communes
	{
		Id = "Doppelganger",
		DisplayName = "Le Sosie",
		Rarity = "Common",
		Income = 1,
		Description = "Il ressemble à quelqu'un que tu connais. Un peu trop.",
		TrueForm = { Skin = rgb(163, 162, 165), Shirt = rgb(40, 40, 40), Pants = rgb(40, 40, 40) },
		EyeColor = rgb(255, 255, 255),
		Clues = { "Photo", "Registry", "Eyes", "Shadow" },
		Look = { "Faceless", "ExtraEyes" },
	},
	{
		Id = "Shadowless",
		DisplayName = "L'Homme sans ombre",
		Rarity = "Common",
		Income = 2,
		Description = "Le soleil le traverse sans le voir.",
		TrueForm = { Skin = rgb(235, 235, 225), Shirt = rgb(20, 20, 20), Pants = rgb(20, 20, 20) },
		EyeColor = rgb(120, 200, 255),
		Clues = { "Shadow", "Registry", "Eyes" },
		Look = { "Faceless", "Wisps" },
		Scale = 1.15,
	},
	{
		Id = "MrsSmile",
		DisplayName = "Madame Sourire",
		Rarity = "Common",
		Income = 2,
		Description = "Elle sourit. Tout le temps. Même en dormant.",
		TrueForm = { Skin = rgb(255, 230, 230), Shirt = rgb(255, 120, 170), Pants = rgb(255, 120, 170) },
		EyeColor = rgb(255, 80, 160),
		Clues = { "Eyes", "Photo", "Registry" },
		Look = { "Smile" },
	},
	{
		Id = "GreyTraveler",
		DisplayName = "Le Voyageur Gris",
		Rarity = "Common",
		Income = 3,
		Description = "Il arrive toujours de nulle part, avec une valise vide.",
		TrueForm = { Skin = rgb(120, 120, 120), Shirt = rgb(90, 90, 90), Pants = rgb(70, 70, 70) },
		EyeColor = rgb(200, 200, 200),
		Clues = { "Registry", "Photo", "Shadow" },
		Look = { "TopHat", "Suitcase" },
	},

	-- Rares
	{
		Id = "Sleepwalker",
		DisplayName = "Le Somnambule",
		Rarity = "Rare",
		Income = 8,
		Description = "Il a réservé la chambre 0. Elle n'existe pas.",
		TrueForm = { Skin = rgb(200, 210, 255), Shirt = rgb(60, 60, 120), Pants = rgb(60, 60, 120) },
		EyeColor = rgb(150, 150, 255),
		Clues = { "Eyes", "Shadow", "Registry" },
		Look = { "NightCap", "Hover" },
	},
	{
		Id = "MirrorLady",
		DisplayName = "La Dame du Miroir",
		Rarity = "Rare",
		Income = 10,
		Description = "Son reflet part toujours une seconde après elle.",
		TrueForm = { Skin = rgb(220, 240, 255), Shirt = rgb(180, 220, 255), Pants = rgb(140, 180, 220) },
		EyeColor = rgb(0, 220, 255),
		Clues = { "Photo", "Eyes", "Registry" },
		Look = { "Mirror" },
	},
	{
		Id = "ForgottenMailman",
		DisplayName = "Le Facteur Oublié",
		Rarity = "Rare",
		Income = 12,
		Description = "Il livre des lettres datées de 1923.",
		TrueForm = { Skin = rgb(210, 190, 150), Shirt = rgb(30, 60, 120), Pants = rgb(30, 30, 60) },
		EyeColor = rgb(255, 220, 120),
		Clues = { "Registry", "Shadow", "Photo" },
		Look = { "Cap", "MailBag" },
	},

	-- Épiques
	{
		Id = "InvertedGuest",
		DisplayName = "L'Invité Inversé",
		Rarity = "Epic",
		Income = 35,
		Description = "Il dit « au revoir » en arrivant.",
		TrueForm = { Skin = rgb(40, 255, 200), Shirt = rgb(255, 0, 90), Pants = rgb(0, 30, 255) },
		EyeColor = rgb(255, 255, 0),
		Clues = { "Photo", "Shadow", "Eyes" },
		Look = { "TwistedHead" },
	},
	{
		Id = "PhantomConcierge",
		DisplayName = "Le Concierge Fantôme",
		Rarity = "Epic",
		Income = 45,
		Description = "Il connaît le numéro de ta chambre. Tu n'as pas de chambre.",
		TrueForm = { Skin = rgb(240, 250, 255), Shirt = rgb(120, 0, 0), Pants = rgb(20, 20, 20) },
		EyeColor = rgb(170, 255, 255),
		Clues = { "Registry", "Eyes", "Shadow" },
		Look = { "Ghost", "Cap" },
	},

	-- Légendaires
	{
		Id = "MidnightBride",
		DisplayName = "La Mariée de Minuit",
		Rarity = "Legendary",
		Income = 150,
		Description = "Elle attend quelqu'un qui n'arrivera jamais.",
		TrueForm = { Skin = rgb(250, 250, 255), Shirt = rgb(255, 255, 255), Pants = rgb(230, 230, 240) },
		EyeColor = rgb(255, 40, 40),
		Clues = { "Eyes", "Photo", "Registry" },
		Look = { "Veil", "Dress", "Hover" },
	},
	{
		Id = "FacelessWarden",
		DisplayName = "Le Gardien Sans Visage",
		Rarity = "Legendary",
		Income = 200,
		Description = "Personne ne se souvient de son visage. Lui non plus.",
		TrueForm = { Skin = rgb(10, 10, 10), Shirt = rgb(50, 0, 80), Pants = rgb(10, 10, 10) },
		EyeColor = rgb(180, 0, 255),
		Clues = { "Shadow", "Registry", "Photo" },
		Look = { "Faceless", "LongArms", "Wisps" },
		Scale = 1.25,
	},

	-- Mythique
	{
		Id = "TheOwner",
		DisplayName = "Le Propriétaire",
		Rarity = "Mythic",
		Income = 800,
		Description = "Il affirme que l'hôtel lui appartient. Il a peut-être raison.",
		TrueForm = { Skin = rgb(255, 215, 0), Shirt = rgb(15, 15, 15), Pants = rgb(15, 15, 15) },
		EyeColor = rgb(255, 0, 0),
		Clues = { "Registry", "Eyes", "Photo", "Shadow" },
		Look = { "Crown", "Cape", "Halo" },
		Scale = 1.3,
	},
}

-- Accès par Id : AnomalyConfig.ById["Doppelganger"]
local byId: { [string]: Types.AnomalyDef } = {}
for _, def in list do
	assert(byId[def.Id] == nil, `Id d'anomalie en double : {def.Id}`)
	byId[def.Id] = def
end

return {
	List = list,
	ById = byId,
}
