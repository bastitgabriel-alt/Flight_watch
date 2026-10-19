--!strict
-- Construit la carte et attribue un hôtel libre à chaque joueur qui arrive.
-- L'hôtel est libéré quand le joueur quitte.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local MapBuilder = require(Server:WaitForChild("Modules"):WaitForChild("MapBuilder"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local HotelService = {}

-- (player, hotel) : un hôtel vient d'être attribué
HotelService.HotelAssigned = Signal.new()
-- (player, hotel) : le joueur part, l'hôtel va être libéré
HotelService.HotelReleased = Signal.new()

local hotels: { Model } = {}
local ownerOf: { [Model]: Player } = {}
local hotelOf: { [Player]: Model } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function setSignText(hotel: Model, text: string)
	local sign = hotel:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("OwnerLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Téléporte le personnage du joueur devant son comptoir
local function teleportHome(player: Player, character: Model)
	local hotel = hotelOf[player]
	local spawnPart = hotel and hotel:FindFirstChild("OwnerSpawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end
	-- On attend que le personnage soit complètement chargé
	local root = character:WaitForChild("HumanoidRootPart", 5)
	-- Petit délai : Roblox place d'abord le personnage sur le SpawnLocation
	task.wait(0.2)
	if root and character.Parent and hotelOf[player] == hotel then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	end
end

local function assignHotel(player: Player)
	if hotelOf[player] or player.Parent ~= Players then
		return
	end
	local hotel: Model? = nil
	for _, candidate in hotels do
		if not ownerOf[candidate] then
			hotel = candidate
			break
		end
	end
	if not hotel then
		-- Ne devrait pas arriver si « Max Players » = nombre d'hôtels
		warn(`[HotelService] Aucun hôtel libre pour {player.Name}`)
		player:Kick("Ce serveur est plein (tous les hôtels sont pris). Rejoins un autre serveur !")
		return
	end

	ownerOf[hotel] = player
	hotelOf[player] = hotel
	hotel:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("HotelIndex", hotel:GetAttribute("HotelIndex"))
	setSignText(hotel, `Hôtel de {player.DisplayName}`)

	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		task.spawn(teleportHome, player, player.Character)
	end

	HotelService.HotelAssigned:Fire(player, hotel)
end

local function releaseHotel(player: Player)
	local hotel = hotelOf[player]
	if not hotel then
		return
	end
	HotelService.HotelReleased:Fire(player, hotel)

	hotelOf[player] = nil
	ownerOf[hotel] = nil
	hotel:SetAttribute("OwnerUserId", nil)
	setSignText(hotel, "Hôtel libre")

	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

function HotelService.GetHotel(player: Player): Model?
	return hotelOf[player]
end

function HotelService.GetOwner(hotel: Model): Player?
	return ownerOf[hotel]
end

function HotelService.Init(_self: typeof(HotelService))
	local map = MapBuilder.build()
	local hotelsFolder = map:WaitForChild("Hotels")
	for _, child in hotelsFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("HotelIndex") then
			table.insert(hotels, child)
		end
	end
	table.sort(hotels, function(a, b)
		return (a:GetAttribute("HotelIndex") :: number) < (b:GetAttribute("HotelIndex") :: number)
	end)

	PlayerDataService.DataLoaded:Connect(assignHotel)
	Players.PlayerRemoving:Connect(releaseHotel)
end

return HotelService
