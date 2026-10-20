--!strict
-- Sons (musique d'ambiance, sonnette, capture, alarme de vol, événements...)
-- et petit « jumpscare » (flash rouge) quand une anomalie s'infiltre.

local ContentProvider = game:GetService("ContentProvider")
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
		local id = if entry.Id ~= "" then entry.Id else entry.Fallback
		if not id then
			continue
		end
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = entry.Volume
		sound.Looped = entry.Looped == true
		sound.Parent = SoundService
		sounds[name] = sound
		-- Nos sons ne se chargent que dans le jeu publié (pas dans un fichier ouvert
		-- depuis l'ordinateur) : s'ils échouent, on met le son Roblox de secours.
		if entry.Id ~= "" then
			task.spawn(function()
				ContentProvider:PreloadAsync({ sound }, function(_, status)
					if status == Enum.AssetFetchStatus.Failure then
						warn(`[Son] {name} n'a pas pu se charger ({entry.Id})`)
						if entry.Fallback then
							sound.SoundId = entry.Fallback
						end
					end
				end)
			end)
		end
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
		elseif outcome == "Captured" or outcome == "CapturedSold" then
			SoundController.Play("Capture")
		elseif outcome == "Served" then
			SoundController.Play("Cash")
		end
	end)

	-- Musique d'ambiance
	local ambience = sounds.Ambience
	if ambience then
		ambience:Play()
	end

	-- Sonnette : un client attend à MON comptoir ; alarme : on me vole une anomalie
	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("ProximityPrompt") and instance:GetAttribute("OnlyUserId") == player.UserId then
			if instance.ActionText == "Recevoir" then
				SoundController.Play("Bell")
			elseif instance.ActionText == "Récupérer" then
				SoundController.Play("Alarm")
			end
		end
	end)

	-- Renaissance
	local lastRebirths = player:GetAttribute("Rebirths") :: number?
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		local count = player:GetAttribute("Rebirths") :: number?
		if lastRebirths and count and count > lastRebirths then
			SoundController.Play("Rebirth")
		end
		lastRebirths = count
	end)

	-- Événements
	local EVENT_SOUNDS: { [string]: string } = { BloodMoon = "Howl", Blackout = "PowerDown", GhostRush = "Thunder" }
	workspace:GetAttributeChangedSignal("EventId"):Connect(function()
		local sound = EVENT_SOUNDS[(workspace:GetAttribute("EventId") :: string?) or ""]
		if sound then
			SoundController.Play(sound)
		end
	end)
end

return SoundController
