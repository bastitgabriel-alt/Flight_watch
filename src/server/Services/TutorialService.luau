--!strict
-- Tutoriel des nouveaux joueurs (3 étapes, affiché par TutorialController).
-- Le serveur mémorise qu'il est terminé et envoie les étapes aux statistiques.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Analytics = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Analytics"))
local RateLimiter = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Util"):WaitForChild("RateLimiter"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local STEP_NAMES = { "Recevoir un client", "Prendre une décision", "Ouvrir la boutique" }

local TutorialService = {}

local limiter = RateLimiter.new(3, 1)

local function onStep(player: Player, step: any)
	if typeof(step) ~= "number" or step % 1 ~= 0 or step < 1 or step > #STEP_NAMES then
		return
	end
	local data = PlayerDataService.GetData(player)
	if not data or data.TutorialDone or not limiter:allow(player) then
		return
	end
	Analytics.funnel(player, step, STEP_NAMES[step])
	if step == #STEP_NAMES then
		data.TutorialDone = true
		player:SetAttribute("TutorialDone", true)
	end
end

function TutorialService.Init(_self: typeof(TutorialService))
	Remotes.getEvent("TutorialStep").OnServerEvent:Connect(onStep)
end

return TutorialService
