--!strict
-- Construit la carte placeholder : une place centrale et 6 hôtels (3 de chaque côté).
-- Si un dossier Workspace.Map existe déjà (carte faite à la main), on ne fait rien.
--
-- Pour remplacer un hôtel par un vrai modèle plus tard, garder ces noms :
--   Hotel{n} (attribut HotelIndex)
--     GuestSpawn, GuestSpot, GuestExit, OwnerSpawn, Lobby  (repères invisibles)
--     DoorBarrier, Sign (SurfaceGui > OwnerLabel)
--     Cells > Cell{n} > Pad, Spot, Label (SurfaceGui > Text)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local MapDecor = require(script.Parent:WaitForChild("MapDecor"))
local PartFactory = require(script.Parent:WaitForChild("PartFactory"))

-- Dimensions (studs)
local HOTEL_SIZE = 56
local WALL_HEIGHT = 16
local DOOR_WIDTH = 12
local HOTEL_SPACING = 70
local HOTEL_DISTANCE = 100 -- distance entre le centre de la place et le centre d'un hôtel
local CELL_WIDTH = 6.5

local MapBuilder = {}

local makePart = PartFactory.part
local makeMarker = PartFactory.marker

-- Une cellule de confinement. « local » = repère de l'hôtel.
local function buildCell(index: number, origin: CFrame, localCFrame: CFrame, parent: Instance)
	local cell = Instance.new("Model")
	cell.Name = `Cell{index}`
	cell:SetAttribute("CellIndex", index)

	local cf = origin * localCFrame -- l'avant de la cellule (ouverture) = LookVector

	local pad = makePart({
		Name = "Pad",
		Size = Vector3.new(CELL_WIDTH - 0.5, 0.4, CELL_WIDTH - 0.5),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.DiamondPlate,
		Parent = cell,
	})

	-- Vitre décorative (traversable, pour le futur vol)
	makePart({
		Name = "Glass",
		Size = Vector3.new(CELL_WIDTH - 0.5, 8, 0.3),
		CFrame = cf * CFrame.new(0, 4.4, -(CELL_WIDTH / 2 - 0.4)),
		Color = Color3.fromRGB(150, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CanCollide = false,
		CastShadow = false,
		Parent = cell,
	})

	-- Liseré lumineux autour du pad (couleur de la rareté, voir AnomalyService)
	local trims = Instance.new("Folder")
	trims.Name = "Trim"
	trims.Parent = cell
	local edge = CELL_WIDTH - 0.5
	for _, offset in { CFrame.new(0, 0.45, edge / 2), CFrame.new(0, 0.45, -edge / 2), CFrame.new(edge / 2, 0.45, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(-edge / 2, 0.45, 0) * CFrame.Angles(0, math.rad(90), 0) } do
		PartFactory.decor({
			Name = "TrimStrip",
			Size = Vector3.new(edge, 0.12, 0.25),
			CFrame = cf * offset,
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
			Parent = trims,
		})
	end

	-- Où l'anomalie se tient : sur le pad, tournée vers l'ouverture
	makeMarker("Spot", cf * CFrame.new(0, 0.4, 0), cell)

	-- Panneau au-dessus de la vitre (nom, rareté, revenu). Un panneau fixe
	-- plutôt qu'une étiquette flottante : les 16 textes ne se chevauchent pas.
	local sign = makePart({
		Name = "Label",
		Size = Vector3.new(CELL_WIDTH - 0.5, 2, 0.2),
		CFrame = cf * CFrame.new(0, 9.5, -(CELL_WIDTH / 2 - 0.4)),
		Color = Color3.fromRGB(20, 15, 25),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
		Parent = cell,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front -- côté ouverture de la cellule
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = sign

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = ""
	text.Parent = surface

	cell.PrimaryPart = pad
	cell.Parent = parent
end

local function buildHotel(index: number, origin: CFrame, parent: Instance)
	local hotel = Instance.new("Model")
	hotel.Name = `Hotel{index}`
	hotel:SetAttribute("HotelIndex", index)

	local half = HOTEL_SIZE / 2
	local wallColor = MapDecor.wallColor(index)

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(HOTEL_SIZE, 1, HOTEL_SIZE),
		CFrame = origin * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(105, 64, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = hotel,
	})

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hotel
	local function wall(name: string, size: Vector3, localPos: Vector3)
		makePart({
			Name = name,
			Size = size,
			CFrame = origin * CFrame.new(localPos),
			Color = wallColor,
			Material = Enum.Material.Brick,
			Parent = walls,
		})
	end
	local y = 1 + WALL_HEIGHT / 2
	wall("Back", Vector3.new(HOTEL_SIZE, WALL_HEIGHT, 1), Vector3.new(0, y, -half))
	wall("Left", Vector3.new(1, WALL_HEIGHT, HOTEL_SIZE), Vector3.new(-half, y, 0))
	wall("Right", Vector3.new(1, WALL_HEIGHT, HOTEL_SIZE), Vector3.new(half, y, 0))
	-- Façade avec une ouverture pour la porte (avant = +Z local, vers la place)
	local sideWidth = (HOTEL_SIZE - DOOR_WIDTH) / 2
	wall("FrontLeft", Vector3.new(sideWidth, WALL_HEIGHT, 1), Vector3.new(-(DOOR_WIDTH + sideWidth) / 2, y, half))
	wall("FrontRight", Vector3.new(sideWidth, WALL_HEIGHT, 1), Vector3.new((DOOR_WIDTH + sideWidth) / 2, y, half))
	wall("FrontTop", Vector3.new(DOOR_WIDTH, 4, 1), Vector3.new(0, 1 + WALL_HEIGHT - 2, half))

	-- Barrière de la porte (verrou de base, utilisée à l'étape 7)
	makePart({
		Name = "DoorBarrier",
		Size = Vector3.new(DOOR_WIDTH, WALL_HEIGHT - 4, 1),
		CFrame = origin * CFrame.new(0, 1 + (WALL_HEIGHT - 4) / 2, half),
		Color = Color3.fromRGB(255, 50, 50),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = hotel,
	})

	-- Comptoir de la réception
	makePart({
		Name = "Counter",
		Size = Vector3.new(14, 4, 2.5),
		CFrame = origin * CFrame.new(0, 3, 12),
		Color = Color3.fromRGB(60, 35, 25),
		Material = Enum.Material.Wood,
		Parent = hotel,
	})

	-- Repères (le client regarde le comptoir, donc vers -Z local)
	local facingCounter = CFrame.identity -- LookVector = -Z local
	makeMarker("GuestSpawn", origin * CFrame.new(0, 1, half + 8) * facingCounter, hotel)
	-- Assez loin du comptoir pour que la caméra se glisse entre les deux
	makeMarker("GuestSpot", origin * CFrame.new(0, 1, 19.5) * facingCounter, hotel)
	makeMarker("GuestExit", origin * CFrame.new(half + 10, 1, half + 8), hotel)
	makeMarker("OwnerSpawn", origin * CFrame.new(0, 1, 7) * CFrame.Angles(0, math.pi, 0), hotel)
	local lobby = makeMarker("Lobby", origin * CFrame.new(0, 1, 0), hotel)
	lobby.Size = Vector3.new(40, 1, 16) -- zone où erre une anomalie échappée

	-- Lumière au-dessus du client : rend son ombre bien visible
	local lightHolder = makeMarker("GuestLight", origin * CFrame.new(0, 12, 20), hotel)
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 0.9
	light.Shadows = true
	light.Parent = lightHolder

	-- Enseigne au-dessus de la porte, lisible depuis la place
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(24, 4, 0.5),
		CFrame = CFrame.lookAt(
			(origin * CFrame.new(0, WALL_HEIGHT + 3.5, half + 0.6)).Position,
			(origin * CFrame.new(0, WALL_HEIGHT + 3.5, half + 10)).Position
		),
		Color = Color3.fromRGB(30, 20, 30),
		Material = Enum.Material.SmoothPlastic,
		Parent = hotel,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Name = "OwnerLabel"
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.TextScaled = true
	signText.Font = Enum.Font.Creepster
	signText.TextColor3 = Color3.fromRGB(255, 220, 120)
	signText.Text = "Hôtel libre"
	signText.Parent = surface

	-- Cellules : 8 le long du mur du fond, puis 4 sur chaque côté
	local cells = Instance.new("Folder")
	cells.Name = "Cells"
	cells.Parent = hotel
	local cellIndex = 0
	local backZ = -half + CELL_WIDTH / 2 + 0.5
	for i = 0, 7 do
		cellIndex += 1
		local x = -half + 1 + CELL_WIDTH / 2 + i * CELL_WIDTH
		-- Ouverture vers +Z (vers le centre de l'hôtel)
		buildCell(cellIndex, origin, CFrame.new(x, 1, backZ) * CFrame.Angles(0, math.pi, 0), cells)
	end
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			cellIndex += 1
			local x = side * (half - CELL_WIDTH / 2 - 0.5)
			local z = backZ + CELL_WIDTH * (i + 1.5)
			-- Ouverture vers le centre de l'hôtel
			local look = CFrame.lookAt(Vector3.new(x, 1, z), Vector3.new(0, 1, z))
			buildCell(cellIndex, origin, look, cells)
		end
	end
	assert(cellIndex >= GameConfig.MaxCells, "Pas assez d'emplacements de cellules construits")

	MapDecor.decorateHotel(hotel, origin, { Index = index, Size = HOTEL_SIZE, WallHeight = WALL_HEIGHT, DoorWidth = DOOR_WIDTH })

	hotel.PrimaryPart = floor
	hotel.Parent = parent
end

function MapBuilder.build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	-- Le sol est en terrain (herbe), voir MapDecor.setupTerrain
	MapDecor.setupTerrain()
	makePart({
		Name = "Plaza",
		Size = Vector3.new(220, 0.4, 130),
		CFrame = CFrame.new(0, 0.2, 0),
		Color = Color3.fromRGB(110, 110, 115),
		Material = Enum.Material.Cobblestone,
		Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.9, 30) -- la fontaine occupe le centre
	spawn.Neutral = true
	spawn.Duration = 0 -- pas de bouclier d'apparition
	spawn.Color = Color3.fromRGB(80, 40, 90)
	spawn.Parent = map

	-- Panneau du classement mondial, au bord ouest de la place, tourné vers le centre
	local board = makePart({
		Name = "Leaderboard",
		Size = Vector3.new(26, 16, 1),
		CFrame = CFrame.lookAt(Vector3.new(-104, 9, 0), Vector3.new(0, 9, 0)),
		Color = Color3.fromRGB(25, 18, 30),
		Material = Enum.Material.SmoothPlastic,
		Parent = map,
	})
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 30
	boardGui.Parent = board
	local boardTitle = Instance.new("TextLabel")
	boardTitle.Size = UDim2.fromScale(1, 0.16)
	boardTitle.BackgroundTransparency = 1
	boardTitle.TextScaled = true
	boardTitle.Font = Enum.Font.Creepster
	boardTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
	boardTitle.Text = "Meilleurs revenus"
	boardTitle.Parent = boardGui
	local boardLines = Instance.new("TextLabel")
	boardLines.Name = "Lines"
	boardLines.Position = UDim2.fromScale(0.05, 0.18)
	boardLines.Size = UDim2.fromScale(0.9, 0.78)
	boardLines.BackgroundTransparency = 1
	boardLines.TextScaled = true
	boardLines.TextXAlignment = Enum.TextXAlignment.Left
	boardLines.TextYAlignment = Enum.TextYAlignment.Top
	boardLines.Font = Enum.Font.GothamBold
	boardLines.TextColor3 = Color3.new(1, 1, 1)
	boardLines.Text = "Chargement..."
	boardLines.Parent = boardGui

	local hotels = Instance.new("Folder")
	hotels.Name = "Hotels"
	hotels.Parent = map

	-- 3 hôtels au nord (porte vers le sud), 3 au sud (porte vers le nord)
	local perSide = math.ceil(GameConfig.HotelCount / 2)
	local hotelXs: { number } = {}
	for index = 1, GameConfig.HotelCount do
		local north = index <= perSide
		local column = if north then index - 1 else index - perSide - 1
		local x = (column - (perSide - 1) / 2) * HOTEL_SPACING
		local origin
		if north then
			origin = CFrame.new(x, 0, -HOTEL_DISTANCE)
		else
			origin = CFrame.new(x, 0, HOTEL_DISTANCE) * CFrame.Angles(0, math.pi, 0)
		end
		buildHotel(index, origin, hotels)
		if not table.find(hotelXs, x) then
			table.insert(hotelXs, x)
		end
	end

	MapDecor.decoratePlaza(map, hotelXs)
	MapDecor.setupLighting()

	map.Parent = workspace
	return map
end

return MapBuilder
