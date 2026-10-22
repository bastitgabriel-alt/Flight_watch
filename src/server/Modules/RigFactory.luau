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

-- La tête par défaut de Roblox est un modèle 3D téléchargé à part : s'il ne se
-- charge pas, les personnages apparaissent sans tête. On la remplace par la
-- tête classique de Roblox (intégrée au jeu, toujours disponible).
local function replaceHead(rig: Model)
	local oldHead = rig:FindFirstChild("Head")
	if not oldHead or not oldHead:IsA("BasePart") then
		return
	end
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(oldHead.Size.X, oldHead.Size.Y, oldHead.Size.Z)
	head.CFrame = oldHead.CFrame
	head.Color = oldHead.Color
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.05, 1, 1.05)
	mesh.Parent = head
	-- Articulation du cou, points d'attache, visage : déplacés sur la nouvelle tête
	for _, child in oldHead:GetChildren() do
		if child:IsA("Attachment") or child:IsA("JointInstance") or child:IsA("Decal") then
			child.Parent = head
		end
	end
	for _, joint in rig:GetDescendants() do
		if joint:IsA("JointInstance") then
			if joint.Part0 == oldHead then
				joint.Part0 = head
			end
			if joint.Part1 == oldHead then
				joint.Part1 = head
			end
		end
	end
	local face = head:FindFirstChildWhichIsA("Decal")
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end
	face.Texture = "rbxasset://textures/face.png" -- visage classique, intégré au jeu
	oldHead:Destroy()
	head.Parent = rig
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

	replaceHead(rig)

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
