--!strict
-- Raisons de revenir : gains hors ligne et récompense quotidienne (série de jours).
-- Le joueur reçoit un message « Bon retour » (WelcomeBack) à sa connexion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local IncomeCalculator = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("IncomeCalculator"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local DAY = 86400

local RetentionService = {}

-- Gains hors ligne (calcul pur, testable)
function RetentionService.offlineEarnings(data: any, now: number): (number, number)
	if data.LastSeen <= 0 then
		return 0, 0
	end
	local seconds = math.min(now - data.LastSeen, EconomyConfig.OfflineMaxSeconds)
	if seconds < EconomyConfig.OfflineMinSeconds then
		return 0, 0
	end
	local income = IncomeCalculator.total(data.Anomalies, RebirthConfig.incomeMultiplier(data.Rebirths))
	return math.floor(income * seconds * EconomyConfig.OfflineRate), seconds
end

-- Met à jour la série de jours. Renvoie (jour de la série, récompense) ou (0, 0) si déjà reçue aujourd'hui.
function RetentionService.dailyReward(data: any, now: number): (number, number)
	local today = now // DAY
	if data.LastDailyDay == today then
		return 0, 0
	end
	if data.LastDailyDay == today - 1 then
		data.LoginStreak += 1
	else
		data.LoginStreak = 1
	end
	data.LastDailyDay = today
	local rewards = EconomyConfig.DailyRewards
	local day = (data.LoginStreak - 1) % #rewards + 1
	local income = IncomeCalculator.total(data.Anomalies, RebirthConfig.incomeMultiplier(data.Rebirths))
	local amount = math.max(rewards[day], math.floor(income * EconomyConfig.DailyIncomeSeconds * day))
	return day, amount
end

local function onDataLoaded(player: Player, data: any)
	local now = os.time()
	local offline, seconds = RetentionService.offlineEarnings(data, now)
	local day, daily = RetentionService.dailyReward(data, now)
	data.LastSeen = now
	if offline + daily > 0 then
		PlayerDataService.AddMoney(player, offline + daily)
		-- Laisse l'interface se charger avant d'afficher la fenêtre
		task.delay(3, function()
			if player.Parent == Players then
				Remotes.getEvent("WelcomeBack"):FireClient(player, offline, seconds, day, daily)
			end
		end)
	end
	player:SetAttribute("LoginStreak", data.LoginStreak)
end

function RetentionService.Init(_self: typeof(RetentionService))
	PlayerDataService.DataLoaded:Connect(onDataLoaded)
end

function RetentionService.Start(_self: typeof(RetentionService))
	-- Présence notée régulièrement (si le serveur s'arrête brutalement)
	while true do
		task.wait(60)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local data = PlayerDataService.GetData(player)
			if data then
				data.LastSeen = now
			end
		end
	end
end

return RetentionService
