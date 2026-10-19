--!strict
-- Affiche chaque invite (ProximityPrompt) seulement aux bons joueurs :
--   attribut OnlyUserId   -> visible uniquement par ce joueur (ex. « Recevoir »)
--   attribut ExceptUserId -> visible par tous sauf ce joueur (ex. « Voler »)

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function updatePrompt(prompt: ProximityPrompt)
	local only = prompt:GetAttribute("OnlyUserId")
	local except = prompt:GetAttribute("ExceptUserId")
	-- Modification locale : n'affecte que l'écran de ce joueur
	if only ~= nil then
		prompt.Enabled = only == player.UserId
	elseif except ~= nil then
		prompt.Enabled = except ~= player.UserId
	end
end

function PromptController.Start(_self: typeof(PromptController))
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			-- Les attributs arrivent avec l'objet ; on attend une image par sécurité
			task.defer(updatePrompt, descendant)
		end
	end)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant)
		end
	end
end

return PromptController
