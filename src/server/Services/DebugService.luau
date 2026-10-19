--!strict
-- Commandes de test, à taper dans le chat (Studio, ou UserId dans GameConfig.AdminUserIds) :
--   !argent 1000              donne de l'argent
--   !anomalie Doppelganger    ajoute une anomalie (mutation optionnelle : Golden, Neon)
--   !prochain anomalie        le prochain client sera une anomalie
--   !prochain normal          le prochain client sera un vrai client
--   !prochain TheOwner        le prochain client sera cette anomalie précise
--   !pass DoubleMoney         simule un gamepass (DoubleMoney ou ExtraCells), jusqu'au départ
--   !chance                   lance une « Nuit chanceuse » de 10 min
--   !temps 10                 accélère le temps x10 (revenus et clients) ; !temps 1 pour revenir
--   !tuto                     relance le tutoriel
--   !reset                    remet tes données à zéro

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local MutationConfig = require(Config:WaitForChild("MutationConfig"))
local Notify = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Notify"))
local AnomalyService = require(script.Parent:WaitForChild("AnomalyService"))
local GuestService = require(script.Parent:WaitForChild("GuestService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local DebugService = {}

local function isAllowed(player: Player): boolean
	if GameConfig.DebugInStudio and RunService:IsStudio() then
		return true
	end
	return table.find(GameConfig.AdminUserIds, player.UserId) ~= nil
end

local commands: { [string]: (player: Player, args: { string }) -> () } = {}

commands.argent = function(player, args)
	local amount = tonumber(args[1])
	if not amount then
		Notify.send(player, "Usage : !argent 1000", "Bad")
		return
	end
	PlayerDataService.AddMoney(player, amount)
	Notify.send(player, `+{amount} $ (debug)`, "Good")
end

commands.anomalie = function(player, args)
	local id = args[1]
	local mutation = args[2] or "None"
	if not id or not AnomalyConfig.ById[id] then
		local ids = {}
		for _, def in AnomalyConfig.List do
			table.insert(ids, def.Id)
		end
		Notify.send(player, "Ids : " .. table.concat(ids, ", "), "Bad")
		return
	end
	if not MutationConfig.Mutations[mutation :: any] then
		Notify.send(player, "Mutation : None, Golden ou Neon", "Bad")
		return
	end
	local cell = AnomalyService.AddAnomaly(player, id, mutation :: any)
	Notify.send(player, if cell then `Ajoutée en cellule {cell}` else "Cellules pleines", "Info")
end

commands.prochain = function(player, args)
	local what = args[1]
	if what == "anomalie" then
		GuestService.ForceNext(player, { ForceAnomaly = true })
	elseif what == "normal" then
		GuestService.ForceNext(player, { ForceAnomaly = false })
	elseif what and AnomalyConfig.ById[what] then
		GuestService.ForceNext(player, { ForceAnomalyId = what })
	else
		Notify.send(player, "Usage : !prochain anomalie | normal | <Id>", "Bad")
		return
	end
	Notify.send(player, "Prochain client réglé (debug)", "Info")
end

commands.pass = function(player, args)
	local name = args[1]
	if name ~= "DoubleMoney" and name ~= "ExtraCells" then
		Notify.send(player, "Usage : !pass DoubleMoney | ExtraCells", "Bad")
		return
	end
	player:SetAttribute(`Pass_{name}`, true)
	AnomalyService.RefreshCells(player)
	AnomalyService.AnomaliesChanged:Fire(player)
	Notify.send(player, `Gamepass {name} simulé (debug)`, "Good")
end

commands.chance = function(player)
	local data = PlayerDataService.GetData(player)
	if data then
		data.LuckyUntil = os.time() + 600
		player:SetAttribute("LuckyUntil", data.LuckyUntil)
		Notify.send(player, "Nuit chanceuse lancée (debug)", "Good")
	end
end

commands.temps = function(player, args)
	local scale = tonumber(args[1])
	if not scale or scale < 1 or scale > 100 then
		Notify.send(player, "Usage : !temps 10 (entre 1 et 100)", "Bad")
		return
	end
	player:SetAttribute("TimeScale", if scale == 1 then nil else scale)
	Notify.send(player, `Temps x{scale} (debug)`, "Good")
end

commands.tuto = function(player)
	local data = PlayerDataService.GetData(player)
	if data then
		data.TutorialDone = false
		player:SetAttribute("TutorialDone", false)
		GuestService.ForceNext(player, { ForceAnomalyId = "Doppelganger" })
		Notify.send(player, "Tutoriel relancé (debug)", "Good")
	end
end

commands.reset = function(player)
	PlayerDataService.ResetData(player)
end

local function onChatted(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "!" or not isAllowed(player) then
		return
	end
	local words = string.split(string.sub(message, 2), " ")
	local name = string.lower(table.remove(words, 1) or "")
	local command = commands[name]
	if command then
		print(`[Debug] {player.Name} : !{name} {table.concat(words, " ")}`)
		command(player, words)
	end
end

local function onPlayerAdded(player: Player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end

function DebugService.Start(_self: typeof(DebugService))
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return DebugService
