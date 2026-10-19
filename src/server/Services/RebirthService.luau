--!strict
-- Renaissance : le joueur paie le prix, perd son argent et ses anomalies, et
-- gagne des bonus permanents (revenus, chance, nouvelles anomalies).
-- Le nombre de renaissances est publié dans l'attribut « Rebirths » du joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RebirthConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Server = ServerScriptService:WaitForChild("Server")
local Notify = require(Server:WaitForChild("Modules"):WaitForChild("Notify"))
local Analytics = require(Server:WaitForChild("Modules"):WaitForChild("Analytics"))
local RateLimiter = require(Server:WaitForChild("Util"):WaitForChild("RateLimiter"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local RebirthService = {}

local limiter = RateLimiter.new(1, 2)

local function publish(player: Player, data: any)
	player:SetAttribute("Rebirths", data.Rebirths)
end

-- free = true : sans payer (commande debug)
function RebirthService.Rebirth(player: Player, free: boolean?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end
	if data.Rebirths >= RebirthConfig.MaxRebirths then
		Notify.send(player, "Tu as atteint la renaissance maximale !", "Bad")
		return
	end
	local cost = RebirthConfig.cost(data.Rebirths)
	if not free and data.Money < cost then
		Notify.send(player, `Il te faut {Format.money(cost)} pour renaître`, "Bad")
		return
	end

	AnomalyService.ClearAll(player)
	data.Rebirths += 1
	data.RebirthMultiplier = RebirthConfig.incomeMultiplier(data.Rebirths)
	PlayerDataService.AddMoney(player, -data.Money)
	PlayerDataService.AddMoney(player, RebirthConfig.StartMoneyPerRebirth * data.Rebirths)
	publish(player, data)
	AnomalyService.AnomaliesChanged:Fire(player)
	Analytics.event(player, "Rebirth", data.Rebirths)

	Notify.send(player, `Renaissance {data.Rebirths} ! Revenus x{data.RebirthMultiplier} pour toujours`, Color3.fromRGB(255, 200, 80))
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Notify.send(other, `{player.DisplayName} vient de renaître (renaissance {data.Rebirths}) !`, "Info")
		end
	end
end

function RebirthService.Init(_self: typeof(RebirthService))
	PlayerDataService.DataLoaded:Connect(publish)
	Remotes.getEvent("RebirthRequest").OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			RebirthService.Rebirth(player, false)
		end
	end)
end

return RebirthService
