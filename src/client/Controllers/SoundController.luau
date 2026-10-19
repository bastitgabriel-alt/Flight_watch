--!strict
-- Sons et petit « jumpscare » (flash rouge) quand une anomalie s'infiltre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("SoundConfig"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local SoundController = {}

local sounds: { [string]: Sound } = {}
local flash: Frame

function SoundController.Play(name: string)
	local sound = sounds[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

local function scare()
	SoundController.Play("Scare")
	flash.BackgroundTransparency = 0.25
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

function SoundController.Start(_self: typeof(SoundController))
	for name, entry in SoundConfig do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = entry.Id
		sound.Volume = entry.Volume
		sound.Parent = SoundService
		sounds[name] = sound
	end

	local gui = UI.new("ScreenGui", {
		Name = "Flash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 0, 0),
		BackgroundTransparency = 1,
		Active = false,
		Parent = gui,
	})

	Remotes.getEvent("Notify").OnClientEvent:Connect(function(_text, kind)
		if kind == "Good" then
			SoundController.Play("Good")
		elseif kind == "Bad" then
			SoundController.Play("Bad")
		end
	end)
	Remotes.getEvent("ReceptionResult").OnClientEvent:Connect(function(_token, outcome)
		if outcome == "Escaped" then
			scare()
		elseif outcome == "WrongCapture" then
			SoundController.Play("Bad")
		else
			SoundController.Play("Good")
		end
	end)
end

return SoundController
