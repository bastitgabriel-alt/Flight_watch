--!strict
-- Génère les clients de la réception : nom, apparence, photo, registre,
-- et, pour les anomalies déguisées, leurs indices.
-- Module « pur » (aucun effet sur le jeu), testable séparément.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Types = require(Shared:WaitForChild("Types"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local GuestConfig = require(Config:WaitForChild("GuestConfig"))
local MutationConfig = require(Config:WaitForChild("MutationConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))

export type Options = {
	AnomalyChance: number?, -- remplace GuestConfig.AnomalyChance
	RarityLuck: number?, -- multiplie les poids des raretés non communes (bonus)
	ForceAnomaly: boolean?, -- true = anomalie, false = vrai client, nil = hasard
	ForceAnomalyId: string?,
}

local GuestGenerator = {}

local HIDDEN_CLUES: { Types.ClueType } = { "UV", "Thermal" }

-- Température d'un humain normal, ou d'une anomalie glacée
local function normalTemperature(rng: Random): number
	return math.floor(rng:NextNumber(36.2, 37.4) * 10) / 10
end
local function coldTemperature(rng: Random): number
	return math.floor(rng:NextNumber(6, 18) * 10) / 10
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function shuffle<T>(rng: Random, list: { T })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function randomName(rng: Random): string
	return pick(rng, GuestConfig.FirstNames) .. " " .. pick(rng, GuestConfig.LastNames)
end

local function randomAppearance(rng: Random): Types.Appearance
	return {
		Skin = pick(rng, GuestConfig.SkinTones),
		Shirt = pick(rng, GuestConfig.ClothColors),
		Pants = pick(rng, GuestConfig.ClothColors),
	}
end

-- Choisit une couleur différente de « current » dans la liste
local function differentColor(rng: Random, list: { Color3 }, current: Color3): Color3
	local others = {}
	for _, color in list do
		if color ~= current then
			table.insert(others, color)
		end
	end
	return if #others > 0 then pick(rng, others) else current
end

-- Fausse le nom de famille en échangeant deux lettres voisines
-- (« Dubois » -> « Dubios »). Sert d'indice discret dans le registre.
function GuestGenerator.misspell(rng: Random, fullName: string): string
	local space = string.find(fullName, " ", 1, true)
	if not space then
		return fullName .. "e"
	end
	local first = string.sub(fullName, 1, space)
	local last = string.sub(fullName, space + 1)
	-- Positions où deux lettres voisines sont différentes (on garde la 1re lettre)
	local candidates = {}
	for i = 2, #last - 1 do
		local a, b = string.sub(last, i, i), string.sub(last, i + 1, i + 1)
		if a ~= b and string.match(a, "%a") and string.match(b, "%a") then
			table.insert(candidates, i)
		end
	end
	if #candidates == 0 then
		return first .. last .. "e"
	end
	local i = pick(rng, candidates)
	local swapped = string.sub(last, 1, i - 1)
		.. string.sub(last, i + 1, i + 1)
		.. string.sub(last, i, i)
		.. string.sub(last, i + 2)
	return first .. swapped
end

-- Tire une rareté selon les poids (RarityLuck augmente les raretés hautes)
function GuestGenerator.rollRarity(rng: Random, rarityLuck: number?): Types.RarityId
	local luck = rarityLuck or 1
	local entries: { { id: Types.RarityId, weight: number } } = {}
	local total = 0
	for id, rarity in RarityConfig do
		local weight = rarity.SpawnWeight
		if id ~= "Common" then
			weight *= luck
		end
		-- Une rareté sans anomalie configurée ne peut pas sortir
		local hasAnomaly = false
		for _, def in AnomalyConfig.List do
			if def.Rarity == id then
				hasAnomaly = true
				break
			end
		end
		if weight > 0 and hasAnomaly then
			table.insert(entries, { id = id, weight = weight })
			total += weight
		end
	end
	-- Ordre stable pour que les tests soient reproductibles
	table.sort(entries, function(a, b)
		return RarityConfig[a.id].Order < RarityConfig[b.id].Order
	end)
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry.weight
		if roll < 0 then
			return entry.id
		end
	end
	return entries[#entries].id
end

function GuestGenerator.rollMutation(rng: Random): Types.MutationId
	for _, id in MutationConfig.RollOrder do
		if rng:NextNumber() < MutationConfig.Mutations[id].SpawnChance then
			return id
		end
	end
	return "None"
end

function GuestGenerator.pickAnomaly(rng: Random, rarity: Types.RarityId): Types.AnomalyDef
	local candidates = {}
	for _, def in AnomalyConfig.List do
		if def.Rarity == rarity then
			table.insert(candidates, def)
		end
	end
	return pick(rng, candidates)
end

-- Registre : (size - 1) autres noms + le nom à inclure (s'il y en a un), mélangés
local function buildRegistry(rng: Random, includeName: string?, excludeName: string): { string }
	local size = GuestConfig.RegistrySize
	local names: { string } = {}
	local used: { [string]: boolean } = { [excludeName] = true }
	if includeName then
		table.insert(names, includeName)
		used[includeName] = true
	end
	local attempts = 0
	while #names < size and attempts < 200 do
		attempts += 1
		local name = randomName(rng)
		if not used[name] then
			used[name] = true
			table.insert(names, name)
		end
	end
	shuffle(rng, names)
	return names
end

function GuestGenerator.generate(rng: Random, options: Options?): Types.GuestProfile
	local opts: Options = options or {}
	local name = randomName(rng)
	local appearance = randomAppearance(rng)

	local isAnomaly
	if opts.ForceAnomalyId ~= nil then
		isAnomaly = true
	elseif opts.ForceAnomaly ~= nil then
		isAnomaly = opts.ForceAnomaly
	else
		isAnomaly = rng:NextNumber() < (opts.AnomalyChance or GuestConfig.AnomalyChance)
	end

	if not isAnomaly then
		return {
			Name = name,
			IsAnomaly = false,
			AnomalyId = nil,
			Mutation = "None",
			Appearance = appearance,
			PhotoAppearance = table.clone(appearance),
			Registry = buildRegistry(rng, name, name),
			Clues = {},
			Temperature = normalTemperature(rng),
		}
	end

	local def
	if opts.ForceAnomalyId and AnomalyConfig.ById[opts.ForceAnomalyId] then
		def = AnomalyConfig.ById[opts.ForceAnomalyId]
	else
		def = GuestGenerator.pickAnomaly(rng, GuestGenerator.rollRarity(rng, opts.RarityLuck))
	end
	local rarity = RarityConfig[def.Rarity]

	-- Choix des indices parmi ceux possibles pour cette anomalie
	local pool = table.clone(def.Clues)
	shuffle(rng, pool)
	local clues: { [Types.ClueType]: Types.ClueStrength } = {}
	for i = 1, math.min(rarity.ClueCount, #pool) do
		clues[pool[i]] = if rng:NextNumber() < rarity.SubtleChance then "Subtle" else "Strong"
	end
	-- Indice caché en plus (seulement visible avec l'outil correspondant)
	if rng:NextNumber() < rarity.HiddenClueChance then
		clues[pick(rng, HIDDEN_CLUES)] = "Strong"
	end

	-- Photo d'identité
	local photo = table.clone(appearance)
	if clues.Photo == "Strong" then
		photo.Skin = differentColor(rng, GuestConfig.SkinTones, appearance.Skin)
		photo.Shirt = differentColor(rng, GuestConfig.ClothColors, appearance.Shirt)
	elseif clues.Photo == "Subtle" then
		photo.Pants = differentColor(rng, GuestConfig.ClothColors, appearance.Pants)
	end

	-- Registre des réservations
	local registryName: string?
	if clues.Registry == "Strong" then
		registryName = nil -- son nom n'y est pas
	elseif clues.Registry == "Subtle" then
		registryName = GuestGenerator.misspell(rng, name) -- presque son nom
	else
		registryName = name
	end

	return {
		Name = name,
		IsAnomaly = true,
		AnomalyId = def.Id,
		Mutation = GuestGenerator.rollMutation(rng),
		Appearance = appearance,
		PhotoAppearance = photo,
		Registry = buildRegistry(rng, registryName, name),
		Clues = clues,
		Temperature = if clues.Thermal then coldTemperature(rng) else normalTemperature(rng),
	}
end

return GuestGenerator
