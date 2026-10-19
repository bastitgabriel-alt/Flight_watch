--!strict
-- Catalogue des anomalies (Anomalydex) : publie les anomalies découvertes
-- (attributs Disc_<Id>) et verse les récompenses de paliers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local CatalogConfig = require(Config:WaitForChild("CatalogConfig"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Notify = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Notify"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CatalogService = {}

local function countDiscovered(data: any): number
	local count = 0
	for _, def in AnomalyConfig.List do
		if data.Discovered[def.Id] then
			count += 1
		end
	end
	return count
end

-- Publie le catalogue et verse les récompenses pas encore reçues
local function refresh(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	for _, def in AnomalyConfig.List do
		player:SetAttribute(`Disc_{def.Id}`, data.Discovered[def.Id] == true)
	end
	local count = countDiscovered(data)
	player:SetAttribute("DiscoveredCount", count)
	for _, reward in CatalogConfig.Rewards do
		local key = tostring(reward.Count)
		if count >= reward.Count and not data.CatalogRewards[key] then
			data.CatalogRewards[key] = true
			PlayerDataService.AddMoney(player, reward.Money)
			Notify.send(player, `Catalogue : {reward.Count} anomalies découvertes ! +{Format.money(reward.Money)}`, "Good")
		end
	end
end

function CatalogService.Init(_self: typeof(CatalogService))
	PlayerDataService.DataLoaded:Connect(refresh)
	AnomalyService.Discovered:Connect(refresh)
end

return CatalogService
