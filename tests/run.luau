--!nocheck
-- Tests de la logique « pure » du jeu, exécutés hors de Roblox.
-- Simule juste ce qu'il faut de l'API Roblox (script, require, Color3, Random...).

local ROOT = "src"

------------------------------------------------------------------ simulation Roblox
local Color3 = {}
Color3.__index = Color3
function Color3.fromRGB(r, g, b)
	return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end

local Random = {}
Random.__index = Random
function Random.new(seed)
	math.randomseed(seed or 12345)
	return setmetatable({}, Random)
end
function Random:NextNumber(min, max)
	-- Générateur de Luau (le LCG maison était trop corrélé)
	local x = math.random()
	if min then
		return min + x * (max - min)
	end
	return x
end
function Random:NextInteger(min, max)
	return min + math.floor(self:NextNumber() * (max - min + 1))
end

local function makeNode(path, name, parent)
	local node = { __path = path, Name = name, Parent = parent }
	local children = {}
	local function child(childName)
		if children[childName] then
			return children[childName]
		end
		local base = node.__path .. "/" .. childName
		local found
		if __isdir(base) then
			found = makeNode(base, childName, node)
		elseif __readfile(base .. ".luau") then
			found = makeNode(base .. ".luau", childName, node)
		end
		children[childName] = found
		return found
	end
	return setmetatable(node, {
		__index = function(_, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, childName)
					local found = child(childName)
					assert(found or key == "FindFirstChild", "Introuvable : " .. node.__path .. "/" .. childName)
					return found
				end
			end
			return child(key)
		end,
	})
end

local shared = makeNode(ROOT .. "/shared", "Shared")
local server = makeNode(ROOT .. "/server", "Server")
local services = {
	ReplicatedStorage = setmetatable({}, { __index = function(_, k) return k == "Shared" and shared or nil end }),
	ServerScriptService = setmetatable({}, { __index = function(_, k) return k == "Server" and server or nil end }),
	RunService = { IsServer = function() return true end, IsStudio = function() return true end },
}
services.ReplicatedStorage.WaitForChild = function(self, k) return self[k] end
services.ServerScriptService.WaitForChild = function(self, k) return self[k] end
local game = { GetService = function(_, name) return assert(services[name], "Service non simulé : " .. name) end }

local cache = {}
local function robloxRequire(node)
	local path = node.__path
	if cache[path] == nil then
		local source = assert(__readfile(path), "Fichier introuvable : " .. path)
		local env = setmetatable({
			script = node, game = game, Color3 = Color3, Random = Random, require = robloxRequire,
			task = { spawn = function(f, ...) f(...) end, wait = function() return 0 end },
		}, { __index = _G })
		local fn = __load(source, path, env)
		cache[path] = fn()
	end
	return cache[path]
end

------------------------------------------------------------------ mini framework
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("ÉCHEC  " .. name .. " : " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "") .. " attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2)
	end
end

------------------------------------------------------------------ modules testés
local Config = shared.Config
local AnomalyConfig = robloxRequire(Config.AnomalyConfig)
local RarityConfig = robloxRequire(Config.RarityConfig)
local GuestConfig = robloxRequire(Config.GuestConfig)
local MutationConfig = robloxRequire(Config.MutationConfig)
local Format = robloxRequire(shared.Util.Format)
local GuestGenerator = robloxRequire(server.Modules.GuestGenerator)
local IncomeCalculator = robloxRequire(server.Modules.IncomeCalculator)
local DataSchema = robloxRequire(server.Modules.DataSchema)

test("12 anomalies sur 5 raretés, indices valides", function()
	eq(#AnomalyConfig.List, 12, "nombre d'anomalies")
	local rarities = {}
	local valid = { Registry = true, Shadow = true, Eyes = true, Photo = true }
	for _, def in AnomalyConfig.List do
		assert(RarityConfig[def.Rarity], "rareté inconnue " .. def.Rarity)
		rarities[def.Rarity] = true
		assert(#def.Clues >= RarityConfig[def.Rarity].ClueCount, def.Id .. " : pas assez d'indices possibles")
		for _, clue in def.Clues do
			assert(valid[clue], def.Id .. " : indice inconnu " .. clue)
		end
		assert(def.Income > 0, def.Id)
	end
	local count = 0
	for _ in rarities do
		count += 1
	end
	eq(count, 5, "raretés utilisées")
end)

test("Format des nombres", function()
	eq(Format.number(0), "0")
	eq(Format.number(999.9), "999")
	eq(Format.number(1000), "1K")
	eq(Format.number(1234), "1.2K")
	eq(Format.number(15360), "15.3K")
	eq(Format.number(152000), "152K")
	eq(Format.number(2500000), "2.5M")
	eq(Format.number(-1500), "-1.5K")
	eq(Format.money(42), "$42")
end)

test("Faute d'orthographe du registre", function()
	local rng = Random.new(7)
	for _ = 1, 500 do
		local name = "Léa Dubois"
		local wrong = GuestGenerator.misspell(rng, name)
		assert(wrong ~= name, "nom identique")
		eq(#wrong, #name, "longueur")
		eq(string.sub(wrong, 1, #"Léa D"), "Léa D", "début du nom")
	end
end)

test("Clients générés cohérents (20 000 tirages)", function()
	local rng = Random.new(42)
	local anomalies, total = 0, 20000
	local rarityCount, mutationCount = {}, {}
	for _ = 1, total do
		local g = GuestGenerator.generate(rng)
		eq(#g.Registry, GuestConfig.RegistrySize, "taille du registre")
		local seen = {}
		for _, n in g.Registry do
			assert(not seen[n], "nom en double dans le registre")
			seen[n] = true
		end
		if not g.IsAnomaly then
			assert(seen[g.Name], "vrai client absent du registre")
			assert(next(g.Clues) == nil, "vrai client avec indices")
			eq(g.PhotoAppearance.Skin, g.Appearance.Skin)
			eq(g.PhotoAppearance.Shirt, g.Appearance.Shirt)
			eq(g.PhotoAppearance.Pants, g.Appearance.Pants)
		else
			anomalies += 1
			local def = AnomalyConfig.ById[g.AnomalyId]
			assert(def, "anomalie inconnue")
			rarityCount[def.Rarity] = (rarityCount[def.Rarity] or 0) + 1
			mutationCount[g.Mutation] = (mutationCount[g.Mutation] or 0) + 1
			local n = 0
			for clue in g.Clues do
				n += 1
				assert(table.find(def.Clues, clue), "indice non autorisé")
			end
			eq(n, RarityConfig[def.Rarity].ClueCount, "nombre d'indices " .. def.Rarity)
			-- Registre
			if g.Clues.Registry == "Strong" then
				assert(not seen[g.Name], "nom présent malgré l'indice registre")
			elseif g.Clues.Registry == "Subtle" then
				assert(not seen[g.Name], "nom exact présent malgré l'indice discret")
			else
				assert(seen[g.Name], "nom absent sans indice registre")
			end
			-- Photo
			if g.Clues.Photo == "Strong" then
				assert(g.PhotoAppearance.Skin ~= g.Appearance.Skin, "photo forte identique")
			elseif g.Clues.Photo == "Subtle" then
				assert(g.PhotoAppearance.Pants ~= g.Appearance.Pants, "photo discrète identique")
				eq(g.PhotoAppearance.Skin, g.Appearance.Skin)
			else
				eq(g.PhotoAppearance.Skin, g.Appearance.Skin)
				eq(g.PhotoAppearance.Pants, g.Appearance.Pants)
			end
			-- Toute anomalie doit être repérable
			assert(n >= 1, "anomalie sans indice")
		end
	end
	local ratio = anomalies / total
	assert(math.abs(ratio - GuestConfig.AnomalyChance) < 0.02, "taux d'anomalies " .. ratio)
	print(string.format("  Anomalies : %.1f %% des clients", ratio * 100))
	for _, id in { "Common", "Rare", "Epic", "Legendary", "Mythic" } do
		print(string.format("  %-10s %5.2f %%", id, (rarityCount[id] or 0) / anomalies * 100))
	end
	print(string.format("  Mutations : Dorée %.2f %%, Néon %.2f %%",
		(mutationCount.Golden or 0) / anomalies * 100, (mutationCount.Neon or 0) / anomalies * 100))
end)

test("Options forcées (debug)", function()
	local rng = Random.new(1)
	eq(GuestGenerator.generate(rng, { ForceAnomaly = false }).IsAnomaly, false)
	eq(GuestGenerator.generate(rng, { ForceAnomaly = true }).IsAnomaly, true)
	eq(GuestGenerator.generate(rng, { ForceAnomalyId = "TheOwner" }).AnomalyId, "TheOwner")
end)

test("Calcul du revenu", function()
	eq(IncomeCalculator.anomalyIncome("Doppelganger", "None"), 1)
	eq(IncomeCalculator.anomalyIncome("Doppelganger", "Golden"), 2)
	eq(IncomeCalculator.anomalyIncome("Doppelganger", "Neon"), 5)
	eq(IncomeCalculator.anomalyIncome("Inconnue", "None"), 0)
	local owned = {
		["1"] = { Id = "Doppelganger", Mutation = "None", Cell = 1 },
		["2"] = { Id = "Sleepwalker", Mutation = "Golden", Cell = 2 },
		["3"] = { Id = "TheOwner", Mutation = "None", Cell = 0 }, -- hors cellule : ne compte pas
	}
	eq(IncomeCalculator.total(owned, 1), 17)
	eq(IncomeCalculator.total(owned, 0.5), 8.5)
end)

test("Schéma de données et migration", function()
	local data = { Money = 5 }
	DataSchema.migrate(data)
	eq(data.DataVersion, DataSchema.VERSION)
	eq(DataSchema.TEMPLATE.CellsUnlocked, 8)
	eq(DataSchema.TEMPLATE.Money, 0)
end)

test("Courbe de progression (estimation)", function()
	-- Hypothèse : un client toutes les ~15 s, 90 % des anomalies repérées
	local guestsPerMinute = 4
	local anomaliesPerMinute = guestsPerMinute * GuestConfig.AnomalyChance * 0.9
	local weights, total = {}, 0
	for id, r in RarityConfig do
		weights[id] = r.SpawnWeight
		total += r.SpawnWeight
	end
	local pRare = (total - weights.Common) / total
	local pLegend = (weights.Legendary + weights.Mythic) / total
	print(string.format("  1re rare (ou mieux) : ~%.0f min", 1 / (pRare * anomaliesPerMinute)))
	print(string.format("  1re légendaire (ou mieux) : ~%.0f min", 1 / (pLegend * anomaliesPerMinute)))
end)

print(string.format("\n%d test(s) réussi(s), %d échec(s)", passed, failed))
if failed > 0 then
	error("des tests ont échoué")
end
