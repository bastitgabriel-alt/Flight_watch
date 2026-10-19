--!strict
-- Réception : fait arriver des clients au comptoir de chaque hôtel occupé.
-- Le propriétaire les inspecte puis choisit « Donner la clé » ou « Capturer ».
-- Le serveur garde secret qui est une anomalie et décide du résultat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Modules = Server:WaitForChild("Modules")

local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local GuestConfig = require(Config:WaitForChild("GuestConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local RigAppearance = require(Shared:WaitForChild("Util"):WaitForChild("RigAppearance"))
local GuestGenerator = require(Modules:WaitForChild("GuestGenerator"))
local IncomeCalculator = require(Modules:WaitForChild("IncomeCalculator"))
local Notify = require(Modules:WaitForChild("Notify"))
local RigFactory = require(Modules:WaitForChild("RigFactory"))
local CollisionGroups = require(Modules:WaitForChild("CollisionGroups"))
local RateLimiter = require(Server:WaitForChild("Util"):WaitForChild("RateLimiter"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local HotelService = require(script.Parent:WaitForChild("HotelService"))
local IncomeService = require(script.Parent:WaitForChild("IncomeService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- Distance max entre le joueur et le client pour décider (anti-triche)
local MAX_DECISION_DISTANCE = 30
local GUEST_WALK_SPEED = 12

type Guest = {
	token: number,
	profile: Types.GuestProfile,
	model: Model,
	state: "Arriving" | "Waiting" | "Decided",
	decision: string?,
}

type Session = {
	player: Player,
	hotel: Model,
	active: boolean,
	guest: Guest?,
	extraModels: { [Model]: boolean }, -- clients qui partent, anomalies qui errent
	forceNext: GuestGenerator.Options?, -- prochain client imposé (debug)
}

local GuestService = {}

local rng = Random.new()
local sessions: { [Player]: Session } = {}
local nextToken = 0
local promptLimiter = RateLimiter.new(3, 1)
local decisionLimiter = RateLimiter.new(4, 1)

local guestsFolder: Folder

local function getMarker(hotel: Model, name: string): BasePart
	local marker = hotel:FindFirstChild(name)
	assert(marker and marker:IsA("BasePart"), `Repère manquant dans {hotel.Name} : {name}`)
	return marker
end

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Fait marcher un personnage jusqu'à une position (avec délai max)
local function walkTo(model: Model, position: Vector3, timeout: number): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or not model.Parent then
		return false
	end
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(success)
		reached = success
	end)
	humanoid:MoveTo(position)
	local elapsed = 0
	while not reached and elapsed < timeout and model.Parent do
		elapsed += task.wait(0.1)
	end
	connection:Disconnect()
	return reached
end

local function destroyExtra(session: Session, model: Model)
	session.extraModels[model] = nil
	model:Destroy()
end

local function setAnchored(model: Model, anchored: boolean)
	local root = getRoot(model)
	if root then
		root.Anchored = anchored
	end
end

local function removePrompt(model: Model)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:Destroy()
	end
end

-- Crée le modèle du client avec ses indices visibles (yeux, ombre)
local function buildGuestModel(session: Session, profile: Types.GuestProfile): Model
	local rig = RigFactory.newRig()
	rig.Name = "Guest"
	RigAppearance.apply(rig, profile.Appearance)

	local eyes = profile.Clues.Eyes
	if eyes == "Strong" then
		RigAppearance.addGlowingEyes(rig, Color3.fromRGB(255, 40, 40), 0.28)
	elseif eyes == "Subtle" then
		RigAppearance.addGlowingEyes(rig, Color3.fromRGB(255, 170, 60), 0.12)
	end
	if profile.Clues.Shadow then
		RigAppearance.setCastShadow(rig, false)
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GUEST_WALK_SPEED
	end
	rig:SetAttribute("OwnerUserId", session.player.UserId)
	-- Les clients traversent la barrière de verrou
	CollisionGroups.assign(rig, CollisionGroups.GUESTS):Disconnect()

	RigAppearance.placeOnFloor(rig, getMarker(session.hotel, "GuestSpawn").CFrame)
	rig.Parent = guestsFolder

	-- Le serveur contrôle la physique du client (empêche les joueurs de le déplacer)
	local root = getRoot(rig)
	if root then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	return rig
end

-- Le client repart (vers l'extérieur, ou dans l'hôtel s'il a eu sa clé)
local function walkAway(session: Session, model: Model, intoHotel: boolean)
	removePrompt(model)
	setAnchored(model, false)
	session.extraModels[model] = true
	task.spawn(function()
		local spot = getMarker(session.hotel, "GuestSpot").CFrame
		if intoHotel then
			-- Contourne le comptoir puis entre dans l'hôtel
			walkTo(model, (spot * CFrame.new(10, 0, 0)).Position, 4)
			walkTo(model, (spot * CFrame.new(10, 0, -14)).Position, 4)
		else
			walkTo(model, getMarker(session.hotel, "GuestSpawn").Position, 5)
			walkTo(model, getMarker(session.hotel, "GuestExit").Position, 5)
		end
		if session.extraModels[model] then
			destroyExtra(session, model)
		end
	end)
end

-- Anomalie capturée : révèle sa vraie forme puis disparaît (elle part en cellule)
local function revealAndVanish(session: Session, model: Model, def: Types.AnomalyDef)
	removePrompt(model)
	session.extraModels[model] = true
	RigAppearance.apply(model, def.TrueForm)
	RigAppearance.addGlowingEyes(model, def.EyeColor, 0.28)
	RigAppearance.setCastShadow(model, false)
	task.spawn(function()
		task.wait(0.6)
		local info = TweenInfo.new(0.8)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
				TweenService:Create(descendant, info, { Transparency = 1 }):Play()
			elseif descendant:IsA("Decal") then
				TweenService:Create(descendant, info, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.9)
		if session.extraModels[model] then
			destroyExtra(session, model)
		end
	end)
end

-- Anomalie qui s'est infiltrée : elle erre dans le hall pendant la pénalité
local function startWanderer(session: Session, model: Model, def: Types.AnomalyDef)
	removePrompt(model)
	setAnchored(model, false)
	RigAppearance.addGlowingEyes(model, def.EyeColor, 0.28)
	session.extraModels[model] = true
	task.spawn(function()
		local lobby = getMarker(session.hotel, "Lobby")
		local spot = getMarker(session.hotel, "GuestSpot").CFrame
		walkTo(model, (spot * CFrame.new(10, 0, 0)).Position, 4)
		local endsAt = os.clock() + EconomyConfig.EscapedDuration
		while os.clock() < endsAt and session.active and model.Parent do
			local offset = Vector3.new(
				rng:NextNumber(-0.5, 0.5) * lobby.Size.X,
				0,
				rng:NextNumber(-0.5, 0.5) * lobby.Size.Z
			)
			walkTo(model, lobby.CFrame:PointToWorldSpace(offset), 4)
			task.wait(rng:NextNumber(0.5, 2))
		end
		if session.extraModels[model] then
			destroyExtra(session, model)
		end
	end)
end

local function clueList(profile: Types.GuestProfile): { { Type: string, Strength: string } }
	local list = {}
	for clueType, strength in profile.Clues do
		table.insert(list, { Type = clueType, Strength = strength })
	end
	table.sort(list, function(a, b)
		return a.Type < b.Type
	end)
	return list
end

-- Applique la décision (ou l'absence de décision) et prévient le joueur
local function resolve(session: Session, guest: Guest, decision: string)
	local player = session.player
	local profile = guest.profile
	local data = PlayerDataService.GetData(player)
	if not data then
		guest.model:Destroy()
		return
	end
	local income = IncomeService.GetIncome(player)
	local outcome: string
	local details: { [string]: any } = { Clues = clueList(profile), Amount = 0 }

	if profile.IsAnomaly then
		local def = AnomalyConfig.ById[profile.AnomalyId :: string]
		details.AnomalyName = def.DisplayName
		details.Rarity = def.Rarity
		details.Mutation = profile.Mutation

		if decision == "Capture" then
			data.Stats.Captures += 1
			local cell = AnomalyService.AddAnomaly(player, def.Id, profile.Mutation)
			if cell then
				outcome = "Captured"
			else
				outcome = "CapturedSold"
				local amount = IncomeCalculator.anomalyIncome(def.Id, profile.Mutation) * EconomyConfig.FullCellsSellSeconds
				details.Amount = amount
				PlayerDataService.AddMoney(player, amount)
			end
			revealAndVanish(session, guest.model, def)
		else
			outcome = "Escaped"
			data.Stats.Escaped += 1
			IncomeService.ApplyDebuff(player, EconomyConfig.EscapedIncomeMultiplier, EconomyConfig.EscapedDuration)
			startWanderer(session, guest.model, def)
		end
	else
		if decision == "Accept" then
			outcome = "Served"
			local tip = math.max(EconomyConfig.TipBase, math.floor(income * EconomyConfig.TipIncomeSeconds))
			details.Amount = tip
			data.Stats.GuestsServed += 1
			PlayerDataService.AddMoney(player, tip)
			walkAway(session, guest.model, true)
		elseif decision == "Capture" then
			outcome = "WrongCapture"
			local penalty = math.floor(EconomyConfig.WrongCaptureBase + income * EconomyConfig.WrongCaptureIncomeSeconds)
			penalty = math.min(penalty, PlayerDataService.GetMoney(player))
			details.Amount = penalty
			data.Stats.WrongCaptures += 1
			PlayerDataService.AddMoney(player, -penalty)
			walkAway(session, guest.model, false)
		else
			outcome = "Left"
			walkAway(session, guest.model, false)
		end
	end

	Remotes.getEvent("ReceptionResult"):FireClient(player, guest.token, outcome, details)
end

local function onPromptTriggered(session: Session, guest: Guest, player: Player, deadline: number)
	if player ~= session.player or guest.state ~= "Waiting" then
		return
	end
	if not promptLimiter:allow(player) then
		return
	end
	-- Résultats des outils : envoyés seulement si le joueur les a achetés
	local data = PlayerDataService.GetData(player)
	local tools = if data then data.Tools else {}
	local toolResults = {
		UV = if tools.UVLamp then guest.profile.Clues.UV ~= nil else nil,
		Thermal = if tools.ThermalScanner then guest.profile.Temperature else nil,
	}
	local info: Types.ReceptionInfo = {
		Token = guest.token,
		Name = guest.profile.Name,
		PhotoAppearance = guest.profile.PhotoAppearance,
		Registry = guest.profile.Registry,
		Deadline = deadline,
		Guest = guest.model,
		ToolResults = toolResults,
	}
	Remotes.getEvent("ReceptionShow"):FireClient(player, info)
end

-- Un client complet : arrivée, attente de la décision, résultat
local function serveOneGuest(session: Session)
	local options: GuestGenerator.Options = session.forceNext or {}
	session.forceNext = nil
	-- « Nuit chanceuse » (produit Robux) : anomalies rares plus fréquentes
	local data = PlayerDataService.GetData(session.player)
	if data and data.LuckyUntil > os.time() then
		options.RarityLuck = MonetizationConfig.Products.LuckyNight.RarityLuck
	end
	local profile = GuestGenerator.generate(rng, options)

	nextToken += 1
	local model = buildGuestModel(session, profile)
	local guest: Guest = {
		token = nextToken,
		profile = profile,
		model = model,
		state = "Arriving",
		decision = nil,
	}
	session.guest = guest

	local spot = getMarker(session.hotel, "GuestSpot")
	walkTo(model, spot.Position, 8)
	if not session.active or not model.Parent then
		return
	end
	-- Bien placé face au comptoir, et immobile
	RigAppearance.placeOnFloor(model, spot.CFrame)
	setAnchored(model, true)

	local deadline = workspace:GetServerTimeNow() + GuestConfig.Patience
	local root = getRoot(model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recevoir"
	prompt.ObjectText = profile.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OnlyUserId", session.player.UserId)
	prompt.Parent = root or model
	prompt.Triggered:Connect(function(player)
		onPromptTriggered(session, guest, player, deadline)
	end)

	guest.state = "Waiting"
	while guest.state == "Waiting" and session.active and workspace:GetServerTimeNow() < deadline do
		task.wait(0.2)
	end
	if not session.active then
		return
	end
	guest.state = "Decided"
	session.guest = nil
	resolve(session, guest, guest.decision or "Timeout")
end

local function runSession(session: Session)
	while session.active do
		task.wait(rng:NextNumber(GuestConfig.SpawnDelayMin, GuestConfig.SpawnDelayMax))
		if not session.active or session.player.Parent ~= Players then
			break
		end
		local ok, err = pcall(serveOneGuest, session)
		if not ok then
			warn(`[GuestService] Erreur client : {err}`)
			local guest = session.guest
			if guest then
				guest.model:Destroy()
				session.guest = nil
			end
			task.wait(2)
		end
	end
end

local function onDecision(player: Player, token: any, choice: any)
	-- Vérifications : types, fréquence, client attendu, distance
	if typeof(token) ~= "number" or (choice ~= "Accept" and choice ~= "Capture") then
		return
	end
	if not decisionLimiter:allow(player) then
		return
	end
	local session = sessions[player]
	local guest = session and session.guest
	if not session or not guest or guest.token ~= token or guest.state ~= "Waiting" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local spot = getMarker(session.hotel, "GuestSpot")
	if not root or not root:IsA("BasePart") or (root.Position - spot.Position).Magnitude > MAX_DECISION_DISTANCE then
		Notify.send(player, "Rapproche-toi du comptoir !", "Bad")
		return
	end
	guest.decision = choice
	guest.state = "Decided"
end

local function onHotelAssigned(player: Player, hotel: Model)
	local session: Session = {
		player = player,
		hotel = hotel,
		active = true,
		guest = nil,
		extraModels = {},
		forceNext = nil,
	}
	sessions[player] = session
	task.spawn(runSession, session)
end

local function onHotelReleased(player: Player, _hotel: Model)
	local session = sessions[player]
	if not session then
		return
	end
	session.active = false
	sessions[player] = nil
	if session.guest then
		session.guest.model:Destroy()
		session.guest = nil
	end
	for model in session.extraModels do
		model:Destroy()
	end
	table.clear(session.extraModels)
end

-- Debug : impose le prochain client (anomalie, vrai client, ou anomalie précise)
function GuestService.ForceNext(player: Player, options: GuestGenerator.Options)
	local session = sessions[player]
	if session then
		session.forceNext = options
	end
end

function GuestService.Init(_self: typeof(GuestService))
	local folder = Instance.new("Folder")
	folder.Name = "Guests"
	folder.Parent = workspace
	guestsFolder = folder

	HotelService.HotelAssigned:Connect(onHotelAssigned)
	HotelService.HotelReleased:Connect(onHotelReleased)
	Remotes.getEvent("ReceptionDecision").OnServerEvent:Connect(onDecision)
end

return GuestService
