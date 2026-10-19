--!strict
-- Événements du serveur, côté écran : bandeau avec compte à rebours (en haut
-- à droite), grande annonce au début, et ambiance propre à chaque événement
-- (lune rouge, coupure de courant avec lampe torche, brume verte).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EventConfig"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local EventController = {}

local banner: Frame
local bannerTitle: TextLabel
local bannerInfo: TextLabel
local bannerStroke: UIStroke
local announce: TextLabel
local announceInfo: TextLabel

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function buildGui()
	local gui = UI.new("ScreenGui", {
		Name = "Events",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bannerStroke = UI.stroke(Color3.fromRGB(170, 80, 255), 2)
	banner = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(230, 58),
		BackgroundColor3 = Color3.fromRGB(15, 10, 20),
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { UI.corner(12), bannerStroke, UI.padding(6) })
	bannerTitle = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.55),
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = banner,
	})
	bannerInfo = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.fromScale(1, 0.45),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 210, 230),
		Parent = banner,
	})

	-- Grande annonce au centre de l'écran
	announce = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromScale(0.8, 0.14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})
	announceInfo = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.7, 0.05),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})
end

local function showAnnouncement(event: EventConfig.EventDef)
	announce.Text = event.DisplayName
	announce.TextColor3 = event.Color
	announceInfo.Text = event.Description
	for _, label in { announce, announceInfo } do
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	end
	announce.Size = UDim2.fromScale(1.1, 0.18)
	TweenService:Create(announce, TweenInfo.new(0.8, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.14) }):Play()
	task.delay(4, function()
		for _, label in { announce, announceInfo } do
			TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

------------------------------------------------------------------ ambiance

type Saved = { [Instance]: { [string]: any } }
local saved: Saved = {}
local flashlight: SpotLight? = nil

local function set(instance: Instance?, props: { [string]: any })
	if not instance then
		return
	end
	local backup = saved[instance] or {}
	for key, value in props do
		if backup[key] == nil then
			backup[key] = (instance :: any)[key]
		end
		(instance :: any)[key] = value
	end
	saved[instance] = backup
end

local function restoreAll()
	for instance, props in saved do
		for key, value in props do
			pcall(function()
				(instance :: any)[key] = value
			end)
		end
	end
	table.clear(saved)
	if flashlight then
		flashlight:Destroy()
		flashlight = nil
	end
end

local function giveFlashlight()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and not flashlight then
		local spot = Instance.new("SpotLight")
		spot.Name = "Flashlight"
		spot.Range = 45
		spot.Angle = 55
		spot.Brightness = 3
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 240, 210)
		spot.Face = Enum.NormalId.Front
		spot.Parent = head
		flashlight = spot
	end
end

local function applyAmbience(eventId: string?)
	restoreAll()
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if eventId == "BloodMoon" then
		-- Tout devient rouge sang
		set(sky, { MoonAngularSize = 50 })
		set(atmosphere, { Density = 0.48, Haze = 2, Color = Color3.fromRGB(200, 40, 50), Decay = Color3.fromRGB(110, 10, 20) })
		set(color, { TintColor = Color3.fromRGB(255, 150, 150), Saturation = 0.15, Contrast = 0.2 })
		set(Lighting, { OutdoorAmbient = Color3.fromRGB(160, 50, 60), Ambient = Color3.fromRGB(120, 50, 60) })
	elseif eventId == "Blackout" then
		local map = workspace:FindFirstChild("Map")
		if map then
			for _, descendant in map:GetDescendants() do
				-- Les anomalies et le contour des cellules restent visibles dans le noir
				local rig = descendant:FindFirstAncestorOfClass("Model")
				if (rig and rig:GetAttribute("Motion") ~= nil) or descendant.Name == "TrimStrip" then
					continue
				end
				if descendant:IsA("Light") then
					set(descendant, { Enabled = false })
				elseif descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
					set(descendant, { Material = Enum.Material.SmoothPlastic, Color = descendant.Color:Lerp(Color3.new(0, 0, 0), 0.6) })
				end
			end
		end
		set(Lighting, {
			Ambient = Color3.fromRGB(40, 35, 55),
			OutdoorAmbient = Color3.fromRGB(55, 50, 80),
		})
		giveFlashlight()
	elseif eventId == "GhostRush" then
		-- Brume verte épaisse
		set(atmosphere, { Density = 0.55, Haze = 2.5, Color = Color3.fromRGB(100, 220, 150), Decay = Color3.fromRGB(20, 100, 60) })
		set(color, { TintColor = Color3.fromRGB(200, 255, 215), Saturation = 0.1 })
		set(Lighting, { OutdoorAmbient = Color3.fromRGB(80, 150, 110) })
	end
end

function EventController.Start(_self: typeof(EventController))
	buildGui()

	local function onEventChanged()
		local event = EventConfig.get(workspace:GetAttribute("EventId") :: string?)
		applyAmbience(if event then event.Id else nil)
		if event then
			showAnnouncement(event)
		end
	end
	workspace:GetAttributeChangedSignal("EventId"):Connect(onEventChanged)
	if workspace:GetAttribute("EventId") then
		onEventChanged()
	end
	-- La lampe torche suit le personnage s'il réapparaît
	player.CharacterAdded:Connect(function()
		flashlight = nil
		if workspace:GetAttribute("EventId") == "Blackout" then
			task.wait(1)
			giveFlashlight()
		end
	end)

	while true do
		local now = workspace:GetServerTimeNow()
		local event = EventConfig.get(workspace:GetAttribute("EventId") :: string?)
		if event then
			local endsAt = (workspace:GetAttribute("EventEndsAt") :: number?) or now
			bannerTitle.Text = event.DisplayName
			bannerTitle.TextColor3 = event.Color
			bannerInfo.Text = `Encore {formatTime(endsAt - now)}`
			bannerStroke.Color = event.Color
		else
			local nextAt = (workspace:GetAttribute("NextEventAt") :: number?) or now
			bannerTitle.Text = "Prochain événement"
			bannerTitle.TextColor3 = Color3.fromRGB(220, 180, 255)
			bannerInfo.Text = `dans {formatTime(nextAt - now)}`
			bannerStroke.Color = Color3.fromRGB(170, 80, 255)
		end
		task.wait(0.5)
	end
end

return EventController
