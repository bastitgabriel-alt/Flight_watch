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

local S = __load(__readfile("tests/stubs.luau"), "tests/stubs.luau", setmetatable({}, { __index = _G }))()

local shared = makeNode(ROOT .. "/shared", "Shared")
local server = makeNode(ROOT .. "/server", "Server")
local services = {
	ReplicatedStorage = setmetatable({}, { __index = function(_, k) return k == "Shared" and shared or nil end }),
	ServerScriptService = setmetatable({}, { __index = function(_, k) return k == "Server" and server or nil end }),
	RunService = { IsServer = function() return true end, IsStudio = function() return true end },
	Lighting = S.Lighting,
	Workspace = S.workspace,
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
			Vector3 = S.Vector3, CFrame = S.CFrame, Instance = S.Instance, Enum = S.Enum,
			UDim2 = S.UDim2, UDim = S.UDim, workspace = S.workspace,
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
	local anomalies, total, hidden = 0, 20000, 0
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
			assert(g.Temperature > 36 and g.Temperature < 38, "vrai client glacé")
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
				if clue == "UV" or clue == "Thermal" then
					hidden += 1
				else
					n += 1
					assert(table.find(def.Clues, clue), "indice non autorisé")
				end
			end
			if g.Clues.Thermal then
				assert(g.Temperature < 20, "anomalie glacée trop chaude")
			else
				assert(g.Temperature > 36, "température anormale sans indice")
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
	print(string.format("  Indices cachés (UV/thermique) : %.1f %% des anomalies", hidden / anomalies * 100))
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


------------------------------------------------------------------ géométrie de la carte
local MapBuilder = robloxRequire(server.Modules.MapBuilder)
local ReceptionCamera = robloxRequire(shared.Util.ReceptionCamera)
local GameConfig = robloxRequire(Config.GameConfig)
local V = S.Vector3
local map = MapBuilder.build()
local hotels = map.Hotels:GetChildren()
local ROOT_HEIGHT = 3 -- hauteur du HumanoidRootPart d'un R15 au-dessus du sol
local VERTICAL_HALF_FOV = math.tan(math.rad(35)) -- champ de vision vertical Roblox : 70°
local HORIZONTAL_HALF_FOV = VERTICAL_HALF_FOV * 16 / 9
-- Le panneau de réception couvre les 42 % de droite de l'écran
local PANEL_LEFT_EDGE = HORIZONTAL_HALF_FOV * (1 - 2 * 0.42)

-- Pièces opaques et solides d'un hôtel (hors sol)
local function solids(hotel)
	local list = {}
	for _, d in hotel:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Floor" and d.CanCollide ~= false and d.Transparency < 0.7 then
			table.insert(list, d)
		end
	end
	return list
end
local function visibleParts(hotel)
	local list = {}
	for _, d in hotel:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Floor" and d.Transparency < 0.7 then
			table.insert(list, d)
		end
	end
	return list
end
local function noHit(a, b, parts, what)
	local hit = S.segmentHits(a, b, parts)
	assert(hit == nil, what .. " bloqué par " .. tostring(hit and hit.Name))
end

test("Carte : 6 hôtels complets", function()
	eq(#hotels, GameConfig.HotelCount, "hôtels")
	for _, hotel in hotels do
		for _, name in { "GuestSpawn", "GuestSpot", "GuestExit", "OwnerSpawn", "Lobby", "DoorBarrier", "Sign", "Counter", "Floor" } do
			assert(hotel:FindFirstChild(name), hotel.Name .. " : " .. name .. " manquant")
		end
		eq(#hotel.Cells:GetChildren(), GameConfig.MaxCells, "cellules")
	end
end)

test("Carte : hôtels et cellules ne se chevauchent pas", function()
	for i, a in hotels do
		for j, b in hotels do
			if i < j then
				assert((a.Floor.Position - b.Floor.Position).Magnitude > 56, "hôtels trop proches")
			end
		end
		local pads = {}
		for _, cell in a.Cells:GetChildren() do
			local pad = cell.Pad
			assert(S.pointInPart(pad.Position - V.new(0, 0.7, 0), a.Floor), cell.Name .. " hors de l'hôtel")
			for _, other in pads do
				assert((other.Position - pad.Position).Magnitude >= 6, cell.Name .. " chevauche une autre cellule")
			end
			table.insert(pads, pad)
		end
	end
end)

test("Panneau du classement : sur la place, loin des hôtels", function()
	local board = map.Leaderboard
	assert(board, "panneau manquant")
	assert(S.pointInPart(board.Position - V.new(0, 8.5, 0), map.Plaza, 0.5), "panneau hors de la place")
	for _, hotel in hotels do
		assert((hotel.Floor.Position - board.Position).Magnitude > 50, "panneau trop près de " .. hotel.Name)
	end
	assert((map.PlazaSpawn.Position - board.Position).Magnitude > 30, "panneau sur le point d'apparition")
end)

test("Réception : la caméra voit le client en entier, à gauche du panneau", function()
	for _, hotel in hotels do
		local root = hotel.GuestSpot.CFrame + V.new(0, ROOT_HEIGHT, 0)
		local eye, target = ReceptionCamera.compute(root)
		for _, part in solids(hotel) do
			assert(not S.pointInPart(eye, part, 0.5), "caméra dans " .. part.Name)
		end
		local head = root.Position + V.new(0, 1.8, 0)
		local feet = root.Position - V.new(0, ROOT_HEIGHT - 0.2, 0)
		local shadow = feet + root.RightVector * 1.5
		local parts = visibleParts(hotel)
		noHit(eye, head, parts, "vue de la tête")
		noHit(eye, feet, parts, "vue des pieds")
		noHit(eye, shadow, parts, "vue de l'ombre")
		local cam = S.CFrame.lookAt(eye, target)
		for label, point in { tete = head, pieds = feet } do
			local l = cam:PointToObjectSpace(point)
			assert(l.Z < 0, label .. " derrière la caméra")
			local sx, sy = l.X / -l.Z, l.Y / -l.Z
			assert(math.abs(sy) < VERTICAL_HALF_FOV, label .. " hors écran (vertical)")
			assert(sx > -HORIZONTAL_HALF_FOV and sx < PANEL_LEFT_EDGE, label .. " caché par le panneau ou hors écran")
		end
	end
end)

test("Chemins des clients et du propriétaire dégagés", function()
	for _, hotel in hotels do
		local up = V.new(0, ROOT_HEIGHT, 0)
		local parts = solids(hotel)
		local spot = hotel.GuestSpot.CFrame
		noHit(hotel.GuestSpawn.Position + up, spot.Position + up, parts, "arrivée du client")
		local side = (spot * S.CFrame.new(10, 0, 0)).Position + up
		local inside = (spot * S.CFrame.new(10, 0, -14)).Position + up
		noHit(spot.Position + up, side, parts, "entrée (1)")
		noHit(side, inside, parts, "entrée (2)")
		noHit(hotel.GuestSpawn.Position + up, hotel.GuestExit.Position + up, parts, "sortie")
		local owner = hotel.OwnerSpawn.Position + up
		for _, part in parts do
			assert(not S.pointInPart(owner, part), "apparition du propriétaire dans " .. part.Name)
		end
		assert((owner - (spot.Position + up)).Magnitude < 14, "propriétaire trop loin pour « Recevoir »")
		-- La zone d'errance ne touche ni le comptoir ni les cellules
		local lobby = hotel.Lobby
		for _, sx in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				local corner = lobby.CFrame * V.new(sx * lobby.Size.X, 2, sz * lobby.Size.Z)
				for _, part in parts do
					assert(not S.pointInPart(corner, part), "zone d'errance dans " .. part.Name)
				end
			end
		end
	end
end)

test("Décor de la place : loin des hôtels, du spawn et du classement", function()
	local spawnPos = map.PlazaSpawn.Position + V.new(0, ROOT_HEIGHT, 0)
	for _, part in map.Decor:GetChildren() do
		assert(not S.pointInPart(spawnPos, part, 3), "apparition dans " .. part.Name)
		assert((part.Position - map.Leaderboard.Position).Magnitude > 12, part.Name .. " devant le classement")
		for _, hotel in hotels do
			local p = part.Position
			p = V.new(p.X, hotel.Floor.Position.Y + 2, p.Z)
			assert(not S.pointInPart(p, hotel.Floor, 6), part.Name .. " dans " .. hotel.Name)
		end
	end
	assert(#map.Decor:GetChildren() > 20, "décor manquant")
end)

print(string.format("\n%d test(s) réussi(s), %d échec(s)", passed, failed))
if failed > 0 then
	error("des tests ont échoué")
end
