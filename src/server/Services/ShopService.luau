--!strict
-- Boutique : cellules supplémentaires, outils de détection, améliorations de sécurité.
-- Le client envoie seulement « je veux acheter X » ; le serveur vérifie le prix et l'argent.
-- Ce que possède le joueur est publié en attributs (lus par l'interface) :
--   CellsUnlocked, Tool_<id> = true, Sec_<id> = niveau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ShopConfig = require(Config:WaitForChild("ShopConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Notify = require(Server:WaitForChild("Modules"):WaitForChild("Notify"))
local Analytics = require(Server:WaitForChild("Modules"):WaitForChild("Analytics"))
local RateLimiter = require(Server:WaitForChild("Util"):WaitForChild("RateLimiter"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local ShopService = {}

local buyLimiter = RateLimiter.new(4, 1)

local function publishOwnership(player: Player, data: any)
	player:SetAttribute("CellsUnlocked", data.CellsUnlocked)
	for toolId in ShopConfig.Tools do
		player:SetAttribute(`Tool_{toolId}`, data.Tools[toolId] == true)
	end
	for upgradeId in ShopConfig.Security do
		player:SetAttribute(`Sec_{upgradeId}`, data.SecurityUpgrades[upgradeId] or 0)
	end
end

local function pay(player: Player, price: number, itemName: string): boolean
	if PlayerDataService.TrySpend(player, price) then
		local data = PlayerDataService.GetData(player)
		if data then
			Analytics.first(player, data, "ShopPurchase")
		end
		Notify.send(player, `Acheté : {itemName} (-{Format.money(price)})`, "Good")
		return true
	end
	Notify.send(player, `Pas assez d'argent pour {itemName}`, "Bad")
	return false
end

local function onBuy(player: Player, category: any, itemId: any)
	if typeof(category) ~= "string" or typeof(itemId) ~= "string" or not buyLimiter:allow(player) then
		return
	end
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	if category == "Cell" then
		local purchased = data.CellsUnlocked - GameConfig.BaseCells
		local price = ShopConfig.nextCellPrice(purchased)
		if price and pay(player, price, "Cellule") then
			data.CellsUnlocked += 1
			AnomalyService.RefreshCells(player)
		end
	elseif category == "Tool" then
		local tool = (ShopConfig.Tools :: any)[itemId]
		if tool and not data.Tools[itemId] and pay(player, tool.Price, tool.DisplayName) then
			data.Tools[itemId] = true
		end
	elseif category == "Security" then
		local upgrade = (ShopConfig.Security :: any)[itemId]
		local level = data.SecurityUpgrades[itemId] or 0
		local price = ShopConfig.nextSecurityPrice(itemId, level)
		if upgrade and price and pay(player, price, `{upgrade.DisplayName} niv. {level + 1}`) then
			data.SecurityUpgrades[itemId] = level + 1
		end
	end
	publishOwnership(player, data)
end

function ShopService.Init(_self: typeof(ShopService))
	PlayerDataService.DataLoaded:Connect(publishOwnership)
	Remotes.getEvent("ShopBuy").OnServerEvent:Connect(onBuy)
end

return ShopService
