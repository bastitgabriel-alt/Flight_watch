--!strict
-- Jouer avec ses amis rapporte plus :
--   * bonus de revenus pour chaque ami présent sur le serveur (attribut FriendBoost)
--   * récompense quand un ami rejoint le jeu grâce à ton invitation
--     (Roblox indique qui a invité dans les données d'arrivée du joueur)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Server = ServerScriptService:WaitForChild("Server")
local Notify = require(Server:WaitForChild("Modules"):WaitForChild("Notify"))
local Analytics = require(Server:WaitForChild("Modules"):WaitForChild("Analytics"))
local RateLimiter = require(Server:WaitForChild("Util"):WaitForChild("RateLimiter"))
local IncomeService = require(script.Parent:WaitForChild("IncomeService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local SocialService = {}

local friendships: { [Player]: { [Player]: boolean } } = {}
local inviteLimiter = RateLimiter.new(2, 10)

local function isFriend(a: Player, b: Player): boolean
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and result == true
end

local function refreshBoost(player: Player)
	local friends = friendships[player]
	local count = 0
	if friends then
		for other in friends do
			if other.Parent == Players then
				count += 1
			end
		end
	end
	local boost = math.min(count * EconomyConfig.FriendBoostPerFriend, EconomyConfig.FriendBoostMax)
	player:SetAttribute("FriendBoost", if boost > 0 then boost else nil)
	player:SetAttribute("FriendsHere", count)
end

local function onPlayerAdded(player: Player)
	friendships[player] = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendships[other] and isFriend(player, other) then
			friendships[player][other] = true
			friendships[other][player] = true
			refreshBoost(other)
			Notify.send(other, `Ton ami {player.DisplayName} est là : +{math.floor(EconomyConfig.FriendBoostPerFriend * 100)} % de revenus !`, "Good")
		end
	end
	refreshBoost(player)
end

local function onPlayerRemoving(player: Player)
	local friends = friendships[player]
	friendships[player] = nil
	if friends then
		for other in friends do
			local theirs = friendships[other]
			if theirs then
				theirs[player] = nil
				refreshBoost(other)
			end
		end
	end
end

-- Le joueur arrive grâce à une invitation : on récompense celui qui l'a invité
local function onDataLoaded(player: Player, data: any)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local referrerId = if ok and joinData then joinData.ReferredByPlayerId else nil
	if typeof(referrerId) ~= "number" or referrerId <= 0 or referrerId == player.UserId then
		return
	end
	local referrer = Players:GetPlayerByUserId(referrerId)
	local referrerData = referrer and PlayerDataService.GetData(referrer)
	if not referrer or not referrerData then
		return -- l'inviteur n'est plus sur ce serveur
	end
	local key = tostring(player.UserId)
	local count = 0
	for _ in referrerData.InvitedUsers do
		count += 1
	end
	if referrerData.InvitedUsers[key] or count >= EconomyConfig.InviteMaxRewarded then
		return
	end
	referrerData.InvitedUsers[key] = true
	local reward = math.max(
		EconomyConfig.InviteRewardMin,
		math.floor(IncomeService.GetIncome(referrer) * EconomyConfig.InviteRewardIncomeSeconds)
	)
	PlayerDataService.AddMoney(referrer, reward)
	Notify.send(referrer, `{player.DisplayName} a rejoint grâce à ton invitation ! +{Format.money(reward)}`, "Good")
	if not data.Firsts.InvitedWelcome then
		data.Firsts.InvitedWelcome = true
		PlayerDataService.AddMoney(player, EconomyConfig.InviteWelcomeBonus)
		Notify.send(player, `Cadeau de bienvenue de {referrer.DisplayName} : +{Format.money(EconomyConfig.InviteWelcomeBonus)}`, "Good")
	end
	Analytics.event(referrer, "InviteJoined")
end

function SocialService.Init(_self: typeof(SocialService))
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	PlayerDataService.DataLoaded:Connect(onDataLoaded)
	Remotes.getEvent("InviteSent").OnServerEvent:Connect(function(player)
		if inviteLimiter:allow(player) then
			Analytics.event(player, "InvitePrompt")
		end
	end)
end

return SocialService
