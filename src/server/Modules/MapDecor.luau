--!strict
-- Habillage de la carte : ambiance (lumière, brume), décor des hôtels et de la place.
-- Purement visuel : rien ici ne doit gêner les chemins des clients ni la caméra
-- de réception (vérifié par tests/run.luau).

local Lighting = game:GetService("Lighting")

local PartFactory = require(script.Parent:WaitForChild("PartFactory"))

local decor = PartFactory.decor
local light = PartFactory.light
local rgb = Color3.fromRGB

local WARM_LIGHT = rgb(255, 196, 130)

export type HotelLayout = {
	Size: number,
	WallHeight: number,
	DoorWidth: number,
}

local MapDecor = {}

-- Cylindre debout (les cylindres Roblox sont couchés sur l'axe X)
local function standingCylinder(props: { [string]: any }, height: number, diameter: number, position: Vector3): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return decor(props)
end

-- Ambiance : coucher de soleil violet, brume légère, éclairage réaliste
function MapDecor.setupLighting()
	Lighting.ClockTime = 18.6
	Lighting.Brightness = 2
	Lighting.Ambient = rgb(70, 60, 85)
	Lighting.OutdoorAmbient = rgb(110, 95, 130)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(200, 170, 230)
	atmosphere.Decay = rgb(90, 60, 120)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.3
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Contrast = 0.1
	color.Saturation = -0.08
	color.TintColor = rgb(238, 228, 255)
	color.Parent = Lighting
end

function MapDecor.decorateHotel(hotel: Model, origin: CFrame, layout: HotelLayout)
	local half = layout.Size / 2
	local top = 1 + layout.WallHeight -- haut des murs
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = hotel

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Toit (avec un léger débord)
	decor({
		Name = "Roof",
		Size = Vector3.new(layout.Size + 2, 1, layout.Size + 2),
		CFrame = at(0, top + 0.5, 0),
		Color = rgb(45, 35, 50),
		Material = Enum.Material.Slate,
		CanCollide = true,
		Parent = folder,
	})

	-- Plafonniers (pas d'ombre : seule la lampe au-dessus du client en fait)
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
			light(panel, WARM_LIGHT, 26, 1.3)
		end
	end

	-- Tapis rouge de la porte au comptoir
	decor({
		Name = "Carpet",
		Size = Vector3.new(8, 0.1, 13),
		CFrame = at(0, 1.05, 21),
		Color = rgb(120, 20, 35),
		Material = Enum.Material.Fabric,
		Parent = folder,
	})

	-- Comptoir : plateau en marbre, sonnette, registre, petite lampe
	decor({
		Name = "CounterTop",
		Size = Vector3.new(15, 0.4, 3),
		CFrame = at(0, 5.2, 12),
		Color = rgb(225, 220, 230),
		Material = Enum.Material.Marble,
		CanCollide = true,
		Parent = folder,
	})
	decor({
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 0.7, 0.7),
		CFrame = at(3, 5.7, 12),
		Color = rgb(230, 180, 60),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	decor({
		Name = "Ledger",
		Size = Vector3.new(1.8, 0.25, 1.2),
		CFrame = at(-2.5, 5.55, 12) * CFrame.Angles(0, math.rad(10), 0),
		Color = rgb(90, 30, 30),
		Material = Enum.Material.Fabric,
		Parent = folder,
	})
	local lamp = decor({
		Name = "DeskLamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = at(-6, 6, 12),
		Color = rgb(255, 210, 140),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	light(lamp, WARM_LIGHT, 10, 1)

	-- Plantes dans les coins près de l'entrée
	for _, x in { -(half - 3), half - 3 } do
		standingCylinder({
			Name = "Pot",
			Color = rgb(90, 55, 40),
			Material = Enum.Material.Concrete,
			Parent = folder,
		}, 2.5, 2.5, origin * Vector3.new(x, 2.25, half - 3))
		decor({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.5, 3.5, 3.5),
			CFrame = at(x, 4.6, half - 3),
			Color = rgb(40, 95, 50),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
	end

	-- Façade : fenêtres lumineuses, auvent, montants de porte, lanternes
	local sideCenter = (layout.DoorWidth + (layout.Size - layout.DoorWidth) / 2) / 2
	for _, side in { -1, 1 } do
		decor({
			Name = "Window",
			Size = Vector3.new(8, 5, 0.2),
			CFrame = at(side * sideCenter, 9, half + 0.6),
			Color = rgb(255, 200, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			Parent = folder,
		})
		decor({
			Name = "DoorPillar",
			Size = Vector3.new(1, layout.WallHeight - 4, 1),
			CFrame = at(side * (layout.DoorWidth / 2 + 0.5), 1 + (layout.WallHeight - 4) / 2, half + 0.6),
			Color = rgb(60, 35, 25),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		standingCylinder({
			Name = "LanternPost",
			Color = rgb(30, 25, 30),
			Material = Enum.Material.Metal,
			Parent = folder,
		}, 6, 0.5, origin * Vector3.new(side * (layout.DoorWidth / 2 + 2.5), 4, half + 2))
		local flame = decor({
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = at(side * (layout.DoorWidth / 2 + 2.5), 7.5, half + 2),
			Color = rgb(255, 150, 60),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		light(flame, rgb(255, 150, 70), 14, 1.5)
	end
	-- Fenêtres sur les côtés
	for _, side in { -1, 1 } do
		for _, z in { -12, 6 } do
			decor({
				Name = "SideWindow",
				Size = Vector3.new(0.2, 5, 7),
				CFrame = at(side * (half + 0.6), 9, z),
				Color = rgb(255, 200, 120),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				Parent = folder,
			})
		end
	end
	decor({
		Name = "Awning",
		Size = Vector3.new(layout.DoorWidth + 4, 0.5, 4),
		CFrame = at(0, layout.WallHeight - 2.5, half + 2.2) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = rgb(130, 25, 45),
		Material = Enum.Material.Fabric,
		Parent = folder,
	})

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
end

function MapDecor.decoratePlaza(map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = map

	-- Fontaine au centre de la place
	standingCylinder({
		Name = "FountainBasin",
		Color = rgb(120, 115, 125),
		Material = Enum.Material.Cobblestone,
		CanCollide = true,
		Parent = folder,
	}, 2, 18, Vector3.new(0, 1, 0))
	standingCylinder({
		Name = "FountainWater",
		Color = rgb(90, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = folder,
	}, 0.2, 15, Vector3.new(0, 2.05, 0))
	standingCylinder({
		Name = "FountainPillar",
		Color = rgb(150, 145, 155),
		Material = Enum.Material.Marble,
		CanCollide = true,
		Parent = folder,
	}, 6, 2, Vector3.new(0, 4, 0))
	local orb = decor({
		Name = "FountainOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(0, 8.5, 0),
		Color = rgb(150, 90, 255),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	light(orb, rgb(170, 110, 255), 30, 2)

	-- Lampadaires
	for _, x in { -105, -35, 35, 105 } do
		for _, z in { -50, 50 } do
			standingCylinder({
				Name = "LampPost",
				Color = rgb(30, 25, 35),
				Material = Enum.Material.Metal,
				CanCollide = true,
				Parent = folder,
			}, 10, 0.8, Vector3.new(x, 5, z))
			local bulb = decor({
				Name = "LampBulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.8, 1.8, 1.8),
				CFrame = CFrame.new(x, 10.6, z),
				Color = rgb(255, 210, 150),
				Material = Enum.Material.Neon,
				Parent = folder,
			})
			light(bulb, WARM_LIGHT, 28, 1.6)
		end
	end

	-- Arbres morts et tombes autour de la place (hors des chemins)
	local treeSpots = {
		Vector3.new(-170, 0, -40), Vector3.new(-160, 0, 60), Vector3.new(170, 0, -60), Vector3.new(165, 0, 45),
		Vector3.new(-120, 0, -175), Vector3.new(30, 0, -180), Vector3.new(-40, 0, 180), Vector3.new(120, 0, 175),
	}
	for index, base in treeSpots do
		standingCylinder({
			Name = "TreeTrunk",
			Color = rgb(55, 40, 35),
			Material = Enum.Material.Wood,
			CanCollide = true,
			Parent = folder,
		}, 14, 2, base + Vector3.new(0, 7, 0))
		for b = 1, 3 do
			local angle = math.rad(index * 47 + b * 120)
			decor({
				Name = "TreeBranch",
				Size = Vector3.new(0.6, 6, 0.6),
				CFrame = CFrame.new(base + Vector3.new(0, 10 + b, 0))
					* CFrame.Angles(0, angle, 0)
					* CFrame.Angles(math.rad(50), 0, 0)
					* CFrame.new(0, 3, 0),
				Color = rgb(55, 40, 35),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	local graves = {
		Vector3.new(-150, 0, 0), Vector3.new(-150, 0, 12), Vector3.new(-150, 0, -12),
		Vector3.new(150, 0, 0), Vector3.new(150, 0, 12), Vector3.new(150, 0, -12),
	}
	for _, base in graves do
		decor({
			Name = "Grave",
			Size = Vector3.new(3, 4, 0.8),
			CFrame = CFrame.new(base + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(90), math.rad(4)),
			Color = rgb(100, 100, 110),
			Material = Enum.Material.Slate,
			CanCollide = true,
			Parent = folder,
		})
	end
end

return MapDecor
