--!strict
-- Événements du serveur (Lune de Sang, Panne de courant, Ruée fantôme).
-- L'état est publié dans les attributs de workspace, lus par les clients :
--   EventId        événement en cours (absent = aucun)
--   EventEndsAt    fin de l'événement (workspace:GetServerTimeNow())
--   NextEventAt    début du prochain événement

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EventConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EventConfig"))
local Notify = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Notify"))
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

local EventService = {}

-- (eventId?) : un événement commence (id) ou se termine (nil)
EventService.Changed = Signal.new()

local current: EventConfig.EventDef? = nil
local rng = Random.new()
local forced: string? = nil

function EventService.Current(): EventConfig.EventDef?
	return current
end

local function pickEvent(): EventConfig.EventDef
	local total = 0
	for _, event in EventConfig.Events do
		total += event.Weight
	end
	local roll = rng:NextNumber() * total
	for _, event in EventConfig.Events do
		roll -= event.Weight
		if roll < 0 then
			return event
		end
	end
	return EventConfig.Events[1]
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function runEvent(event: EventConfig.EventDef)
	current = event
	workspace:SetAttribute("EventId", event.Id)
	workspace:SetAttribute("EventEndsAt", now() + EventConfig.Duration)
	workspace:SetAttribute("NextEventAt", nil)
	Notify.sendAll(`{event.DisplayName} ! {event.Description}`, event.Color)
	EventService.Changed:Fire(event.Id)

	local endsAt = now() + EventConfig.Duration
	while now() < endsAt and current == event do
		task.wait(1)
	end
	if current == event then
		current = nil
		workspace:SetAttribute("EventId", nil)
		workspace:SetAttribute("EventEndsAt", nil)
		Notify.sendAll(`Fin de l'événement : {event.DisplayName}`, "Info")
		EventService.Changed:Fire(nil)
	end
end

-- Debug : lance tout de suite un événement (ou arrête l'événement en cours)
function EventService.Force(id: string?)
	if id == nil then
		current = nil
		workspace:SetAttribute("EventId", nil)
		workspace:SetAttribute("EventEndsAt", nil)
		EventService.Changed:Fire(nil)
		return
	end
	forced = id
	current = nil -- termine l'événement en cours, le forcé démarre juste après
end

function EventService.Start(_self: typeof(EventService))
	local nextAt = now() + EventConfig.FirstDelay
	workspace:SetAttribute("NextEventAt", nextAt)
	while true do
		task.wait(1)
		if forced then
			local event = EventConfig.get(forced)
			forced = nil
			if event then
				current = nil
				runEvent(event)
				nextAt = now() + EventConfig.Interval
				workspace:SetAttribute("NextEventAt", nextAt)
			end
		elseif now() >= nextAt and current == nil then
			runEvent(pickEvent())
			nextAt = now() + EventConfig.Interval
			workspace:SetAttribute("NextEventAt", nextAt)
		end
	end
end

return EventService
