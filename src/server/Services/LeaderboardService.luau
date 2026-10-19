--!strict
-- Classements :
--  - dans le serveur : liste des joueurs (en haut à droite) avec revenu/s et anomalies
--  - mondial : panneau sur la place, meilleurs revenus/s de tous les temps
--    (OrderedDataStore ; indisponible dans un fichier Studio non publié)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local STAT_INCOME = "Revenu/s"
local STAT_ANOMALIES = "Anomalies"
local LOCAL_REFRESH = 2 -- secondes
local GLOBAL_WRITE = 120 -- secondes entre deux envois d'un joueur au classement mondial
local GLOBAL_READ = 60 -- secondes entre deux mises à jour du panneau
local GLOBAL_SIZE = 10

local LeaderboardService = {}

local lastWritten: { [Player]: number } = {}
local nameCache: { [number]: string } = {}

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats" -- nom imposé par Roblox
	local income = Instance.new("IntValue")
	income.Name = STAT_INCOME
	income.Parent = folder
	local anomalies = Instance.new("IntValue")
	anomalies.Name = STAT_ANOMALIES
	anomalies.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	local data = PlayerDataService.GetData(player)
	if not folder or not data then
		return
	end
	local count = 0
	for _ in data.Anomalies do
		count += 1
	end
	local income = folder:FindFirstChild(STAT_INCOME)
	local anomalies = folder:FindFirstChild(STAT_ANOMALIES)
	if income and income:IsA("IntValue") then
		income.Value = math.floor((player:GetAttribute("Income") :: number?) or 0)
	end
	if anomalies and anomalies:IsA("IntValue") then
		anomalies.Value = count
	end
end

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok then name else "?"
	nameCache[userId] = result
	return result
end

local function getBoardLabel(): TextLabel?
	local map = workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("Leaderboard")
	local label = board and board:FindFirstChild("Lines", true)
	return if label and label:IsA("TextLabel") then label else nil
end

function LeaderboardService.Init(_self: typeof(LeaderboardService))
	PlayerDataService.DataLoaded:Connect(setupLeaderstats)
	Players.PlayerRemoving:Connect(function(player)
		lastWritten[player] = nil
	end)
end

function LeaderboardService.Start(_self: typeof(LeaderboardService))
	-- Classement du serveur
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updateLeaderstats(player)
			end
			task.wait(LOCAL_REFRESH)
		end
	end)

	-- Classement mondial
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("BestIncome_v1")
	end)
	local label = getBoardLabel()
	if not ok then
		if label then
			label.Text = "Classement mondial disponible une fois le jeu publié"
		end
		return
	end

	local lastRead = 0
	while true do
		-- Envoi des revenus des joueurs (on garde leur meilleur score)
		for _, player in Players:GetPlayers() do
			local income = math.floor((player:GetAttribute("Income") :: number?) or 0)
			local last = lastWritten[player] or 0
			if income > 0 and os.clock() - last > GLOBAL_WRITE then
				lastWritten[player] = os.clock()
				pcall(function()
					store:UpdateAsync(tostring(player.UserId), function(old)
						return math.max(old or 0, income)
					end)
				end)
			end
		end

		-- Mise à jour du panneau
		if os.clock() - lastRead > GLOBAL_READ then
			lastRead = os.clock()
			local success, pages = pcall(function()
				return store:GetSortedAsync(false, GLOBAL_SIZE)
			end)
			label = getBoardLabel()
			if label then
				if success then
					local lines = {}
					for rank, entry in pages:GetCurrentPage() do
						local userId = tonumber(entry.key)
						local name = if userId then getName(userId) else "?"
						table.insert(lines, `{rank}. {name} — {Format.money(entry.value)}/s`)
					end
					label.Text = if #lines > 0 then table.concat(lines, "\n") else "Personne pour l'instant !"
				else
					label.Text = "Classement mondial disponible une fois le jeu publié"
				end
			end
		end
		task.wait(10)
	end
end

return LeaderboardService
