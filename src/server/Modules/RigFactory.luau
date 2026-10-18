--!strict
-- Fournit le personnage R15 placeholder utilisé pour les clients et anomalies.
-- Le modèle de base est créé une fois, puis placé dans
-- ReplicatedStorage.Assets.GuestRig (le client s'en sert pour les photos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RigFactory = {}

local template: Model? = nil

local function getAssetsFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Assets"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function createTemplate(): Model
	-- Un modèle déjà présent (fait à la main) est prioritaire
	local existing = getAssetsFolder():FindFirstChild("GuestRig")
	if existing and existing:IsA("Model") then
		return existing
	end

	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		error(`[RigFactory] Impossible de créer le personnage R15 : {result}`)
	end
	local rig = result :: Model
	rig.Name = "GuestRig"

	-- On retire scripts et vêtements : couleurs pilotées par RigAppearance
	for _, descendant in rig:GetDescendants() do
		if
			descendant:IsA("BaseScript")
			or descendant:IsA("BodyColors")
			or descendant:IsA("Clothing")
			or descendant:IsA("ShirtGraphic")
		then
			descendant:Destroy()
		end
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	rig.Parent = getAssetsFolder()
	return rig
end

-- Renvoie une copie neuve du personnage de base (peut attendre au 1er appel)
local creating = false

function RigFactory.newRig(): Model
	-- Si un autre thread est déjà en train de le créer, on attend
	while creating do
		task.wait()
	end
	if not template then
		creating = true
		local ok, result = pcall(createTemplate)
		creating = false
		if not ok then
			error(result)
		end
		template = result
	end
	return (template :: Model):Clone()
end

return RigFactory
