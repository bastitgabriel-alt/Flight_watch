--!strict
-- Effets d'ambiance, calculés seulement sur l'écran du joueur (rien ne passe
-- par le réseau) :
--   * lumières qui grésillent (pièces avec l'attribut Flicker)
--   * anomalies qui flottent dans leur cellule (modèles avec l'attribut Hover)
--   * éclairs de temps en temps

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LIGHTNING_MIN_DELAY = 50
local LIGHTNING_MAX_DELAY = 110
local HOVER_BOB = 0.25 -- amplitude du balancement (studs)
local HOVER_SPEED = 1.6

local AmbienceController = {}

type Hovering = { root: BasePart, base: CFrame, height: number, phase: number }
local hovering: { [Model]: Hovering } = {}
local flickering: { [BasePart]: boolean } = {}

-- Grésillement : de longs moments allumée, puis quelques clignotements rapides
local function flicker(part: BasePart)
	if flickering[part] then
		return
	end
	flickering[part] = true
	task.spawn(function()
		local lights: { [Light]: number } = {}
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				lights[child] = child.Brightness
			end
		end
		local transparency = part.Transparency
		while part.Parent do
			task.wait(4 + math.random() * 10)
			for _ = 1, math.random(2, 6) do
				for lightObject in lights do
					lightObject.Brightness = 0.05
				end
				part.Transparency = math.min(transparency + 0.7, 1)
				task.wait(0.03 + math.random() * 0.1)
				for lightObject, brightness in lights do
					lightObject.Brightness = brightness
				end
				part.Transparency = transparency
				task.wait(0.04 + math.random() * 0.15)
			end
		end
		flickering[part] = nil
	end)
end

local function track(instance: Instance)
	if instance:IsA("BasePart") and instance:GetAttribute("Flicker") then
		flicker(instance)
	elseif instance:IsA("Model") then
		local height = instance:GetAttribute("Hover")
		local root = instance:WaitForChild("HumanoidRootPart", 5)
		if typeof(height) == "number" and root and root:IsA("BasePart") and root.Anchored then
			hovering[instance] = { root = root, base = root.CFrame, height = height, phase = math.random() * math.pi * 2 }
		end
	end
end

local function lightningStrike()
	-- Le tonnerre arrive juste après l'éclair
	task.delay(0.4, function()
		local SoundController = require(script.Parent:WaitForChild("SoundController")) :: any
		SoundController.Play("Thunder")
	end)
	local exposure = Lighting.ExposureCompensation
	local ambient = Lighting.OutdoorAmbient
	for _, duration in { 0.07, 0.05, 0.12 } do
		Lighting.ExposureCompensation = exposure + 2
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 255)
		task.wait(duration)
		Lighting.ExposureCompensation = exposure
		Lighting.OutdoorAmbient = ambient
		task.wait(0.08 + math.random() * 0.1)
	end
end

function AmbienceController.Start(_self: typeof(AmbienceController))
	workspace.DescendantAdded:Connect(function(instance)
		if instance:GetAttribute("Flicker") or instance:GetAttribute("Hover") then
			task.spawn(track, instance)
		end
	end)
	for _, instance in workspace:GetDescendants() do
		if instance:GetAttribute("Flicker") or instance:GetAttribute("Hover") then
			task.spawn(track, instance)
		end
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, entry in hovering do
			if not model.Parent or not entry.root.Parent or not entry.root.Anchored then
				hovering[model] = nil
			else
				local offset = entry.height + math.sin(now * HOVER_SPEED + entry.phase) * HOVER_BOB
				entry.root.CFrame = entry.base + Vector3.new(0, offset, 0)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(LIGHTNING_MIN_DELAY + math.random() * (LIGHTNING_MAX_DELAY - LIGHTNING_MIN_DELAY))
			lightningStrike()
		end
	end)
end

return AmbienceController
