--!strict
-- Cache les invites « Recevoir » des clients des autres hôtels :
-- chaque joueur ne voit que celles de son propre hôtel.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function updatePrompt(prompt: ProximityPrompt)
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	local owner = model and model:GetAttribute("OwnerUserId")
	-- Modification locale : n'affecte que l'écran de ce joueur
	prompt.Enabled = owner == nil or owner == player.UserId
end

function PromptController.Start(_self: typeof(PromptController))
	local guests = workspace:WaitForChild("Guests")
	guests.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant)
		end
	end)
	for _, descendant in guests:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			updatePrompt(descendant)
		end
	end
end

return PromptController
