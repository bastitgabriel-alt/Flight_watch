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
local ShopConfig = require(Config:WaitForChild("ShopConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RigAppearance = require(Shared:WaitForChild("Util"):WaitForChild("RigAppearance"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local IncomeCalculator = require(Server:WaitForChild("Modules"):WaitForChild("IncomeCalculator"))
local RigFactory = require(Server:WaitForChild("Modules"):WaitForChild("RigFactory"))
local AnomalyLooks = require(Server:WaitForChild("Modules"):WaitForChild("AnomalyLooks"))
local HotelService = require(script.Parent:WaitForChild("HotelService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local AnomalyService = {}

-- (player) : la liste des anomalies du joueur a changé (revenu à recalculer)
AnomalyService.AnomaliesChanged = Signal.new()
-- (player, anomalyId) : première capture de cette anomalie (catalogue)
AnomalyService.Discovered = Signal.new()
-- (thief, owner, uid) : un joueur a activé « Voler » sur une anomalie
AnomalyService.StealRequested = Signal.new()

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
	-- Bonus du gamepass « +3 cellules » (attribut posé par MonetizationService)
	local bonus = if player:GetAttribute("Pass_ExtraCells") then MonetizationConfig.GamePasses.ExtraCells.Cells else 0
	return math.min(GameConfig.MaxCells, data.CellsUnlocked + bonus)
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

-- Liseré autour du pad : couleur de la rareté (néon) ou éteint
local function setTrim(cell: Model, color: Color3, glowing: boolean)
	local trims = cell:FindFirstChild("Trim")
	if not trims then
		return
	end
	for _, strip in trims:GetChildren() do
		if strip:IsA("BasePart") then
			strip.Color = color
			strip.Material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
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
			if not occupied[index] then
				if label then
					label.Text = if unlocked then "Cellule libre" else "🔒 Verrouillée"
					label.TextColor3 = Color3.new(1, 1, 1)
				end
				setTrim(cell, if unlocked then Color3.fromRGB(60, 80, 110) else Color3.fromRGB(30, 30, 35), false)
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
			setTrim(cell, Color3.fromRGB(40, 40, 50), false)
		end
	end
end

-- Lueur de la couleur de la rareté ; particules à partir d'Épique
local SPARKLING_RARITIES: { [string]: boolean } = { Epic = true, Legendary = true, Mythic = true, Secret = true }

local function addAura(rig: Model, rarityId: Types.RarityId)
	local root = rig:FindFirstChild("HumanoidRootPart")
	local rarity = RarityConfig[rarityId]
	if not root or not rarity then
		return
	end
	local color: Color3 = rarity.Color
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if SPARKLING_RARITIES[rarityId] then 10 else 6
	light.Brightness = if SPARKLING_RARITIES[rarityId] then 1.2 else 0.5
	light.Shadows = false
	light.Parent = root
	if SPARKLING_RARITIES[rarityId] then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Aura"
		sparkles.Color = ColorSequence.new(color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency = NumberSequence.new(0.2, 1)
		sparkles.Lifetime = NumberRange.new(1, 2)
		sparkles.Rate = if rarityId == "Epic" then 6 else 14
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = root
	end
end

-- Personnage de l'anomalie sous sa vraie forme (couleurs, mutation, yeux)
function AnomalyService.BuildRig(anomalyId: string, mutationId: Types.MutationId): Model
	local def = AnomalyConfig.ById[anomalyId]
	local rig = RigFactory.newRig()
	RigAppearance.apply(rig, def.TrueForm)
	if def.Scale and def.Scale ~= 1 then
		rig:ScaleTo(def.Scale)
	end
	AnomalyLooks.apply(rig, def.Look, def.TrueForm, def.EyeColor)
	local mutation = MutationConfig.Mutations[mutationId]
	if mutation and mutation.Color and mutation.Material then
		RigAppearance.applyMaterial(rig, mutation.Color, mutation.Material)
	end
	RigAppearance.addGlowingEyes(rig, def.EyeColor, 0.25)
	RigAppearance.setCastShadow(rig, false)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	addAura(rig, def.Rarity)
	return rig
end

-- Crée le modèle 3D de l'anomalie dans sa cellule (sa vraie forme)
local function spawnModel(player: Player, hotel: Model, uid: string, owned: Types.OwnedAnomaly)
	local def = AnomalyConfig.ById[owned.Id]
	local cell = getCell(hotel, owned.Cell)
	local spot = cell and cell:FindFirstChild("Spot")
	if not def or not cell or not spot or not spot:IsA("BasePart") then
		return
	end

	local rig = AnomalyService.BuildRig(owned.Id, owned.Mutation)
	rig.Name = `Anomaly_{uid}`
	-- Seul le tronc est ancré : les membres restent libres pour l'animation
	local rigRoot = rig:FindFirstChild("HumanoidRootPart")
	if rigRoot and rigRoot:IsA("BasePart") then
		rigRoot.Anchored = true
	end
	RigAppearance.placeOnFloor(rig, spot.CFrame)
	rig:SetAttribute("Motion", def.Motion or "Creepy") -- animé par RigMotionController (client)
	rig.Parent = cell

	-- Invite « Voler », visible seulement des autres joueurs (voir PromptController)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Voler"
		prompt.ObjectText = def.DisplayName
		prompt.HoldDuration = ShopConfig.Steal.HoldDuration
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ExceptUserId", player.UserId)
		prompt.Triggered:Connect(function(thief)
			AnomalyService.StealRequested:Fire(thief, player, uid)
		end)
		prompt.Parent = root
	end

	-- Étiquette : nom, rareté, mutation, revenu
	local label = getCellLabel(cell)
	if label then
		local rarity = RarityConfig[def.Rarity]
		local income = IncomeCalculator.anomalyIncome(owned.Id, owned.Mutation)
		local mutation = MutationConfig.Mutations[owned.Mutation]
		local mutationText = if owned.Mutation ~= "None" and mutation then ` [{mutation.DisplayName}]` else ""
		label.Text = `{def.DisplayName}{mutationText}\n{rarity.DisplayName} • {Format.money(income)}/s`
		label.TextColor3 = rarity.Color
	end
	setTrim(cell, RarityConfig[def.Rarity].Color, true)

	local playerModels = models[player]
	if playerModels then
		playerModels[uid] = rig
	end
end

-- Vérifie les données au chargement : anomalies inconnues, cellules en double
local function repairData(player: Player, data: any)
	-- Limite absolue (et pas la capacité actuelle) : la vérification du gamepass
	-- « +3 cellules » peut arriver après, il ne faut pas déplacer ces anomalies
	local capacity = GameConfig.MaxCells
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
		owned.Cell = findFreeCell(data, AnomalyService.GetCellCapacity(player)) or 0
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
	if not data.Discovered[anomalyId] then
		data.Discovered[anomalyId] = true
		AnomalyService.Discovered:Fire(player, anomalyId)
	end

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

-- Anomalie possédée (ou nil)
function AnomalyService.GetOwned(player: Player, uid: string): Types.OwnedAnomaly?
	local data = PlayerDataService.GetData(player)
	return if data then data.Anomalies[uid] else nil
end

function AnomalyService.HasFreeCell(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	return data ~= nil and findFreeCell(data, AnomalyService.GetCellCapacity(player)) ~= nil
end

-- Modèle 3D de l'anomalie dans sa cellule (ou nil)
function AnomalyService.GetModel(player: Player, uid: string): Model?
	local playerModels = models[player]
	return if playerModels then playerModels[uid] else nil
end

-- Retire le modèle de la cellule (pendant un vol) sans toucher aux données
function AnomalyService.HideModel(player: Player, uid: string)
	local playerModels = models[player]
	local model = playerModels and playerModels[uid]
	if model and playerModels then
		model:Destroy()
		playerModels[uid] = nil
	end
end

-- Remet le modèle dans sa cellule (vol raté)
function AnomalyService.ShowModel(player: Player, uid: string)
	local owned = AnomalyService.GetOwned(player, uid)
	local hotel = HotelService.GetHotel(player)
	if owned and hotel and owned.Cell > 0 and not AnomalyService.GetModel(player, uid) then
		spawnModel(player, hotel, uid, owned)
	end
end

-- Supprime définitivement une anomalie (vol réussi). Renvoie ce qui a été retiré.
function AnomalyService.RemoveAnomaly(player: Player, uid: string): Types.OwnedAnomaly?
	local data = PlayerDataService.GetData(player)
	local owned = data and data.Anomalies[uid]
	if not data or not owned then
		return nil
	end
	AnomalyService.HideModel(player, uid)
	data.Anomalies[uid] = nil
	local hotel = HotelService.GetHotel(player)
	if hotel then
		refreshCellVisuals(player, hotel)
	end
	AnomalyService.AnomaliesChanged:Fire(player)
	return owned
end

-- Retire toutes les anomalies du joueur (renaissance)
function AnomalyService.ClearAll(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	for uid in data.Anomalies do
		AnomalyService.HideModel(player, uid)
	end
	table.clear(data.Anomalies)
	local hotel = HotelService.GetHotel(player)
	if hotel then
		refreshCellVisuals(player, hotel)
	end
	AnomalyService.AnomaliesChanged:Fire(player)
end

-- Rafraîchit l'aspect des cellules (après l'achat d'une cellule)
function AnomalyService.RefreshCells(player: Player)
	local hotel = HotelService.GetHotel(player)
	if hotel then
		refreshCellVisuals(player, hotel)
	end
end

function AnomalyService.Init(_self: typeof(AnomalyService))
	HotelService.HotelAssigned:Connect(onHotelAssigned)
	HotelService.HotelReleased:Connect(onHotelReleased)
end

return AnomalyService
