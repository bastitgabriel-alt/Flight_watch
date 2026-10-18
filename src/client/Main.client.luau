--!strict
-- Point d'entrée du client : charge tous les contrôleurs du dossier Controllers,
-- appelle Init() sur chacun, puis Start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader"))

Loader.loadModules(script.Parent:WaitForChild("Controllers"))

print("[Client] Client prêt")
