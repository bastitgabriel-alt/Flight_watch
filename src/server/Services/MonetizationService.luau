--!strict
-- Achats Robux : gamepasses (permanents) et produits (répétables).
-- Les gamepasses possédés sont publiés en attributs Pass_<nom> (lus par les autres services).
-- ProcessReceipt est idempotent : chaque achat est enregistré dans les données
-- et on ne confirme à Roblox (PurchaseGranted) qu'une fois la sauvegarde faite.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Notify = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Notify"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local IncomeService = require(script.Parent:WaitForChild("IncomeService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local MAX_RECEIPTS_KEPT = 100 -- achats mémorisés par joueur (anti-doublon)
local SAVE_TIMEOUT = 15

local MonetizationService = {}

-- Applique les effets d'un gamepass possédé
local function grantPass(player: Player, passName: string)
	if player:GetAttribute(`Pass_{passName}`) then
		return
	end
	player:SetAttribute(`Pass_{passName}`, true)
	if passName == "ExtraCells" then
		AnomalyService.RefreshCells(player)
	end
	AnomalyService.AnomaliesChanged:Fire(player) -- recalcule le revenu
end

local function passNameFromId(passId: number): string?
	for name, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return name
		end
	end
	return nil
end

-- À la connexion : vérifie les gamepasses (avec le cache si Roblox ne répond pas)
local function checkPasses(player: Player, data: any)
	for name, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 then
			local key = tostring(pass.Id)
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok then
				data.GamepassCache[key] = owns or nil
			end
			if data.GamepassCache[key] and player.Parent == Players then
				grantPass(player, name)
			end
		end
	end
end

-- Effet d'un produit acheté. Renvoie false si l'Id est inconnu.
local function applyProduct(player: Player, data: any, productId: number): boolean
	local products = MonetizationConfig.Products
	if products.MoneyPack.Id ~= 0 and productId == products.MoneyPack.Id then
		local pack = products.MoneyPack
		local amount = math.max(pack.Minimum, math.floor(IncomeService.GetIncome(player) * pack.IncomeSeconds))
		PlayerDataService.AddMoney(player, amount)
		Notify.send(player, `Merci ! +{Format.money(amount)}`, "Good")
		return true
	elseif products.LuckyNight.Id ~= 0 and productId == products.LuckyNight.Id then
		local night = products.LuckyNight
		-- Si une nuit est déjà en cours, on prolonge
		data.LuckyUntil = math.max(data.LuckyUntil, os.time()) + night.Duration
		player:SetAttribute("LuckyUntil", data.LuckyUntil)
		Notify.send(player, "Nuit chanceuse ! Anomalies rares x3 pendant 10 min", "Good")
		return true
	end
	return false
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerDataService.GetData(player)
	if not player or not data then
		-- Le joueur n'est pas (encore) là : Roblox réessaiera plus tard
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if not data.ProcessedReceipts[purchaseId] then
		if not applyProduct(player, data, receipt.ProductId) then
			warn(`[Monetization] Produit inconnu : {receipt.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.ProcessedReceipts[purchaseId] = true
		table.insert(data.ReceiptOrder, purchaseId)
		while #data.ReceiptOrder > MAX_RECEIPTS_KEPT do
			local oldest = table.remove(data.ReceiptOrder, 1)
			data.ProcessedReceipts[oldest] = nil
		end
	end

	-- On attend que l'achat soit réellement sauvegardé avant de confirmer
	local saved = PlayerDataService.SaveAndWait(player, function(lastSaved)
		return lastSaved.ProcessedReceipts ~= nil and lastSaved.ProcessedReceipts[purchaseId] == true
	end, SAVE_TIMEOUT)
	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Init(_self: typeof(MonetizationService))
	PlayerDataService.DataLoaded:Connect(function(player, data)
		player:SetAttribute("LuckyUntil", data.LuckyUntil)
		checkPasses(player, data)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passNameFromId(passId)
		local data = PlayerDataService.GetData(player)
		if purchased and name and data then
			data.GamepassCache[tostring(passId)] = true
			grantPass(player, name)
			Notify.send(player, `Merci ! Gamepass « {MonetizationConfig.GamePasses[name].DisplayName} » activé`, "Good")
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
