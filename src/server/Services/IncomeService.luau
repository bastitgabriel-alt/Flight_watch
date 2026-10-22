--!strict
-- Revenu passif : chaque seconde, les anomalies en cellule rapportent de l'argent.
-- Le revenu par seconde est publié dans l'attribut « Income » du joueur (pour l'UI).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local RebirthConfig = require(Config:WaitForChild("RebirthConfig"))
local IncomeCalculator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("IncomeCalculator"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EventService = require(script.Parent:WaitForChild("EventService"))

local IncomeService = {}

type Debuff = { multiplier: number, endsAt: number }
local debuffs: { [Player]: Debuff } = {}

-- Multiplicateur temporaire (ex. anomalie échappée : x0.5 pendant 30 s)
function IncomeService.ApplyDebuff(player: Player, multiplier: number, duration: number)
	local endsAt = workspace:GetServerTimeNow() + duration
	debuffs[player] = { multiplier = multiplier, endsAt = endsAt }
	player:SetAttribute("DebuffEndsAt", endsAt)
	player:SetAttribute("DebuffMultiplier", multiplier)
end

local function getDebuffMultiplier(player: Player): number
	local debuff = debuffs[player]
	if not debuff then
		return 1
	end
	if workspace:GetServerTimeNow() >= debuff.endsAt then
		debuffs[player] = nil
		player:SetAttribute("DebuffEndsAt", nil)
		player:SetAttribute("DebuffMultiplier", nil)
		return 1
	end
	return debuff.multiplier
end

-- Revenu par seconde actuel du joueur (tous multiplicateurs compris)
function IncomeService.GetIncome(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	-- Gamepass « Argent x2 » : attribut posé par MonetizationService
	local passMultiplier = if player:GetAttribute("Pass_DoubleMoney") then 2 else 1
	local event = EventService.Current()
	local eventMultiplier = if event then event.IncomeMultiplier or 1 else 1
	-- Bonus amis (attribut posé par SocialService)
	local friendMultiplier = 1 + ((player:GetAttribute("FriendBoost") :: number?) or 0)
	local multiplier = RebirthConfig.incomeMultiplier(data.Rebirths)
		* getDebuffMultiplier(player)
		* passMultiplier
		* eventMultiplier
		* friendMultiplier
	return IncomeCalculator.total(data.Anomalies, multiplier)
end

local function refreshIncome(player: Player)
	player:SetAttribute("Income", IncomeService.GetIncome(player))
end

function IncomeService.Init(_self: typeof(IncomeService))
	AnomalyService.AnomaliesChanged:Connect(refreshIncome)
	Players.PlayerRemoving:Connect(function(player)
		debuffs[player] = nil
	end)
end

function IncomeService.Start(_self: typeof(IncomeService))
	local tick = EconomyConfig.IncomeTickSeconds
	while true do
		task.wait(tick)
		for _, player in Players:GetPlayers() do
			if PlayerDataService.IsLoaded(player) then
				local income = IncomeService.GetIncome(player)
				player:SetAttribute("Income", income)
				if income > 0 then
					-- TimeScale : accélération du temps (commande debug !temps)
					local timeScale = (player:GetAttribute("TimeScale") :: number?) or 1
					PlayerDataService.AddMoney(player, income * tick * timeScale)
				end
			end
		end
	end
end

return IncomeService
