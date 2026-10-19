--!strict
-- Habillage de la carte : nuit (lune, étoiles, nuages, brume), terrain, façades
-- d'hôtel à étages, intérieurs décorés, fontaine, cimetières...
-- Purement visuel : rien ici ne gêne les chemins des clients ni la caméra de
-- réception (vérifié par tests/run.luau).
--
-- Les lumières marquées de l'attribut Flicker clignotent (AmbienceController).

local Lighting = game:GetService("Lighting")

local PartFactory = require(script.Parent:WaitForChild("PartFactory"))

local decor = PartFactory.decor
local light = PartFactory.light
local rgb = Color3.fromRGB

local WARM_LIGHT = rgb(255, 190, 120)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout

-- Couleur de façade de chaque hôtel (pour les reconnaître de loin)
local WALL_PALETTE = {
	rgb(92, 64, 80), -- prune
	rgb(58, 78, 70), -- vert sapin
	rgb(62, 66, 96), -- bleu nuit
	rgb(110, 52, 52), -- bordeaux
	rgb(70, 64, 60), -- anthracite
	rgb(52, 82, 92), -- bleu canard
}

export type HotelLayout = {
	Index: number,
	Size: number,
	WallHeight: number,
	DoorWidth: number,
}

local MapDecor = {}

function MapDecor.wallColor(index: number): Color3
	return WALL_PALETTE[(index - 1) % #WALL_PALETTE + 1]
end

local function cylinder(props: { [string]: any }, height: number, diameter: number, cframe: CFrame): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cframe * UPRIGHT
	return decor(props)
end

local function ball(props: { [string]: any }, diameter: number, cframe: CFrame): Part
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.CFrame = cframe
	return decor(props)
end

local function wedge(props: { [string]: any }): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Brume au ras du sol, émise depuis une zone invisible
local function mist(parent: Instance, cframe: CFrame, size: Vector3, rate: number)
	local zone = decor({
		Name = "MistZone",
		Size = size,
		CFrame = cframe,
		Transparency = 1,
		Parent = parent,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Color = ColorSequence.new(rgb(175, 165, 210))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 16) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(10, 14)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-8, 8)
	emitter.Parent = zone
end

-- Petites lueurs qui flottent (feux follets)
local function wisps(parent: BasePart, color: Color3, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Wisps"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.3, 0)
	emitter.Parent = parent
end

-- Petite flamme : boule lumineuse + vrai feu Roblox
local function flame(parent: Instance, cframe: CFrame, size: number, range: number, flicker: boolean): Part
	local core = ball({
		Name = "Flame",
		Color = rgb(255, 160, 60),
		Material = Enum.Material.Neon,
		Parent = parent,
	}, size, cframe)
	local fire = Instance.new("Fire")
	fire.Size = size * 2
	fire.Heat = 2
	fire.Color = rgb(255, 140, 40)
	fire.SecondaryColor = rgb(255, 220, 120)
	fire.Parent = core
	light(core, rgb(255, 150, 70), range, 1.4)
	if flicker then
		core:SetAttribute("Flicker", true)
	end
	return core
end

------------------------------------------------------------------ ambiance

function MapDecor.setupLighting()
	Lighting.ClockTime = 21.3
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 1.6
	Lighting.ExposureCompensation = 0.25
	Lighting.Ambient = rgb(85, 75, 105)
	Lighting.OutdoorAmbient = rgb(105, 95, 135)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true

	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.MoonAngularSize = 18
	sky.SunAngularSize = 10
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.15
	atmosphere.Color = rgb(120, 100, 160)
	atmosphere.Decay = rgb(60, 40, 90)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Contrast = 0.12
	color.Saturation = -0.05
	color.TintColor = rgb(235, 228, 255)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	-- Léger flou au loin (la caméra de jeu reste nette)
	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.12
	depth.FocusDistance = 80
	depth.InFocusRadius = 90
	depth.NearIntensity = 0
	depth.Parent = Lighting
end

-- Sol en terrain (herbe animée), collines à l'horizon, nuages, eau
function MapDecor.setupTerrain()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(900, 8, 900), Enum.Material.Grass)

	-- Collines tout autour (ferment l'horizon)
	for i = 0, 23 do
		local angle = math.rad(i * 15)
		local radius = 400 + (i % 3) * 25
		local size = 60 + (i * 7) % 30
		terrain:FillBall(Vector3.new(math.cos(angle) * radius, -15, math.sin(angle) * radius), size, Enum.Material.Grass)
		if i % 4 == 0 then
			terrain:FillBall(Vector3.new(math.cos(angle) * (radius - 30), 5, math.sin(angle) * (radius - 30)), 18, Enum.Material.Rock)
		end
	end
	-- Terre battue des cimetières
	for _, x in { -150, 150 } do
		terrain:FillBlock(CFrame.new(x, -2, 0), Vector3.new(36, 4, 44), Enum.Material.Mud)
	end
	-- Eau de la fontaine
	terrain:FillCylinder(CFrame.new(0, 0.9, 0), 1.6, 7.6, Enum.Material.Water)

	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, rgb(58, 78, 52))
		terrain:SetMaterialColor(Enum.Material.Mud, rgb(60, 48, 40))
		terrain:SetMaterialColor(Enum.Material.Rock, rgb(85, 82, 92))
	end)
	pcall(function()
		terrain.Decoration = true -- brins d'herbe animés
	end)
	terrain.WaterColor = rgb(40, 90, 110)
	terrain.WaterTransparency = 0.6
	terrain.WaterReflectance = 0.8
	terrain.WaterWaveSize = 0.05
	terrain.WaterWaveSpeed = 4

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.62
	clouds.Density = 0.45
	clouds.Color = rgb(70, 60, 90)
	clouds.Parent = terrain
end

------------------------------------------------------------------ hôtels

-- Fenêtre éclairée (ou sombre) avec cadre, rebord et croisillons.
-- `cf` : centre de la fenêtre, avant = -Z (vers l'extérieur du mur)
local function window(parent: Instance, cf: CFrame, width: number, height: number, lit: boolean, frameColor: Color3)
	decor({
		Name = "WindowPane",
		Size = Vector3.new(width, height, 0.15),
		CFrame = cf,
		Color = if lit then rgb(255, 200, 120) else rgb(20, 20, 30),
		Material = if lit then Enum.Material.Neon else Enum.Material.Glass,
		Reflectance = if lit then 0 else 0.4,
		Parent = parent,
	})
	local function frame(name: string, size: Vector3, offset: CFrame)
		decor({ Name = name, Size = size, CFrame = cf * offset, Color = frameColor, Material = Enum.Material.Wood, Parent = parent })
	end
	local t = 0.35
	for _, side in { -1, 1 } do
		frame("WindowFrame", Vector3.new(t, height + t * 2, 0.4), CFrame.new(side * (width / 2 + t / 2), 0, -0.1))
		frame("WindowFrame", Vector3.new(width, t, 0.4), CFrame.new(0, side * (height / 2 + t / 2), -0.1))
	end
	frame("WindowSill", Vector3.new(width + 1, 0.3, 0.8), CFrame.new(0, -height / 2 - 0.45, -0.3))
	-- Croisillons
	frame("Mullion", Vector3.new(0.18, height, 0.25), CFrame.new(0, 0, -0.05))
	frame("Mullion", Vector3.new(width, 0.18, 0.25), CFrame.new(0, height * 0.1, -0.05))
end

-- Silhouette sombre derrière une fenêtre éclairée
local function silhouette(parent: Instance, cf: CFrame)
	decor({ Name = "Silhouette", Size = Vector3.new(1.4, 1.6, 0.05), CFrame = cf * CFrame.new(0, -0.9, -0.1), Color = rgb(10, 8, 14), Parent = parent })
	ball({ Name = "Silhouette", Color = rgb(10, 8, 14), Parent = parent }, 0.9, cf * CFrame.new(0, 0.4, -0.1))
end

local function decorateExterior(folder: Folder, at: (number, number, number) -> CFrame, layout: HotelLayout, wallColor: Color3)
	local half = layout.Size / 2
	local top = 1 + layout.WallHeight
	local stone = rgb(150, 140, 135)
	local trimColor = rgb(45, 30, 25)
	local index = layout.Index

	-- Toit plat du rez-de-chaussée (avec corniche)
	decor({
		Name = "Roof",
		Size = Vector3.new(layout.Size + 2, 1, layout.Size + 2),
		CFrame = at(0, top + 0.5, 0),
		Color = rgb(45, 35, 50),
		Material = Enum.Material.Slate,
		CanCollide = true,
		Parent = folder,
	})
	decor({
		Name = "Cornice",
		Size = Vector3.new(layout.Size + 3, 0.5, layout.Size + 3),
		CFrame = at(0, top + 0.1, 0),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = folder,
	})

	-- Piliers d'angle en pierre
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			decor({
				Name = "CornerPillar",
				Size = Vector3.new(2.4, layout.WallHeight + 1, 2.4),
				CFrame = at(sx * (half + 0.4), (layout.WallHeight + 1) / 2, sz * (half + 0.4)),
				Color = stone,
				Material = Enum.Material.Concrete,
				CanCollide = true,
				Parent = folder,
			})
		end
	end

	-- Étages supérieurs (en retrait derrière l'enseigne)
	local upperWidth = layout.Size - 4
	local upperDepth = 40
	local upperZ = -4
	local upperBottom = top + 1
	local upperHeight = 14
	local upperFront = upperZ + upperDepth / 2
	decor({
		Name = "UpperFloors",
		Size = Vector3.new(upperWidth, upperHeight, upperDepth),
		CFrame = at(0, upperBottom + upperHeight / 2, upperZ),
		Color = wallColor,
		Material = Enum.Material.Brick,
		CanCollide = true,
		Parent = folder,
	})
	decor({
		Name = "UpperCornice",
		Size = Vector3.new(upperWidth + 2, 0.6, upperDepth + 2),
		CFrame = at(0, upperBottom + upperHeight + 0.3, upperZ),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = folder,
	})
	-- Bandeau entre les deux étages
	decor({
		Name = "FloorBand",
		Size = Vector3.new(upperWidth + 0.6, 0.5, upperDepth + 0.6),
		CFrame = at(0, upperBottom + upperHeight / 2, upperZ),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = folder,
	})

	-- Fenêtres des étages : environ 2 sur 3 allumées, une silhouette par hôtel
	local count = 0
	for row, y in { upperBottom + 3.6, upperBottom + 10.4 } do
		for column, x in { -20, -12, -4, 4, 12, 20 } do
			count += 1
			local lit = (index * 7 + column * 3 + row * 5) % 3 ~= 0
			local cf = at(x, y, upperFront + 0.1) * CFrame.Angles(0, math.pi, 0)
			window(folder, cf, 3.6, 3.6, lit, trimColor)
			if lit and count == (index % 6) + 3 then
				silhouette(folder, cf)
			end
		end
		for _, side in { -1, 1 } do
			for _, z in { -18, -8, 2, 10 } do
				local lit = (index + row + z) % 3 ~= 0
				local cf = at(side * (upperWidth / 2 + 0.1), y, z) * CFrame.Angles(0, side * math.rad(-90), 0)
				window(folder, cf, 3.6, 3.6, lit, trimColor)
			end
		end
	end

	-- Toit à deux pans (pignons sur les côtés)
	local roofBottom = upperBottom + upperHeight + 0.6
	local roofHeight = 8
	for _, side in { -1, 1 } do
		local part = wedge({
			Name = "GableRoof",
			Size = Vector3.new(upperWidth + 3, roofHeight, upperDepth / 2 + 1),
			CFrame = at(0, roofBottom + roofHeight / 2, upperZ + side * (upperDepth / 4 + 0.5))
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Color = rgb(40, 32, 45),
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
		part.Parent = folder
	end
	decor({
		Name = "RoofRidge",
		Size = Vector3.new(upperWidth + 3.4, 0.6, 1),
		CFrame = at(0, roofBottom + roofHeight + 0.1, upperZ),
		Color = rgb(25, 20, 28),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	-- Lucarnes rondes sur les pignons
	for _, side in { -1, 1 } do
		local attic = decor({
			Name = "AtticWindow",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3, 3),
			CFrame = at(side * (upperWidth / 2 + 1.55), roofBottom + 2.6, upperZ),
			Color = rgb(255, 120, 60),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		if side > 0 then
			attic:SetAttribute("Flicker", true)
		end
	end
	-- Cheminée qui fume
	local chimney = decor({
		Name = "Chimney",
		Size = Vector3.new(3, 12, 3),
		CFrame = at(15, roofBottom + 5, upperZ - 9),
		Color = rgb(90, 50, 45),
		Material = Enum.Material.Brick,
		Parent = folder,
	})
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(60, 55, 65)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = chimney

	-- Balustrade de la terrasse (de part et d'autre de l'enseigne)
	for _, side in { -1, 1 } do
		local x0 = 13
		local length = half - x0
		decor({
			Name = "Balustrade",
			Size = Vector3.new(length, 0.4, 0.5),
			CFrame = at(side * (x0 + length / 2), top + 2.8, half + 0.2),
			Color = stone,
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
		for i = 0, math.floor(length / 1.5) do
			decor({
				Name = "Baluster",
				Size = Vector3.new(0.4, 1.8, 0.4),
				CFrame = at(side * (x0 + i * 1.5), top + 1.9, half + 0.2),
				Color = stone,
				Material = Enum.Material.Concrete,
				Parent = folder,
			})
		end
	end

	-- Rez-de-chaussée : fenêtres avec volets
	local sideCenter = (layout.DoorWidth + (layout.Size - layout.DoorWidth) / 2) / 2
	for _, side in { -1, 1 } do
		local cf = at(side * sideCenter, 9, half + 0.6) * CFrame.Angles(0, math.pi, 0)
		window(folder, cf, 8, 5, true, trimColor)
		for _, s in { -1, 1 } do
			decor({
				Name = "Shutter",
				Size = Vector3.new(2.2, 5.6, 0.2),
				CFrame = cf * CFrame.new(s * 5.4, 0, -0.1),
				Color = rgb(40, 60, 45),
				Material = Enum.Material.WoodPlanks,
				Parent = folder,
			})
		end
		for _, z in { -12, 6 } do
			window(folder, at(side * (half + 0.6), 9, z) * CFrame.Angles(0, side * math.rad(-90), 0), 7, 5, true, trimColor)
		end
	end

	-- Porte : montants, auvent, marche, lanternes, haies
	for _, side in { -1, 1 } do
		decor({
			Name = "DoorPillar",
			Size = Vector3.new(1.2, layout.WallHeight - 4, 1.2),
			CFrame = at(side * (layout.DoorWidth / 2 + 0.6), 1 + (layout.WallHeight - 4) / 2, half + 0.7),
			Color = rgb(60, 35, 25),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		local px = side * (layout.DoorWidth / 2 + 2.5)
		cylinder({ Name = "LanternPost", Color = rgb(30, 25, 30), Material = Enum.Material.Metal, Parent = folder }, 6.5, 0.5, at(px, 3.25, half + 2))
		decor({
			Name = "LanternGlass",
			Size = Vector3.new(1.4, 1.8, 1.4),
			CFrame = at(px, 7.4, half + 2),
			Color = rgb(255, 220, 160),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Parent = folder,
		})
		decor({
			Name = "LanternCap",
			Size = Vector3.new(1.8, 0.4, 1.8),
			CFrame = at(px, 8.5, half + 2),
			Color = rgb(30, 25, 30),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		flame(folder, at(px, 7.2, half + 2), 0.6, 16, side > 0 and index % 2 == 0)
		decor({
			Name = "Hedge",
			Size = Vector3.new(15, 2.6, 1.8),
			CFrame = at(side * 18.5, 1.3, half + 2.2),
			Color = rgb(35, 70, 40),
			Material = Enum.Material.Grass,
			CanCollide = true,
			Parent = folder,
		})
	end
	decor({
		Name = "Awning",
		Size = Vector3.new(layout.DoorWidth + 4, 0.5, 4),
		CFrame = at(0, layout.WallHeight - 2.5, half + 2.2) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = rgb(130, 25, 45),
		Material = Enum.Material.Fabric,
		Parent = folder,
	})
	for i = -3, 3 do
		decor({
			Name = "AwningStripe",
			Size = Vector3.new(1, 0.52, 4.02),
			CFrame = at(i * 2.2, layout.WallHeight - 2.5, half + 2.2) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = rgb(235, 220, 200),
			Material = Enum.Material.Fabric,
			Parent = folder,
		})
	end
	decor({
		Name = "Step",
		Size = Vector3.new(layout.DoorWidth + 2, 0.5, 3),
		CFrame = at(0, 0.25, half + 2),
		Color = stone,
		Material = Enum.Material.Concrete,
		CanCollide = true,
		Parent = folder,
	})
	-- Allée pavée jusqu'à la place
	decor({
		Name = "Path",
		Size = Vector3.new(layout.DoorWidth, 0.3, 10),
		CFrame = at(0, 0.15, half + 8.5),
		Color = rgb(105, 100, 105),
		Material = Enum.Material.Cobblestone,
		CanCollide = true,
		Parent = folder,
	})
end

local function decorateInterior(folder: Folder, at: (number, number, number) -> CFrame, layout: HotelLayout)
	local half = layout.Size / 2
	local top = 1 + layout.WallHeight
	local inner = half - 0.6 -- doublage contre la face intérieure des murs
	local gold = rgb(200, 160, 70)
	local paper = rgb(85, 28, 38)
	local wainscot = rgb(60, 35, 25)

	-- Papier peint, lambris et frises dorées. Chaque mur : { x, z, longueur, rotation }
	local doorEdge = layout.DoorWidth / 2
	local frontLength = inner - doorEdge
	local walls = {
		{ 0, -inner, inner * 2, 0 },
		{ -inner, 0, inner * 2, math.rad(90) },
		{ inner, 0, inner * 2, math.rad(-90) },
		{ -(doorEdge + frontLength / 2), inner, frontLength, math.pi },
		{ doorEdge + frontLength / 2, inner, frontLength, math.pi },
	}
	for _, w in walls do
		local base = at(w[1], 0, w[2]) * CFrame.Angles(0, w[4], 0)
		local length = w[3]
		decor({ Name = "Wallpaper", Size = Vector3.new(length, top - 5, 0.2), CFrame = base * CFrame.new(0, 5 + (top - 5) / 2, 0), Color = paper, Material = Enum.Material.Fabric, Parent = folder })
		decor({ Name = "Wainscot", Size = Vector3.new(length, 4, 0.3), CFrame = base * CFrame.new(0, 3, 0), Color = wainscot, Material = Enum.Material.WoodPlanks, Parent = folder })
		decor({ Name = "WallTrim", Size = Vector3.new(length, 0.3, 0.4), CFrame = base * CFrame.new(0, 5.1, 0), Color = gold, Material = Enum.Material.Foil, Parent = folder })
		decor({ Name = "CeilingTrim", Size = Vector3.new(length, 0.5, 0.5), CFrame = base * CFrame.new(0, top - 0.3, 0), Color = gold, Material = Enum.Material.Foil, Parent = folder })
	end
	decor({ Name = "Wallpaper", Size = Vector3.new(layout.DoorWidth, 4, 0.2), CFrame = at(0, top - 2, inner), Color = paper, Material = Enum.Material.Fabric, Parent = folder })

	-- Fenêtres de façade vues de l'intérieur (lumière de lune)
	local sideCenter = (layout.DoorWidth + (layout.Size - layout.DoorWidth) / 2) / 2
	for _, side in { -1, 1 } do
		decor({
			Name = "InnerWindow",
			Size = Vector3.new(8, 5, 0.1),
			CFrame = at(side * sideCenter, 9, inner - 0.15),
			Color = rgb(120, 140, 200),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = folder,
		})
	end

	-- Plafond : poutres et plafonniers
	for _, z in { -20, -6, 8, 22 } do
		decor({ Name = "CeilingBeam", Size = Vector3.new(layout.Size - 1, 0.8, 1), CFrame = at(0, top - 0.4, z), Color = rgb(50, 30, 22), Material = Enum.Material.Wood, Parent = folder })
	end
	for _, x in { -14, 14 } do
		for _, z in { -14, 2 } do
			local panel = decor({
				Name = "CeilingLight",
				Size = Vector3.new(6, 0.3, 6),
				CFrame = at(x, top - 0.2, z),
				Color = rgb(255, 230, 190),
				Material = Enum.Material.Neon,
				Parent = folder,
			})
			light(panel, WARM_LIGHT, 26, 1.1)
		end
	end

	-- Lustre au-dessus du hall
	local chandelierY = top - 3.5
	local hub = at(0, chandelierY, -2)
	decor({ Name = "ChandelierChain", Size = Vector3.new(0.2, 3, 0.2), CFrame = at(0, top - 1.5, -2), Color = gold, Material = Enum.Material.Metal, Parent = folder })
	local body = ball({ Name = "Chandelier", Color = gold, Material = Enum.Material.Foil, Parent = folder }, 1.2, hub)
	light(body, WARM_LIGHT, 30, 1.2)
	body:SetAttribute("Flicker", true)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local arm = hub * CFrame.Angles(0, angle, 0)
		decor({ Name = "ChandelierArm", Size = Vector3.new(0.15, 0.15, 2.2), CFrame = arm * CFrame.new(0, 0, -1.1), Color = gold, Material = Enum.Material.Metal, Parent = folder })
		cylinder({ Name = "Candle", Color = rgb(240, 235, 220), Material = Enum.Material.SmoothPlastic, Parent = folder }, 0.6, 0.25, arm * CFrame.new(0, 0.3, -2.2))
		ball({ Name = "CandleFlame", Color = rgb(255, 190, 90), Material = Enum.Material.Neon, Parent = folder }, 0.25, arm * CFrame.new(0, 0.75, -2.2))
	end

	-- Tapis du hall (bordure dorée) et tapis rouge de l'entrée
	decor({ Name = "RugBorder", Size = Vector3.new(34, 0.06, 16), CFrame = at(0, 1.03, -2), Color = gold, Material = Enum.Material.Fabric, Parent = folder })
	decor({ Name = "Rug", Size = Vector3.new(32, 0.08, 14), CFrame = at(0, 1.04, -2), Color = rgb(90, 15, 30), Material = Enum.Material.Fabric, Parent = folder })
	decor({ Name = "Carpet", Size = Vector3.new(8, 0.1, 13), CFrame = at(0, 1.05, 21), Color = rgb(120, 20, 35), Material = Enum.Material.Fabric, Parent = folder })
	for _, side in { -1, 1 } do
		decor({ Name = "CarpetEdge", Size = Vector3.new(0.4, 0.11, 13), CFrame = at(side * 3.6, 1.05, 21), Color = gold, Material = Enum.Material.Fabric, Parent = folder })
	end

	-- Comptoir : plateau en marbre, frise dorée, panneaux, sonnette, registre, lampe
	decor({ Name = "CounterTop", Size = Vector3.new(15, 0.4, 3), CFrame = at(0, 5.2, 12), Color = rgb(225, 220, 230), Material = Enum.Material.Marble, CanCollide = true, Parent = folder })
	decor({ Name = "CounterTrim", Size = Vector3.new(14.2, 0.3, 0.1), CFrame = at(0, 4.7, 13.3), Color = gold, Material = Enum.Material.Foil, Parent = folder })
	for _, x in { -4.6, 0, 4.6 } do
		decor({ Name = "CounterPanel", Size = Vector3.new(3.8, 2.4, 0.1), CFrame = at(x, 2.9, 13.3), Color = rgb(85, 50, 35), Material = Enum.Material.Wood, Parent = folder })
	end
	ball({ Name = "Bell", Color = rgb(230, 180, 60), Material = Enum.Material.Metal, Parent = folder }, 0.7, at(3, 5.7, 12))
	decor({ Name = "Ledger", Size = Vector3.new(1.8, 0.25, 1.2), CFrame = at(-2.5, 5.55, 12) * CFrame.Angles(0, math.rad(10), 0), Color = rgb(90, 30, 30), Material = Enum.Material.Fabric, Parent = folder })
	decor({ Name = "Quill", Size = Vector3.new(0.08, 0.08, 1.1), CFrame = at(-1.3, 5.65, 12) * CFrame.Angles(0, math.rad(40), math.rad(10)), Color = rgb(240, 240, 240), Parent = folder })
	cylinder({ Name = "LampFoot", Color = gold, Material = Enum.Material.Metal, Parent = folder }, 0.9, 0.2, at(-6, 5.85, 12))
	local lamp = ball({ Name = "DeskLamp", Color = rgb(255, 210, 140), Material = Enum.Material.Neon, Parent = folder }, 0.8, at(-6, 6.5, 12))
	light(lamp, WARM_LIGHT, 10, 1)
	lamp:SetAttribute("Flicker", true)

	-- Plantes dans les coins près de l'entrée
	for _, x in { -(half - 3), half - 3 } do
		cylinder({ Name = "Pot", Color = rgb(90, 55, 40), Material = Enum.Material.Concrete, Parent = folder }, 2.5, 2.5, at(x, 2.25, half - 3))
		ball({ Name = "Leaves", Color = rgb(40, 95, 50), Material = Enum.Material.Grass, Parent = folder }, 3.5, at(x, 4.6, half - 3))
		ball({ Name = "Leaves", Color = rgb(30, 80, 45), Material = Enum.Material.Grass, Parent = folder }, 2.4, at(x * 0.97, 6, half - 3.4))
	end

	-- Horloge de parquet et canapé de velours, contre la façade
	decor({ Name = "Clock", Size = Vector3.new(2.4, 8, 1.6), CFrame = at(-9.5, 5, inner - 1), Color = rgb(55, 30, 20), Material = Enum.Material.Wood, CanCollide = true, Parent = folder })
	decor({
		Name = "ClockFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 1.8, 1.8),
		CFrame = at(-9.5, 7.5, inner - 1.85) * CFrame.Angles(0, math.rad(90), 0),
		Color = rgb(240, 230, 200),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	decor({ Name = "ClockHand", Size = Vector3.new(0.1, 0.8, 0.05), CFrame = at(-9.5, 7.8, inner - 1.92) * CFrame.Angles(0, 0, math.rad(30)), Color = rgb(20, 20, 20), Parent = folder })
	decor({ Name = "SofaSeat", Size = Vector3.new(6, 1.4, 2.4), CFrame = at(17, 1.7, inner - 2), Color = rgb(110, 20, 50), Material = Enum.Material.Fabric, CanCollide = true, Parent = folder })
	decor({ Name = "SofaBack", Size = Vector3.new(6, 2.4, 0.6), CFrame = at(17, 3.2, inner - 0.9), Color = rgb(110, 20, 50), Material = Enum.Material.Fabric, Parent = folder })
	for _, s in { -1, 1 } do
		decor({ Name = "SofaArm", Size = Vector3.new(0.6, 2, 2.4), CFrame = at(17 + s * 3, 2.4, inner - 2), Color = rgb(90, 15, 40), Material = Enum.Material.Fabric, Parent = folder })
	end

	-- Portraits aux yeux lumineux sur les murs latéraux (près de l'entrée)
	for _, side in { -1, 1 } do
		for _, z in { 14, 22 } do
			-- Avant (-Z) tourné vers l'intérieur de l'hôtel
			local base = at(side * (inner - 0.2), 10, z) * CFrame.Angles(0, side * math.rad(90), 0)
			decor({ Name = "PortraitFrame", Size = Vector3.new(4, 5, 0.3), CFrame = base, Color = gold, Material = Enum.Material.Foil, Parent = folder })
			decor({ Name = "Portrait", Size = Vector3.new(3.2, 4.2, 0.1), CFrame = base * CFrame.new(0, 0, -0.18), Color = rgb(30, 25, 35), Material = Enum.Material.SmoothPlastic, Parent = folder })
			decor({ Name = "PortraitFigure", Size = Vector3.new(1.6, 1.6, 0.05), CFrame = base * CFrame.new(0, -1.2, -0.24), Color = rgb(12, 10, 16), Parent = folder })
			ball({ Name = "PortraitFigure", Color = rgb(12, 10, 16), Material = Enum.Material.SmoothPlastic, Parent = folder }, 1.2, base * CFrame.new(0, 0.3, -0.2))
			for _, ex in { -0.22, 0.22 } do
				ball({ Name = "PortraitEye", Color = rgb(255, 30, 30), Material = Enum.Material.Neon, Parent = folder }, 0.15, base * CFrame.new(ex, 0.4, -0.78))
			end
		end
	end
end

function MapDecor.decorateHotel(hotel: Model, origin: CFrame, layout: HotelLayout)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = hotel

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	decorateExterior(folder, at, layout, MapDecor.wallColor(layout.Index))
	decorateInterior(folder, at, layout)

	-- Cadre néon autour de l'enseigne
	local sign = hotel:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		decor({
			Name = "SignFrame",
			Size = sign.Size + Vector3.new(0.8, 0.8, -0.3),
			CFrame = sign.CFrame * CFrame.new(0, 0, 0.3),
			Color = rgb(170, 60, 255),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end

	-- Brume devant l'entrée
	mist(folder, at(0, 1, layout.Size / 2 + 9), Vector3.new(40, 1, 10), 2)
end

------------------------------------------------------------------ place

local function fountain(folder: Folder)
	local stone = rgb(150, 145, 155)
	-- Bassin : anneau de pierre (l'eau est en terrain)
	local segments = 20
	local radius = 8.6
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local cf = CFrame.lookAt(Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), Vector3.new(0, 0, 0))
		decor({ Name = "FountainWall", Size = Vector3.new(2.9, 2.2, 1.2), CFrame = cf * CFrame.new(0, 1.1, 0), Color = stone, Material = Enum.Material.Cobblestone, CanCollide = true, Parent = folder })
		decor({ Name = "FountainRim", Size = Vector3.new(3.1, 0.35, 1.8), CFrame = cf * CFrame.new(0, 2.35, 0), Color = rgb(200, 195, 205), Material = Enum.Material.Marble, Parent = folder })
	end
	cylinder({ Name = "FountainFloor", Color = rgb(60, 70, 80), Material = Enum.Material.Slate, Parent = folder }, 0.2, 16.4, CFrame.new(0, 0.3, 0))
	local glow = decor({ Name = "FountainGlow", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 0.6, 0), Transparency = 1, Parent = folder })
	light(glow, rgb(90, 200, 255), 16, 1.5)

	-- Colonne à deux vasques
	cylinder({ Name = "FountainPillar", Color = stone, Material = Enum.Material.Marble, CanCollide = true, Parent = folder }, 3, 3, CFrame.new(0, 1.5, 0))
	cylinder({ Name = "FountainBowl", Color = rgb(200, 195, 205), Material = Enum.Material.Marble, Parent = folder }, 0.6, 7, CFrame.new(0, 3.3, 0))
	cylinder({ Name = "FountainBowlWater", Color = rgb(80, 180, 230), Material = Enum.Material.Glass, Transparency = 0.3, Parent = folder }, 0.1, 6.2, CFrame.new(0, 3.62, 0))
	cylinder({ Name = "FountainPillar", Color = stone, Material = Enum.Material.Marble, Parent = folder }, 3, 1.2, CFrame.new(0, 5.1, 0))
	local topBowl = cylinder({ Name = "FountainBowl", Color = rgb(200, 195, 205), Material = Enum.Material.Marble, Parent = folder }, 0.4, 3.5, CFrame.new(0, 6.8, 0))
	local orb = ball({ Name = "FountainOrb", Color = rgb(150, 90, 255), Material = Enum.Material.Neon, Parent = folder }, 2, CFrame.new(0, 8.2, 0))
	light(orb, rgb(170, 110, 255), 32, 2)

	-- Jet d'eau : gouttes qui montent puis retombent. La vasque est un cylindre
	-- couché puis redressé : son « haut » local (axe X) pointe vers le ciel.
	local jet = Instance.new("ParticleEmitter")
	jet.Name = "WaterJet"
	jet.EmissionDirection = Enum.NormalId.Right
	jet.Color = ColorSequence.new(rgb(170, 220, 255))
	jet.LightEmission = 0.4
	jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.1) })
	jet.Transparency = NumberSequence.new(0.2, 0.8)
	jet.Lifetime = NumberRange.new(0.8, 1.1)
	jet.Rate = 90
	jet.Speed = NumberRange.new(7, 9)
	jet.SpreadAngle = Vector2.new(22, 22)
	jet.Acceleration = Vector3.new(0, -24, 0)
	jet.Parent = topBowl
end

local function bench(folder: Folder, cf: CFrame)
	local wood = rgb(85, 55, 35)
	local iron = rgb(30, 28, 32)
	decor({ Name = "BenchSeat", Size = Vector3.new(6, 0.3, 1.8), CFrame = cf * CFrame.new(0, 1.7, 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
	decor({ Name = "BenchBack", Size = Vector3.new(6, 1.6, 0.25), CFrame = cf * CFrame.new(0, 2.8, 0.85) * CFrame.Angles(math.rad(-10), 0, 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
	for _, x in { -2.6, 2.6 } do
		decor({ Name = "BenchLeg", Size = Vector3.new(0.25, 1.7, 1.6), CFrame = cf * CFrame.new(x, 0.85, 0), Color = iron, Material = Enum.Material.Metal, Parent = folder })
	end
end

local function lampPost(folder: Folder, x: number, z: number, flicker: boolean)
	local iron = rgb(28, 25, 32)
	decor({ Name = "LampBase", Size = Vector3.new(1.4, 1.2, 1.4), CFrame = CFrame.new(x, 0.6, z), Color = iron, Material = Enum.Material.Metal, CanCollide = true, Parent = folder })
	cylinder({ Name = "LampPost", Color = iron, Material = Enum.Material.Metal, CanCollide = true, Parent = folder }, 10, 0.6, CFrame.new(x, 6, z))
	decor({ Name = "LampGlass", Size = Vector3.new(1.6, 2, 1.6), CFrame = CFrame.new(x, 12, z), Color = rgb(255, 220, 160), Material = Enum.Material.Glass, Transparency = 0.45, Parent = folder })
	decor({ Name = "LampCap", Size = Vector3.new(2.2, 0.4, 2.2), CFrame = CFrame.new(x, 13.2, z), Color = iron, Material = Enum.Material.Metal, Parent = folder })
	decor({ Name = "LampCap", Size = Vector3.new(1.2, 0.6, 1.2), CFrame = CFrame.new(x, 13.6, z), Color = iron, Material = Enum.Material.Metal, Parent = folder })
	local bulb = ball({ Name = "LampBulb", Color = rgb(255, 210, 150), Material = Enum.Material.Neon, Parent = folder }, 1, CFrame.new(x, 12, z))
	light(bulb, WARM_LIGHT, 30, 1.6)
	if flicker then
		bulb:SetAttribute("Flicker", true)
	end
end

-- Grille en fer forgé le long d'un segment (barreaux, deux traverses)
local function fence(folder: Folder, from: Vector3, to: Vector3, height: number)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local cf = CFrame.lookAt(from, to)
	local iron = rgb(25, 22, 28)
	for _, y in { 0.8, height - 0.3 } do
		decor({
			Name = "FenceRail",
			Size = Vector3.new(0.2, 0.2, length),
			CFrame = cf * CFrame.new(0, y, -length / 2),
			Color = iron,
			Material = Enum.Material.Metal,
			CanCollide = true,
			Parent = folder,
		})
	end
	local bars = math.max(math.floor(length / 1.5), 1)
	for i = 0, bars do
		local barHeight = if i % 5 == 0 then height + 0.6 else height
		decor({
			Name = "FenceBar",
			Size = Vector3.new(0.18, barHeight, 0.18),
			CFrame = cf * CFrame.new(0, barHeight / 2, -i * length / bars),
			Color = iron,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end
end

local function deadTree(folder: Folder, base: Vector3, seed: number)
	local bark = rgb(55, 42, 36)
	cylinder({ Name = "TreeTrunk", Color = bark, Material = Enum.Material.Wood, CanCollide = true, Parent = folder }, 8, 2.2, CFrame.new(base + Vector3.new(0, 4, 0)))
	cylinder({ Name = "TreeTrunk", Color = bark, Material = Enum.Material.Wood, Parent = folder }, 6, 1.4, CFrame.new(base + Vector3.new(0, 10.5, 0)))
	for b = 1, 4 do
		local yaw = math.rad(seed * 37 + b * 90)
		local branch = CFrame.new(base + Vector3.new(0, 6 + b * 2, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(50), 0, 0)
		decor({ Name = "TreeBranch", Size = Vector3.new(0.6, 5, 0.6), CFrame = branch * CFrame.new(0, 2.5, 0), Color = bark, Material = Enum.Material.Wood, Parent = folder })
		for t = -1, 1, 2 do
			local twig = branch * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(t * 35))
			decor({ Name = "TreeTwig", Size = Vector3.new(0.35, 2.6, 0.35), CFrame = twig * CFrame.new(0, 1.3, 0), Color = bark, Material = Enum.Material.Wood, Parent = folder })
		end
	end
end

local function graveyard(folder: Folder, centerX: number)
	-- Les tombes regardent la place (avant = -Z)
	local towardPlaza = if centerX < 0 then math.rad(-90) else math.rad(90)
	local stone = rgb(105, 105, 115)
	for col, dx in { -8, 0, 8 } do
		for row, dz in { -13, -4.5, 4.5, 13 } do
			local seed = col * 4 + row
			local base = CFrame.new(centerX + dx, 0, dz) * CFrame.Angles(0, towardPlaza, 0) * CFrame.Angles(0, 0, math.rad((seed % 5 - 2) * 3))
			if seed % 3 == 0 then
				decor({ Name = "GraveCross", Size = Vector3.new(0.6, 4.4, 0.6), CFrame = base * CFrame.new(0, 2.2, 0), Color = stone, Material = Enum.Material.Slate, CanCollide = true, Parent = folder })
				decor({ Name = "GraveCross", Size = Vector3.new(2.4, 0.6, 0.6), CFrame = base * CFrame.new(0, 3.2, 0), Color = stone, Material = Enum.Material.Slate, Parent = folder })
			else
				decor({ Name = "Grave", Size = Vector3.new(3, 2.6, 0.8), CFrame = base * CFrame.new(0, 1.3, 0), Color = stone, Material = Enum.Material.Slate, CanCollide = true, Parent = folder })
				decor({
					Name = "GraveTop",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.8, 3, 3),
					CFrame = base * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(90), 0),
					Color = stone,
					Material = Enum.Material.Slate,
					Parent = folder,
				})
			end
			-- Tertre de terre devant la tombe
			decor({ Name = "GraveMound", Size = Vector3.new(2.6, 0.5, 4.5), CFrame = base * CFrame.new(0, 0.2, -2.8), Color = rgb(55, 42, 32), Material = Enum.Material.Ground, Parent = folder })
			if seed % 4 == 1 then
				local candle = base * CFrame.new(1.2, 0, -1)
				cylinder({ Name = "Candle", Color = rgb(235, 230, 215), Material = Enum.Material.SmoothPlastic, Parent = folder }, 0.8, 0.35, candle * CFrame.new(0, 0.4, 0))
				flame(folder, candle * CFrame.new(0, 0.95, 0), 0.25, 8, true)
			end
		end
	end

	-- Grille basse avec un portail côté place
	local x0, x1 = centerX - 15, centerX + 15
	local gateX = if centerX < 0 then x1 else x0
	local backX = if centerX < 0 then x0 else x1
	fence(folder, Vector3.new(backX, 0, -20), Vector3.new(backX, 0, 20), 3.5)
	fence(folder, Vector3.new(x0, 0, -20), Vector3.new(x1, 0, -20), 3.5)
	fence(folder, Vector3.new(x0, 0, 20), Vector3.new(x1, 0, 20), 3.5)
	fence(folder, Vector3.new(gateX, 0, -20), Vector3.new(gateX, 0, -4), 3.5)
	fence(folder, Vector3.new(gateX, 0, 4), Vector3.new(gateX, 0, 20), 3.5)

	-- Mausolée derrière la grille du fond, porte vers la place
	local outward = if centerX < 0 then -1 else 1
	local m = CFrame.new(backX + outward * 7, 0, 0) * CFrame.Angles(0, towardPlaza, 0)
	decor({ Name = "Mausoleum", Size = Vector3.new(10, 9, 8), CFrame = m * CFrame.new(0, 4.5, 0), Color = rgb(120, 118, 125), Material = Enum.Material.Concrete, CanCollide = true, Parent = folder })
	decor({ Name = "MausoleumDoor", Size = Vector3.new(3, 5.5, 0.2), CFrame = m * CFrame.new(0, 2.75, -4.05), Color = rgb(15, 12, 18), Material = Enum.Material.SmoothPlastic, Parent = folder })
	decor({ Name = "MausoleumRoof", Size = Vector3.new(11, 1, 9), CFrame = m * CFrame.new(0, 9.5, 0), Color = rgb(90, 88, 95), Material = Enum.Material.Slate, Parent = folder })
	for _, s in { -1, 1 } do
		cylinder({ Name = "MausoleumColumn", Color = rgb(170, 165, 175), Material = Enum.Material.Marble, Parent = folder }, 9, 1, m * CFrame.new(s * 3.8, 4.5, -4.6))
	end
	local lamp = ball({ Name = "MausoleumLight", Color = rgb(80, 255, 140), Material = Enum.Material.Neon, Parent = folder }, 0.8, m * CFrame.new(0, 7, -4.4))
	light(lamp, rgb(80, 255, 140), 18, 1.5)
	lamp:SetAttribute("Flicker", true)

	-- Brume épaisse et feux follets
	mist(folder, CFrame.new(centerX, 1, 0), Vector3.new(30, 1, 40), 4)
	local wispZone = decor({ Name = "WispZone", Size = Vector3.new(26, 4, 36), CFrame = CFrame.new(centerX, 3, 0), Transparency = 1, Parent = folder })
	wisps(wispZone, rgb(120, 255, 170), 3)
end

-- `hotelXs` : position X de chaque porte d'hôtel (ouvertures dans la grille)
function MapDecor.decoratePlaza(map: Folder, hotelXs: { number })
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = map

	fountain(folder)

	-- Bancs autour de la fontaine, tournés vers elle
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local position = Vector3.new(math.cos(angle) * 16, 0, math.sin(angle) * 16)
		-- Avant (-Z) vers la fontaine, dossier (+Z) côté extérieur
		bench(folder, CFrame.lookAt(position, Vector3.new(0, 0, 0)))
	end

	-- Lampadaires
	local n = 0
	for _, x in { -105, -35, 35, 105 } do
		for _, z in { -50, 50 } do
			n += 1
			lampPost(folder, x, z, n % 3 == 0)
		end
	end

	-- Grille autour de la place : une ouverture devant chaque hôtel
	-- et un portail vers chaque cimetière
	local halfX, halfZ, gap = 110, 65, 9
	local openings = table.clone(hotelXs)
	table.sort(openings)
	for _, z in { -halfZ, halfZ } do
		local cursor = -halfX
		for _, hx in openings do
			fence(folder, Vector3.new(cursor, 0, z), Vector3.new(hx - gap, 0, z), 3.6)
			cursor = hx + gap
		end
		fence(folder, Vector3.new(cursor, 0, z), Vector3.new(halfX, 0, z), 3.6)
	end
	for _, x in { -halfX, halfX } do
		fence(folder, Vector3.new(x, 0, -halfZ), Vector3.new(x, 0, -gap), 3.6)
		fence(folder, Vector3.new(x, 0, gap), Vector3.new(x, 0, halfZ), 3.6)
		for _, z in { -gap, gap } do
			decor({ Name = "GatePillar", Size = Vector3.new(1.8, 5, 1.8), CFrame = CFrame.new(x, 2.5, z), Color = rgb(120, 115, 125), Material = Enum.Material.Concrete, CanCollide = true, Parent = folder })
			flame(folder, CFrame.new(x, 5.6, z), 0.5, 12, false)
		end
	end

	-- Buissons dans les coins de la place
	for _, x in { -92, 92 } do
		for _, z in { -57, 57 } do
			ball({ Name = "Bush", Color = rgb(35, 70, 40), Material = Enum.Material.Grass, Parent = folder }, 4, CFrame.new(x, 1.5, z))
			ball({ Name = "Bush", Color = rgb(30, 60, 38), Material = Enum.Material.Grass, Parent = folder }, 3, CFrame.new(x + 2.2, 1.1, z + 0.8))
		end
	end

	-- Arbres morts tout autour
	local treeSpots = {
		Vector3.new(-175, 0, -45), Vector3.new(-165, 0, 55), Vector3.new(175, 0, -55), Vector3.new(168, 0, 48),
		Vector3.new(-125, 0, -175), Vector3.new(30, 0, -185), Vector3.new(-40, 0, 185), Vector3.new(125, 0, 178),
		Vector3.new(-200, 0, 0), Vector3.new(200, 0, 10), Vector3.new(-135, 0, 110), Vector3.new(140, 0, -115),
		Vector3.new(-115, 0, 175), Vector3.new(105, 0, -180), Vector3.new(-30, 0, -190), Vector3.new(45, 0, 190),
	}
	for i, spot in treeSpots do
		deadTree(folder, spot, i)
	end

	-- Cimetières à l'est et à l'ouest
	graveyard(folder, -150)
	graveyard(folder, 150)

	-- Brume sur la place
	for _, x in { -55, 55 } do
		for _, z in { -32, 32 } do
			mist(folder, CFrame.new(x, 1, z), Vector3.new(100, 1, 55), 3)
		end
	end
end

return MapDecor
