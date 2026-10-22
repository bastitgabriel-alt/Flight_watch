--!strict
-- Bouton « Inviter des amis » (en haut à droite, sous le bandeau des événements).
-- Ouvre la fenêtre d'invitation de Roblox ; la récompense est donnée par le
-- serveur quand l'ami rejoint (SocialService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local InviteController = {}

local function openInvite()
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and canInvite then
		Remotes.getEvent("InviteSent"):FireServer()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end
end

function InviteController.Start(_self: typeof(InviteController))
	local gui = UI.new("ScreenGui", {
		Name = "Invite",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local button = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 74),
		Size = UDim2.fromOffset(230, 40),
		BackgroundColor3 = Color3.fromRGB(40, 150, 90),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = `📨 Invite un ami : +{Format.money(EconomyConfig.InviteRewardMin)}`,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(Color3.new(0, 0, 0), 2), UI.padding(6) })
	button.Activated:Connect(openInvite)

	-- Petit battement pour attirer l'œil toutes les 20 secondes
	local scale = UI.new("UIScale", { Parent = button })
	task.spawn(function()
		while true do
			task.wait(20)
			scale.Scale = 1.12
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
		end
	end)
end

return InviteController
