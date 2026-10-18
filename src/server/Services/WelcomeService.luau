--!strict
-- Service de test de l'étape 1 : vérifie que le client et le serveur
-- communiquent bien via les Remotes.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local RateLimiter = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Util"):WaitForChild("RateLimiter"))

local WelcomeService = {}

-- Un client n'a aucune raison d'envoyer ClientReady plus d'une fois par tranche de 10 s
local readyLimiter = RateLimiter.new(1, 10)

function WelcomeService.Start(_self: typeof(WelcomeService))
	Remotes.getEvent("ClientReady").OnServerEvent:Connect(function(player: Player)
		if not readyLimiter:allow(player) then
			return
		end
		print(`[Serveur] {player.Name} est connecté, son client est prêt`)
	end)
end

return WelcomeService
