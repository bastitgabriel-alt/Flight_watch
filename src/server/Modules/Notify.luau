--!strict
-- Envoie un message à afficher en haut de l'écran d'un joueur.
-- kind : "Info" (blanc), "Good" (vert), "Bad" (rouge), ou une couleur Color3

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Notify = {}

function Notify.send(player: Player, text: string, kind: (string | Color3)?)
	Remotes.getEvent("Notify"):FireClient(player, text, kind or "Info")
end

return Notify
