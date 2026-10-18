--!strict
-- Gère les anomalies capturées : placement dans les cellules, modèles 3D
-- affichés dans l'hôtel, catalogue des anomalies découvertes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local Types = require(Shared:WaitForChild("Types"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local MutationConfig = require(Config:WaitForChild("MutationConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RigAppearance = require(Shared:WaitForChild("Util"):WaitForChild("RigAppearance"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local IncomeCalculator = require(Server:WaitForChild("Modules"):WaitForChild("IncomeCalculator"))
local RigFactory = require(Server:WaitForChild("Modules"):WaitForChild("RigFactory"))
local HotelService = require(script.Parent:WaitForChild("HotelService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local AnomalyService = {}

-- (player) : la liste des anomalies du joueur a changé (revenu à recalculer)
AnomalyService.AnomaliesChanged = Signal.new()

-- Modèles affichés : models[player][uid] = Model
local models: { [Player]: { [string]: Model } } = {}

local function getCell(hotel: Model, cellIndex: number): Model?
	local cells = hotel:FindFirstChild("Cells")
	local cell = cells and cells:FindFirstChild(`Cell{cellIndex}`)
	return if cell and cell:IsA("Model") then cell else nil
end

local function getCellLabel(cell: Model): TextLabel?
	local label = cell:FindFirstChild("Text", true)
	return if label and label:IsA("TextLabel") then label else nil
end

-- Nombre de cellules utilisables par le joueur
function AnomalyService.GetCellCapacity(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	-- Le gamepass « +3 cellules » s'ajoutera ici à l'étape 9
	return math.min(GameConfig.MaxCells, data.CellsUnlocked)
end

-- Premier numéro de cellule libre, ou nil si tout est plein
local function findFreeCell(data: any, capacity: number): number?
	local used: { [number]: boolean } = {}
	for _, owned in data.Anomalies do
		used[owned.Cell] = true
	end
	for index = 1, capacity do
		if not used[index] then
			return index
		end
	end
	return nil
end

-- Met à jour l'aspect des cellules vides / verrouillées
local function refreshCellVisuals(player: Player, hotel: Model)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	local capacity = AnomalyService.GetCellCapacity(player)
	local occupied: { [number]: boolean } = {}
	for _, owned in data.Anomalies do
		occupied[owned.Cell] = true
	end
	for index = 1, GameConfig.MaxCells do
		local cell = getCell(hotel, index)
		if cell then
			local pad = cell:FindFirstChild("Pad")
			local label = getCellLabel(cell)
			local unlocked = index <= capacity
			if pad and pad:IsA("BasePart") then
				pad.Color = if unlocked then Color3.fromRGB(70, 90, 110) else Color3.fromRGB(35, 35, 40)
			end
			if label and not occupied[index] then
				label.Text = if unlocked then "Cellule libre" else "🔒 Verrouillée"
				label.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
end

local function resetCellVisuals(hotel: Model)
	for index = 1, GameConfig.MaxCells do
		local cell = getCell(hotel, index)
		if cell then
			local label = getCellLabel(cell)
			if label then
				label.Text = ""
			end
			local pad = cell:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then
				pad.Color = Color3.fromRGB(60, 60, 70)
			end
		end
	end
end

-- Crée le modèle 3D de l'anomalie dans sa cellule (sa vraie forme)
local function spawnModel(player: Player, hotel: Model, uid: string, owned: Types.OwnedAnomaly)
	local def = AnomalyConfig.ById[owned.Id]
	local cell = getCell(hotel, owned.Cell)
	local spot = cell and cell:FindFirstChild("Spot")
	if not def or not cell or not spot or not spot:IsA("BasePart") then
		return
	end

	local rig = RigFactory.newRig()
	rig.Name = `Anomaly_{uid}`
	RigAppearance.apply(rig, def.TrueForm)
	local mutation = MutationConfig.Mutations[owned.Mutation]
	if mutation and mutation.Color and mutation.Material then
		RigAppearance.applyMaterial(rig, mutation.Color, mutation.Material)
	end
	RigAppearance.addGlowingEyes(rig, def.EyeColor, 0.25)
	RigAppearance.setCastShadow(rig, false)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	RigAppearance.placeOnFloor(rig, spot.CFrame)
	rig.Parent = cell

	-- Étiquette : nom, rareté, mutation, revenu
	local label = getCellLabel(cell)
	if label then
		local rarity = RarityConfig[def.Rarity]
		local income = IncomeCalculator.anomalyIncome(owned.Id, owned.Mutation)
		local mutationText = if owned.Mutation ~= "None" and mutation then ` [{mutation.DisplayName}]` else ""
		label.Text = `{def.DisplayName}{mutationText}\n{rarity.DisplayName} • {Format.money(income)}/s`
		label.TextColor3 = rarity.Color
	end

	local playerModels = models[player]
	if playerModels then
		playerModels[uid] = rig
	end
end

-- Vérifie les données au chargement : anomalies inconnues, cellules en double
local function repairData(player: Player, data: any)
	local capacity = AnomalyService.GetCellCapacity(player)
	local used: { [number]: boolean } = {}
	local toPlace: { any } = {}
	for uid, owned in data.Anomalies do
		if not AnomalyConfig.ById[owned.Id] then
			warn(`[AnomalyService] Anomalie inconnue retirée : {owned.Id}`)
			data.Anomalies[uid] = nil
		elseif owned.Cell < 1 or owned.Cell > capacity or used[owned.Cell] then
			table.insert(toPlace, owned)
		else
			used[owned.Cell] = true
		end
	end
	for _, owned in toPlace do
		owned.Cell = 0
		owned.Cell = findFreeCell(data, capacity) or 0
	end
end

local function onHotelAssigned(player: Player, hotel: Model)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	models[player] = {}
	repairData(player, data)
	refreshCellVisuals(player, hotel)
	for uid, owned in data.Anomalies do
		if owned.Cell > 0 then
			spawnModel(player, hotel, uid, owned)
		end
	end
	AnomalyService.AnomaliesChanged:Fire(player)
end

local function onHotelReleased(player: Player, hotel: Model)
	local playerModels = models[player]
	if playerModels then
		for _, model in playerModels do
			model:Destroy()
		end
	end
	models[player] = nil
	resetCellVisuals(hotel)
end

-- Ajoute une anomalie capturée. Renvoie le numéro de cellule, ou nil si
-- toutes les cellules sont pleines (l'anomalie n'est alors pas ajoutée).
function AnomalyService.AddAnomaly(player: Player, anomalyId: string, mutation: Types.MutationId): number?
	local data = PlayerDataService.GetData(player)
	local hotel = HotelService.GetHotel(player)
	if not data or not AnomalyConfig.ById[anomalyId] then
		return nil
	end
	-- Elle compte dans le catalogue même si elle ne rentre pas
	data.Discovered[anomalyId] = true

	local cellIndex = findFreeCell(data, AnomalyService.GetCellCapacity(player))
	if not cellIndex then
		return nil
	end

	-- Préfixe « a » : la clé reste du texte une fois sauvegardée
	local uid = `a{data.NextAnomalyUid}`
	data.NextAnomalyUid += 1
	local owned: Types.OwnedAnomaly = { Id = anomalyId, Mutation = mutation, Cell = cellIndex }
	data.Anomalies[uid] = owned

	if hotel then
		spawnModel(player, hotel, uid, owned)
	end
	AnomalyService.AnomaliesChanged:Fire(player)
	return cellIndex
end

function AnomalyService.Init(_self: typeof(AnomalyService))
	HotelService.HotelAssigned:Connect(onHotelAssigned)
	HotelService.HotelReleased:Connect(onHotelReleased)
end

return AnomalyService
