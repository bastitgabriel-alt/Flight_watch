--!strict
-- Point d'entrée du serveur : charge tous les services du dossier Services,
-- appelle Init() sur chacun (préparation), puis Start() (démarrage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader"))
local Remotes = require(Shared:WaitForChild("Remotes"))

-- Les RemoteEvents doivent exister avant que les services s'y abonnent
Remotes.setup()

Loader.loadModules(script.Parent:WaitForChild("Services"))

print("[Serveur] Serveur prêt")
