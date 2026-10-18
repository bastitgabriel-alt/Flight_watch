--!strict
-- Applique des couleurs à un personnage R15 placeholder.
-- Utilisé par le serveur (clients, anomalies) et le client (photo d'identité).

local Types = require(script.Parent.Parent.Types)

local SKIN_PARTS = { "Head", "LeftHand", "RightHand" }
local SHIRT_PARTS = {
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
}
local PANTS_PARTS = {
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local RigAppearance = {}

local function paint(rig: Model, partNames: { string }, color: Color3)
	for _, name in partNames do
		local part = rig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

function RigAppearance.apply(rig: Model, appearance: Types.Appearance)
	paint(rig, SKIN_PARTS, appearance.Skin)
	paint(rig, SHIRT_PARTS, appearance.Shirt)
	paint(rig, PANTS_PARTS, appearance.Pants)
end

-- Ajoute deux yeux lumineux sur la tête (indice « yeux anormaux »).
-- size : taille des yeux en studs (petit = indice discret)
function RigAppearance.addGlowingEyes(rig: Model, color: Color3, size: number)
	local head = rig:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "AnomalyEye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(size, size, size)
		eye.Material = Enum.Material.Neon
		eye.Color = color
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CastShadow = false
		-- L'avant de la tête est le côté -Z (LookVector)
		eye.CFrame = head.CFrame * CFrame.new(side * head.Size.X * 0.18, head.Size.Y * 0.1, -head.Size.Z * 0.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = rig
	end
end

-- Active ou désactive l'ombre de toutes les pièces (indice « pas d'ombre »)
function RigAppearance.setCastShadow(rig: Model, enabled: boolean)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = enabled
		end
	end
end

-- Couleur + matériau uniformes (mutations Dorée, Néon...)
function RigAppearance.applyMaterial(rig: Model, color: Color3, materialName: string)
	local ok, material = pcall(function()
		return (Enum.Material :: any)[materialName]
	end)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "AnomalyEye" then
			descendant.Color = color
			if ok and material then
				descendant.Material = material
			end
		end
	end
end

-- Place un modèle debout sur une surface : ses pieds touchent floorCFrame.
function RigAppearance.placeOnFloor(rig: Model, floorCFrame: CFrame)
	rig:PivotTo(floorCFrame)
	local boxCFrame, boxSize = rig:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	rig:PivotTo(floorCFrame + Vector3.new(0, floorCFrame.Position.Y - bottom, 0))
end

return RigAppearance
