--!strict
-- Bouton « Verrouiller » : ferme la porte de son hôtel aux autres joueurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudBar = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("HudBar"))

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(60, 110, 200)
local LOCKED_COLOR = Color3.fromRGB(190, 40, 50)
local COOLDOWN_COLOR = Color3.fromRGB(80, 80, 90)

local LockController = {}

function LockController.Start(_self: typeof(LockController))
	local button = HudBar.addButton("Verrou", 3, READY_COLOR)

	button.Activated:Connect(function()
		Remotes.getEvent("LockRequest"):FireServer()
	end)

	while true do
		local now = workspace:GetServerTimeNow()
		local endsAt = (player:GetAttribute("LockEndsAt") :: number?) or 0
		local readyAt = (player:GetAttribute("LockReadyAt") :: number?) or 0
		if now < endsAt then
			button.Text = `🔒 {math.ceil(endsAt - now)} s`
			button.BackgroundColor3 = LOCKED_COLOR
		elseif now < readyAt then
			button.Text = `⏳ {math.ceil(readyAt - now)} s`
			button.BackgroundColor3 = COOLDOWN_COLOR
		else
			button.Text = "🔒 Verrouiller"
			button.BackgroundColor3 = READY_COLOR
		end
		task.wait(0.25)
	end
end

return LockController
