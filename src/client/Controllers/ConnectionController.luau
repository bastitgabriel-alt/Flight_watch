--!strict
-- Contrôleur de test de l'étape 1 : prévient le serveur que le client a chargé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ConnectionController = {}

function ConnectionController.Start(_self: typeof(ConnectionController))
	Remotes.getEvent("ClientReady"):FireServer()
end

return ConnectionController
