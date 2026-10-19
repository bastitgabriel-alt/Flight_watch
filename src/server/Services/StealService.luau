--!strict
-- Vol entre joueurs : un voleur prend une anomalie dans la cellule d'un autre,
-- la porte au-dessus de sa tête (vitesse réduite) et doit rejoindre son hôtel.
-- Le propriétaire peut la récupérer en touchant le voleur (invite « Récupérer »).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local ShopConfig = require(Config:WaitForChild("ShopConfig"))
local Notify = require(Server:WaitForChild("Modules"):WaitForChild("Notify"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local HotelService = require(script.Parent:WaitForChild("HotelService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local NORMAL_WALK_SPEED = 16
local MAX_START_DISTANCE = 16

type Steal = {
	thief: Player,
	owner: Player,
	uid: string,
	anomalyId: string,
	carried: Model,
	startedAt: number,
	diedConnection: RBXScriptConnection?,
}

local StealService = {}

local stealsByThief: { [Player]: Steal } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function isUidBeingStolen(owner: Player, uid: string): boolean
	for _, steal in stealsByThief do
		if steal.owner == owner and steal.uid == uid then
			return true
		end
	end
	return false
end

-- Le voleur est-il dans son propre hôtel ?
local function isInsideOwnHotel(thief: Player, root: BasePart): boolean
	local hotel = HotelService.GetHotel(thief)
	local floor = hotel and hotel:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		return false
	end
	local localPos = floor.CFrame:PointToObjectSpace(root.Position)
	return math.abs(localPos.X) < floor.Size.X / 2 and math.abs(localPos.Z) < floor.Size.Z / 2 and localPos.Y < 25
end

-- Termine un vol. success = l'anomalie change de propriétaire.
local function finish(steal: Steal, success: boolean, reason: string?)
	if stealsByThief[steal.thief] ~= steal then
		return
	end
	stealsByThief[steal.thief] = nil
	steal.carried:Destroy()
	if steal.diedConnection then
		steal.diedConnection:Disconnect()
	end
	if steal.thief.Parent == Players then
		setWalkSpeed(steal.thief, NORMAL_WALK_SPEED)
	end

	local def = AnomalyConfig.ById[steal.anomalyId]
	local name = if def then def.DisplayName else "l'anomalie"

	if success then
		local owned = AnomalyService.RemoveAnomaly(steal.owner, steal.uid)
		if owned and AnomalyService.AddAnomaly(steal.thief, owned.Id, owned.Mutation) then
			local thiefData = PlayerDataService.GetData(steal.thief)
			local ownerData = PlayerDataService.GetData(steal.owner)
			if thiefData then
				thiefData.Stats.StealsSucceeded += 1
			end
			if ownerData then
				ownerData.Stats.StealsSuffered += 1
			end
			Notify.send(steal.thief, `Vol réussi : {name} est à toi !`, "Good")
			Notify.send(steal.owner, `{steal.thief.DisplayName} t'a volé {name} !`, "Bad")
			return
		elseif owned then
			-- Impossible de l'ajouter au voleur (cellules pleines) : on la rend
			local ownerData = PlayerDataService.GetData(steal.owner)
			if ownerData then
				ownerData.Anomalies[steal.uid] = owned
				AnomalyService.ShowModel(steal.owner, steal.uid)
				AnomalyService.AnomaliesChanged:Fire(steal.owner)
			end
			Notify.send(steal.thief, "Tes cellules sont pleines, l'anomalie s'échappe !", "Bad")
			return
		end
	end

	-- Échec : l'anomalie retourne dans sa cellule
	if steal.owner.Parent == Players then
		AnomalyService.ShowModel(steal.owner, steal.uid)
		if reason then
			Notify.send(steal.owner, reason, "Good")
		end
	end
	if steal.thief.Parent == Players then
		Notify.send(steal.thief, `Vol raté : {name} est retournée dans sa cellule`, "Bad")
	end
end

-- Copie de l'anomalie portée au-dessus de la tête du voleur
local function buildCarried(steal: Steal, root: BasePart): Model
	local owned = AnomalyService.GetOwned(steal.owner, steal.uid)
	assert(owned, "anomalie introuvable")
	local rig = AnomalyService.BuildRig(owned.Id, owned.Mutation)
	rig.Name = "CarriedAnomaly"
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy() -- simple objet porté, pas un personnage
	end
	rig:ScaleTo(0.6)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = true
		end
	end
	local rigRoot = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	rig:PivotTo(root.CFrame * CFrame.new(0, 5, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = rigRoot
	weld.Parent = rigRoot

	-- Seul le propriétaire voit l'invite « Récupérer »
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Récupérer"
	prompt.ObjectText = steal.thief.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OnlyUserId", steal.owner.UserId)
	prompt.Triggered:Connect(function(player)
		if player == steal.owner then
			finish(steal, false, "Tu as récupéré ton anomalie !")
		end
	end)
	prompt.Parent = rigRoot

	rig.Parent = root.Parent
	return rig
end

local function tryStart(thief: Player, owner: Player, uid: string)
	if thief == owner or stealsByThief[thief] or thief.Parent ~= Players or owner.Parent ~= Players then
		return
	end
	local owned = AnomalyService.GetOwned(owner, uid)
	local model = AnomalyService.GetModel(owner, uid)
	local root = getRoot(thief)
	if not owned or not model or not root or isUidBeingStolen(owner, uid) then
		return
	end
	if not HotelService.GetHotel(thief) then
		return
	end
	if (model:GetPivot().Position - root.Position).Magnitude > MAX_START_DISTANCE then
		return
	end
	if not AnomalyService.HasFreeCell(thief) then
		Notify.send(thief, "Tes cellules sont pleines : achète-en une à la boutique !", "Bad")
		return
	end

	local steal: Steal = {
		thief = thief,
		owner = owner,
		uid = uid,
		anomalyId = owned.Id,
		carried = (nil :: any) :: Model,
		startedAt = os.clock(),
		diedConnection = nil,
	}
	steal.carried = buildCarried(steal, root)
	stealsByThief[thief] = steal
	AnomalyService.HideModel(owner, uid)

	local ownerData = PlayerDataService.GetData(owner)
	local trapLevel = if ownerData then ownerData.SecurityUpgrades.SlowTrap or 0 else 0
	setWalkSpeed(thief, ShopConfig.carrySpeed(trapLevel))

	local humanoid = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		steal.diedConnection = humanoid.Died:Connect(function()
			finish(steal, false, nil)
		end)
	end

	local def = AnomalyConfig.ById[owned.Id]
	Notify.send(owner, `ALERTE : {thief.DisplayName} vole {def.DisplayName} ! Rattrape-le !`, "Bad")
	Notify.send(thief, "Ramène-la dans ton hôtel !", "Info")
end

function StealService.Init(_self: typeof(StealService))
	AnomalyService.StealRequested:Connect(tryStart)

	Players.PlayerRemoving:Connect(function(player)
		for _, steal in table.clone(stealsByThief) do
			if steal.thief == player or steal.owner == player then
				finish(steal, false, nil)
			end
		end
	end)
end

function StealService.Start(_self: typeof(StealService))
	-- Vérifie régulièrement : arrivée à l'hôtel, délai dépassé, personnage disparu
	while true do
		task.wait(0.25)
		for _, steal in table.clone(stealsByThief) do
			local root = getRoot(steal.thief)
			if not root or not steal.carried.Parent then
				finish(steal, false, nil)
			elseif isInsideOwnHotel(steal.thief, root) then
				finish(steal, true, nil)
			elseif os.clock() - steal.startedAt > ShopConfig.Steal.Timeout then
				finish(steal, false, "Le voleur a mis trop de temps, ton anomalie est revenue.")
			end
		end
	end
end

return StealService
