--!strict
-- Verrou de base : le propriétaire ferme sa porte pendant un temps (60 s + bonus),
-- puis doit attendre avant de pouvoir reverrouiller.
-- La barrière bloque tout le monde sauf le propriétaire et les clients (groupes de collision).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ShopConfig = require(Config:WaitForChild("ShopConfig"))
local CollisionGroups = require(Server:WaitForChild("Modules"):WaitForChild("CollisionGroups"))
local Notify = require(Server:WaitForChild("Modules"):WaitForChild("Notify"))
local RateLimiter = require(Server:WaitForChild("Util"):WaitForChild("RateLimiter"))
local HotelService = require(script.Parent:WaitForChild("HotelService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local LockService = {}

local lockLimiter = RateLimiter.new(2, 1)
local characterConnections: { [Player]: { RBXScriptConnection } } = {}

local function getBarrier(hotel: Model): BasePart?
	local barrier = hotel:FindFirstChild("DoorBarrier")
	return if barrier and barrier:IsA("BasePart") then barrier else nil
end

local function setBarrierLocked(hotel: Model, locked: boolean)
	local barrier = getBarrier(hotel)
	if barrier then
		barrier.CanCollide = locked
		barrier.Transparency = if locked then 0.35 else 1
	end
	hotel:SetAttribute("Locked", locked)
end

function LockService.IsLocked(hotel: Model): boolean
	return hotel:GetAttribute("Locked") == true
end

local function disconnectAll(player: Player)
	local connections = characterConnections[player]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	characterConnections[player] = nil
end

-- Le personnage du propriétaire traverse sa propre barrière
local function onHotelAssigned(player: Player, hotel: Model)
	local index = hotel:GetAttribute("HotelIndex") :: number
	local group = CollisionGroups.owner(index)
	local connections: { RBXScriptConnection } = {}
	characterConnections[player] = connections
	local function onCharacter(character: Model)
		table.insert(connections, CollisionGroups.assign(character, group))
	end
	if player.Character then
		onCharacter(player.Character)
	end
	table.insert(connections, player.CharacterAdded:Connect(onCharacter))
	player:SetAttribute("LockEndsAt", nil)
	player:SetAttribute("LockReadyAt", nil)
end

local function onHotelReleased(player: Player, hotel: Model)
	disconnectAll(player)
	setBarrierLocked(hotel, false)
	if player.Character then
		CollisionGroups.assign(player.Character, "Default"):Disconnect()
	end
end

local function onLockRequest(player: Player)
	if not lockLimiter:allow(player) then
		return
	end
	local hotel = HotelService.GetHotel(player)
	local data = PlayerDataService.GetData(player)
	if not hotel or not data then
		return
	end
	local now = workspace:GetServerTimeNow()
	local readyAt = (player:GetAttribute("LockReadyAt") :: number?) or 0
	if now < readyAt then
		return
	end

	local duration = ShopConfig.lockDuration(data.SecurityUpgrades.LockPlus or 0)
	local endsAt = now + duration
	player:SetAttribute("LockEndsAt", endsAt)
	player:SetAttribute("LockReadyAt", endsAt + ShopConfig.Lock.Cooldown)
	setBarrierLocked(hotel, true)
	Notify.send(player, `Porte verrouillée pendant {duration} s`, "Good")

	task.delay(duration, function()
		-- Toujours le même propriétaire et le même verrouillage ?
		if HotelService.GetHotel(player) == hotel and player:GetAttribute("LockEndsAt") == endsAt then
			setBarrierLocked(hotel, false)
			Notify.send(player, "Ta porte est déverrouillée !", "Bad")
		end
	end)
end

function LockService.Init(_self: typeof(LockService))
	HotelService.HotelAssigned:Connect(onHotelAssigned)
	HotelService.HotelReleased:Connect(onHotelReleased)
	Players.PlayerRemoving:Connect(disconnectAll)
	Remotes.getEvent("LockRequest").OnServerEvent:Connect(onLockRequest)
end

function LockService.Start(_self: typeof(LockService))
	CollisionGroups.setup(GameConfig.HotelCount)
	local hotels = workspace:WaitForChild("Map"):WaitForChild("Hotels")
	for _, hotel in hotels:GetChildren() do
		local index = hotel:GetAttribute("HotelIndex")
		local barrier = hotel:IsA("Model") and getBarrier(hotel)
		if typeof(index) == "number" and barrier then
			barrier.CollisionGroup = CollisionGroups.barrier(index)
		end
	end
end

return LockService
