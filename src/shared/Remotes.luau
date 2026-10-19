--!strict
-- Déclaration centralisée de tous les RemoteEvents et RemoteFunctions.
-- Pour ajouter un remote : ajouter son nom dans EVENT_NAMES ou FUNCTION_NAMES.
-- Le serveur les crée (Remotes.setup), le client les attend (Remotes.getEvent).
--
-- Rappel sécurité : le client n'envoie que des INTENTIONS. Le serveur vérifie
-- toujours les arguments, la distance, la propriété et la fréquence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES: { string } = {
	"Notify", -- serveur -> client : (text, kind) message à afficher
	"ReceptionShow", -- serveur -> client : (ReceptionInfo) ouvre la réception
	"ReceptionDecision", -- client -> serveur : (token, "Accept" | "Capture")
	"ReceptionResult", -- serveur -> client : (token, outcome, details)
	"ShopBuy", -- client -> serveur : ("Cell" | "Tool" | "Security", itemId)
	"LockRequest", -- client -> serveur : verrouiller sa porte
	"TutorialStep", -- client -> serveur : (numéro d'étape terminée)
	"RebirthRequest", -- client -> serveur : renaître
	"WelcomeBack", -- serveur -> client : (gains hors ligne, secondes, jour de série, récompense du jour)
}

-- Client -> serveur, avec réponse (à utiliser avec parcimonie)
local FUNCTION_NAMES: { string } = {}

local Remotes = {}

local function isDeclared(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

-- Serveur uniquement : crée le dossier et tous les remotes déclarés
function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup() ne peut être appelé que par le serveur")

	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	assert(folder)

	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getFolder(): Instance
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.getEvent(name: string): RemoteEvent
	assert(isDeclared(EVENT_NAMES, name), `RemoteEvent non déclaré : {name}`)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	assert(isDeclared(FUNCTION_NAMES, name), `RemoteFunction non déclarée : {name}`)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
