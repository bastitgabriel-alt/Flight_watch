--!strict
-- Forme monstrueuse des anomalies dans leur cellule : chapeaux, voile, bras trop
-- longs, tête à l'envers... Chaque anomalie liste ses « traits » dans
-- AnomalyConfig (champ Look). Les pièces ajoutées sont soudées au corps :
-- elles suivent les animations et ne gênent personne (ni collision ni clic).

local AnomalyLooks = {}

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local rgb = Color3.fromRGB

type Context = {
	rig: Model,
	skin: Color3,
	shirt: Color3,
	eye: Color3,
}

local function bodyPart(rig: Model, name: string): BasePart?
	local part = rig:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Pièce décorative soudée à `base`, placée à `cframe` (repère du monde)
local function attach(ctx: Context, base: BasePart, props: { [string]: any }, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = "LookPart"
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = ctx.rig
	return part
end

-- Cylindre debout (les cylindres Roblox sont couchés sur l'axe X)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cylinderSize(height: number, diameter: number): Vector3
	return Vector3.new(height, diameter, diameter)
end

-- Bas des pieds (pour que robes et bras ne passent pas sous le sol)
local function feetBottom(rig: Model): number
	local foot = bodyPart(rig, "LeftFoot")
	if foot then
		return foot.Position.Y - foot.Size.Y / 2
	end
	local cf, size = rig:GetBoundingBox()
	return cf.Position.Y - size.Y / 2
end

local function smoke(parent: BasePart, color: Color3, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LookSmoke"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Acceleration = Vector3.new(0, 0.6, 0)
	emitter.Parent = parent
end

local function removeFace(rig: Model)
	local head = bodyPart(rig, "Head")
	local face = head and head:FindFirstChildWhichIsA("Decal")
	if face then
		face:Destroy()
	end
end

-- Repère de la tête : avant = -Z
local function headFrame(head: BasePart): (CFrame, Vector3)
	return head.CFrame, head.Size
end

local Traits: { [string]: (ctx: Context) -> () } = {}

-- Pas de visage du tout
function Traits.Faceless(ctx: Context)
	removeFace(ctx.rig)
end

-- Deux yeux de plus, sur le front
function Traits.ExtraEyes(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local cf, size = headFrame(head)
	for _, offset in { Vector3.new(-0.12, 0.32, -0.5), Vector3.new(0.12, 0.32, -0.5), Vector3.new(0, -0.18, -0.5) } do
		local d = size.X * 0.13
		attach(ctx, head, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			Material = Enum.Material.Neon,
			Color = ctx.eye,
		}, cf * CFrame.new(offset.X * size.X, offset.Y * size.Y, offset.Z * size.Z))
	end
end

-- Sourire immense qui monte jusqu'aux joues
function Traits.Smile(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	removeFace(ctx.rig)
	local cf, size = headFrame(head)
	for i = -4, 4 do
		local x = i * 0.1 * size.X
		local y = (-0.22 + 0.014 * i * i) * size.Y
		local tooth = attach(ctx, head, {
			Size = Vector3.new(0.09 * size.X, 0.1 * size.Y, 0.05),
			Material = Enum.Material.Neon,
			Color = rgb(255, 250, 240),
		}, cf * CFrame.new(x, y, -size.Z * 0.5) * CFrame.Angles(0, 0, math.rad(i * 6)))
		tooth.Name = "Tooth"
	end
	attach(ctx, head, {
		Size = Vector3.new(0.85 * size.X, 0.16 * size.Y, 0.04),
		Material = Enum.Material.SmoothPlastic,
		Color = rgb(60, 0, 10),
	}, cf * CFrame.new(0, -0.17 * size.Y, -size.Z * 0.49))
end

-- Haut-de-forme
function Traits.TopHat(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	local w = head.Size.X
	attach(ctx, head, {
		Shape = Enum.PartType.Cylinder,
		Size = cylinderSize(0.08, w * 1.5),
		Color = rgb(20, 20, 22),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(0, 0.04, 0) * UPRIGHT)
	attach(ctx, head, {
		Shape = Enum.PartType.Cylinder,
		Size = cylinderSize(w * 0.9, w * 0.95),
		Color = rgb(25, 25, 28),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(0, w * 0.45, 0) * UPRIGHT)
	attach(ctx, head, {
		Shape = Enum.PartType.Cylinder,
		Size = cylinderSize(w * 0.15, w * 0.97),
		Color = rgb(120, 20, 30),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(0, w * 0.12, 0) * UPRIGHT)
end

-- Casquette (groom, facteur)
function Traits.Cap(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	local w = head.Size.X
	attach(ctx, head, {
		Shape = Enum.PartType.Cylinder,
		Size = cylinderSize(w * 0.35, w * 1.02),
		Color = ctx.shirt,
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(0, w * 0.1, 0) * UPRIGHT)
	attach(ctx, head, {
		Size = Vector3.new(w * 0.8, 0.06, w * 0.35),
		Color = rgb(20, 20, 20),
		Material = Enum.Material.SmoothPlastic,
	}, top * CFrame.new(0, -0.02, -w * 0.55))
	attach(ctx, head, {
		Size = Vector3.new(w * 0.25, w * 0.12, 0.05),
		Color = rgb(230, 190, 60),
		Material = Enum.Material.Metal,
	}, top * CFrame.new(0, w * 0.12, -w * 0.52))
end

-- Bonnet de nuit avec pompon
function Traits.NightCap(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	local w = head.Size.X
	attach(ctx, head, {
		Size = Vector3.new(w * 0.95, w * 0.4, w * 0.95),
		Color = rgb(70, 80, 160),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(0, w * 0.1, 0))
	attach(ctx, head, {
		Size = Vector3.new(w * 0.5, w * 0.7, w * 0.5),
		Color = rgb(70, 80, 160),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(w * 0.25, w * 0.5, w * 0.1) * CFrame.Angles(0, 0, math.rad(-35)))
	attach(ctx, head, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(w * 0.3, w * 0.3, w * 0.3),
		Color = rgb(240, 240, 255),
		Material = Enum.Material.Fabric,
	}, top * CFrame.new(w * 0.6, w * 0.75, w * 0.1))
end

-- Valise à la main
function Traits.Suitcase(ctx: Context)
	local hand = bodyPart(ctx.rig, "RightHand")
	if not hand then
		return
	end
	local base = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.5, 0)
	attach(ctx, hand, {
		Size = Vector3.new(0.35, 0.9, 1.3),
		Color = rgb(90, 60, 40),
		Material = Enum.Material.Leather,
	}, base)
	attach(ctx, hand, {
		Size = Vector3.new(0.38, 0.12, 1.32),
		Color = rgb(200, 170, 80),
		Material = Enum.Material.Metal,
	}, base * CFrame.new(0, 0.2, 0))
end

-- Sacoche de facteur en bandoulière
function Traits.MailBag(ctx: Context)
	local torso = bodyPart(ctx.rig, "UpperTorso")
	if not torso then
		return
	end
	local cf, size = torso.CFrame, torso.Size
	attach(ctx, torso, {
		Size = Vector3.new(0.5, 1, 1.1),
		Color = rgb(110, 70, 40),
		Material = Enum.Material.Leather,
	}, cf * CFrame.new(size.X / 2 + 0.25, -size.Y * 0.6, 0))
	attach(ctx, torso, {
		Size = Vector3.new(0.18, size.Y * 1.5, size.Z + 0.06),
		Color = rgb(90, 55, 30),
		Material = Enum.Material.Leather,
	}, cf * CFrame.Angles(0, 0, math.rad(-35)))
	-- Lettres qui s'échappent de la sacoche
	for i = 1, 3 do
		attach(ctx, torso, {
			Size = Vector3.new(0.05, 0.4, 0.6),
			Color = rgb(245, 240, 220),
			Material = Enum.Material.SmoothPlastic,
		}, cf * CFrame.new(size.X / 2 + 0.25, -size.Y * 0.1 + i * 0.05, (i - 2) * 0.25) * CFrame.Angles(math.rad((i - 2) * 15), 0, 0))
	end
end

-- Corps de miroir et éclats autour de la tête
function Traits.Mirror(ctx: Context)
	for _, descendant in ctx.rig:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "AnomalyEye" then
			descendant.Material = Enum.Material.Glass
			descendant.Reflectance = 0.45
			descendant.Transparency = 0.15
		end
	end
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local w = head.Size.X
	for i = 0, 6 do
		local angle = math.rad(-90 + i * 30)
		attach(ctx, head, {
			Size = Vector3.new(0.08, w * (0.5 + (i % 2) * 0.3), w * 0.18),
			Color = rgb(170, 240, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		}, head.CFrame * CFrame.Angles(0, 0, angle) * CFrame.new(0, w * 0.75, 0))
	end
end

-- Tête retournée à l'envers
function Traits.TwistedHead(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	local neck = head and head:FindFirstChild("Neck")
	if neck and neck:IsA("Motor6D") then
		-- Rotation autour du centre de la tête (elle reste sur le cou)
		neck.C1 = CFrame.Angles(0, 0, math.pi) * neck.C1
	end
	-- Bras tordus vers l'arrière
	for _, side in { "Left", "Right" } do
		local upper = bodyPart(ctx.rig, `{side}UpperArm`)
		local shoulder = upper and upper:FindFirstChild(`{side}Shoulder`)
		if shoulder and shoulder:IsA("Motor6D") then
			shoulder.C1 = shoulder.C1 * CFrame.Angles(math.rad(-25), math.rad(180), 0)
		end
	end
end

-- Fantôme : translucide, sans jambes, traînée de brume
function Traits.Ghost(ctx: Context)
	for _, descendant in ctx.rig:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Name ~= "AnomalyEye" then
			descendant.Transparency = if string.find(descendant.Name, "Leg") or string.find(descendant.Name, "Foot")
				then 1
				else 0.45
		end
	end
	local lower = bodyPart(ctx.rig, "LowerTorso")
	if lower then
		smoke(lower, ctx.skin, 10, 1.2)
	end
	ctx.rig:SetAttribute("Hover", 1.2)
end

-- Flotte au-dessus du sol (animé par le client, voir AmbienceController)
function Traits.Hover(ctx: Context)
	if not ctx.rig:GetAttribute("Hover") then
		ctx.rig:SetAttribute("Hover", 0.8)
	end
end

-- Voile de mariée translucide
function Traits.Veil(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local size = head.Size
	attach(ctx, head, {
		Size = Vector3.new(size.X * 1.25, size.Y * 2.2, size.Z * 1.25),
		Color = rgb(250, 250, 255),
		Material = Enum.Material.Fabric,
		Transparency = 0.45,
	}, head.CFrame * CFrame.new(0, -size.Y * 0.35, size.Z * 0.08))
	-- Couronne de fleurs fanées
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		attach(ctx, head, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.28, 0.28, 0.28),
			Color = if i % 2 == 0 then rgb(120, 10, 30) else rgb(240, 240, 240),
			Material = Enum.Material.Fabric,
		}, head.CFrame * CFrame.new(math.cos(angle) * size.X * 0.55, size.Y * 0.5, math.sin(angle) * size.Z * 0.55))
	end
end

-- Robe longue jusqu'au sol (cache les jambes)
function Traits.Dress(ctx: Context)
	local lower = bodyPart(ctx.rig, "LowerTorso")
	if not lower then
		return
	end
	local top = lower.Position.Y + lower.Size.Y / 2
	local bottom = feetBottom(ctx.rig) + 0.05
	local tiers = 4
	local step = (top - bottom) / tiers
	for i = 0, tiers - 1 do
		local y = top - step * (i + 0.5)
		local diameter = lower.Size.X * (1.1 + i * 0.45)
		attach(ctx, lower, {
			Shape = Enum.PartType.Cylinder,
			Size = cylinderSize(step + 0.02, diameter),
			Color = ctx.shirt,
			Material = Enum.Material.Fabric,
		}, CFrame.new(lower.Position.X, y, lower.Position.Z) * UPRIGHT)
	end
	-- Pétales rouges qui tombent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Petals"
	emitter.Color = ColorSequence.new(rgb(170, 0, 30))
	emitter.LightEmission = 0.3
	emitter.Size = NumberSequence.new(0.18)
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 4
	emitter.Speed = NumberRange.new(0.2, 0.5)
	emitter.Acceleration = Vector3.new(0, -1.5, 0)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Parent = lower
end

-- Bras trop longs qui traînent jusqu'au sol, avec des griffes
function Traits.LongArms(ctx: Context)
	local bottom = feetBottom(ctx.rig)
	for _, side in { "Left", "Right" } do
		local hand = bodyPart(ctx.rig, `{side}Hand`)
		if hand then
			local handBottom = hand.Position.Y - hand.Size.Y / 2
			local length = math.max(handBottom - bottom - 0.6, 0.5)
			local center = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - length / 2, 0)
			attach(ctx, hand, {
				Size = Vector3.new(hand.Size.X * 0.8, length, hand.Size.Z * 0.8),
				Color = ctx.skin,
				Material = Enum.Material.SmoothPlastic,
			}, center)
			for i = -1, 1 do
				attach(ctx, hand, {
					Size = Vector3.new(0.08, 0.6, 0.08),
					Color = ctx.eye,
					Material = Enum.Material.Neon,
				}, center * CFrame.new(i * 0.15, -length / 2 - 0.25, -0.1) * CFrame.Angles(math.rad(-20), 0, math.rad(i * 12)))
			end
		end
	end
end

-- Brume noire qui s'échappe du corps
function Traits.Wisps(ctx: Context)
	local torso = bodyPart(ctx.rig, "UpperTorso")
	if torso then
		smoke(torso, rgb(15, 10, 20), 8, 1.4)
	end
end

-- Couronne dorée sertie de rubis
function Traits.Crown(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local w = head.Size.X
	local top = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.05, 0)
	attach(ctx, head, {
		Shape = Enum.PartType.Cylinder,
		Size = cylinderSize(w * 0.22, w * 1.05),
		Color = rgb(255, 200, 40),
		Material = Enum.Material.Foil,
	}, top * UPRIGHT)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local spike = top * CFrame.new(math.cos(angle) * w * 0.48, w * 0.25, math.sin(angle) * w * 0.48)
		attach(ctx, head, {
			Size = Vector3.new(w * 0.12, w * 0.4, w * 0.12),
			Color = rgb(255, 200, 40),
			Material = Enum.Material.Foil,
		}, spike)
		if i % 2 == 0 then
			attach(ctx, head, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(w * 0.14, w * 0.14, w * 0.14),
				Color = rgb(255, 0, 40),
				Material = Enum.Material.Neon,
			}, spike * CFrame.new(0, w * 0.25, 0))
		end
	end
end

-- Auréole sombre au-dessus de la tête
function Traits.Halo(ctx: Context)
	local head = bodyPart(ctx.rig, "Head")
	if not head then
		return
	end
	local w = head.Size.X
	local center = head.CFrame * CFrame.new(0, head.Size.Y / 2 + w * 0.85, w * 0.25)
	for i = 0, 15 do
		local angle = math.rad(i * 22.5)
		attach(ctx, head, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.16, 0.16, 0.16),
			Color = ctx.eye,
			Material = Enum.Material.Neon,
		}, center * CFrame.new(math.cos(angle) * w * 0.7, 0, math.sin(angle) * w * 0.7))
	end
end

-- Longue cape dans le dos
function Traits.Cape(ctx: Context)
	local torso = bodyPart(ctx.rig, "UpperTorso")
	if not torso then
		return
	end
	local shoulderY = torso.Position.Y + torso.Size.Y / 2
	local bottom = feetBottom(ctx.rig) + 0.4
	local height = shoulderY - bottom
	local back = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + 0.12)
	local center = CFrame.new(back.Position.X, shoulderY - height / 2, back.Position.Z) * (torso.CFrame - torso.CFrame.Position)
	attach(ctx, torso, {
		Size = Vector3.new(torso.Size.X * 1.35, height, 0.1),
		Color = rgb(110, 0, 15),
		Material = Enum.Material.Fabric,
	}, center * CFrame.new(0, 0, 0.15) * CFrame.Angles(math.rad(6), 0, 0))
	attach(ctx, torso, {
		Size = Vector3.new(torso.Size.X * 1.5, 0.35, torso.Size.Z * 1.3),
		Color = rgb(240, 235, 230),
		Material = Enum.Material.Fabric,
	}, torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.1, 0))
end

-- Ajoute les traits listés. Le modèle n'est pas encore dans workspace.
function AnomalyLooks.apply(rig: Model, look: { string }?, appearance: { Skin: Color3, Shirt: Color3 }, eyeColor: Color3)
	if not look then
		return
	end
	local ctx: Context = { rig = rig, skin = appearance.Skin, shirt = appearance.Shirt, eye = eyeColor }
	for _, traitName in look do
		local trait = Traits[traitName]
		if trait then
			local ok, err = pcall(trait, ctx)
			if not ok then
				warn(`[AnomalyLooks] Trait {traitName} : {err}`)
			end
		else
			warn(`[AnomalyLooks] Trait inconnu : {traitName}`)
		end
	end
end

AnomalyLooks.Traits = Traits

return AnomalyLooks
