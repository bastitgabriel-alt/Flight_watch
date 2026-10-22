--!strict
-- Écran de la réception : la caméra cadre le client, on compare ses indices
-- (registre, photo d'identité, ombre, yeux) puis on choisit
-- « Donner la clé » ou « Capturer ». Le serveur décide du résultat.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local GuestConfig = require(Config:WaitForChild("GuestConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local RigAppearance = require(Shared:WaitForChild("Util"):WaitForChild("RigAppearance"))
local ReceptionCamera = require(Shared:WaitForChild("Util"):WaitForChild("ReceptionCamera"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RESULT_DURATION = 2.5

-- Description des indices pour le message d'explication
local CLUE_TEXT: { [string]: { [string]: string } } = {
	Registry = { Strong = "nom absent du registre", Subtle = "nom mal écrit dans le registre" },
	Shadow = { Strong = "pas d'ombre", Subtle = "pas d'ombre" },
	Eyes = { Strong = "yeux rouges lumineux", Subtle = "petits yeux orangés" },
	Photo = { Strong = "photo différente", Subtle = "pantalon différent sur la photo" },
	UV = { Strong = "traces fluorescentes (lampe UV)" },
	Thermal = { Strong = "corps glacé (scanner thermique)" },
}

local ReceptionController = {}

local gui: ScreenGui
local panel: Frame
local speechLabel: TextLabel
local timerBar: Frame
local photoFrame: ViewportFrame
local cardName: TextLabel
local registryList: Frame
local acceptButton: TextButton
local captureButton: TextButton
local resultLabel: TextLabel
local toolsLabel: TextLabel

local current: Types.ReceptionInfo? = nil
local cameraFocused = false

local function makeButton(name: string, text: string, color: Color3, position: UDim2): TextButton
	return UI.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0, 1),
		Position = position,
		Size = UDim2.new(0.48, 0, 0.17, 0),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = panel,
	}, { UI.corner(14), UI.stroke(Color3.new(0, 0, 0), 2), UI.padding(8), UI.textSize(16, 30) })
end

local function buildGui()
	gui = UI.new("ScreenGui", {
		Name = "Reception",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Panneau à droite de l'écran : le client reste bien visible à gauche
	panel = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.42, 0, 0.94, 0),
		BackgroundColor3 = Color3.fromRGB(25, 18, 30),
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(Color3.fromRGB(120, 80, 140), 2),
		UI.padding(10),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(440, 600), MinSize = Vector2.new(250, 280) }),
	})

	speechLabel = UI.new("TextLabel", {
		Name = "Speech",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.86, 0, 0.11, 0),
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = panel,
	}, { UI.textSize(12, 22) })

	UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.12, 0, 0.09, 0),
		BackgroundColor3 = Color3.fromRGB(70, 60, 80),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		Parent = panel,
	}, { UI.corner(8), UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }) }).Activated:Connect(function()
		ReceptionController.Close()
	end)

	-- Barre de temps restant
	local timerBack = UI.new("Frame", {
		Name = "TimerBack",
		Position = UDim2.fromScale(0, 0.125),
		Size = UDim2.new(1, 0, 0.02, 0),
		BackgroundColor3 = Color3.fromRGB(50, 40, 55),
		Parent = panel,
	}, { UI.corner(4) })
	timerBar = UI.new("Frame", {
		Name = "Timer",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 80),
		Parent = timerBack,
	}, { UI.corner(4) })

	-- Carte d'identité (à gauche)
	local card = UI.new("Frame", {
		Name = "IdCard",
		Position = UDim2.fromScale(0, 0.165),
		Size = UDim2.new(1, 0, 0.255, 0),
		BackgroundColor3 = Color3.fromRGB(235, 225, 200),
		Parent = panel,
	}, { UI.corner(10), UI.padding(6) })
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.16),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(60, 40, 30),
		Text = "CARTE D'IDENTITÉ",
		Parent = card,
	})
	photoFrame = UI.new("ViewportFrame", {
		Name = "Photo",
		Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.fromScale(1, 0.62),
		BackgroundColor3 = Color3.fromRGB(180, 200, 220),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		Parent = card,
	}, { UI.corner(6) })
	cardName = UI.new("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.82),
		Size = UDim2.fromScale(1, 0.18),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(30, 20, 15),
		Text = "",
		Parent = card,
	})

	-- Registre des réservations (à droite)
	local registry = UI.new("Frame", {
		Name = "Registry",
		Position = UDim2.fromScale(0, 0.43),
		Size = UDim2.new(1, 0, 0.285, 0),
		BackgroundColor3 = Color3.fromRGB(245, 240, 225),
		Parent = panel,
	}, { UI.corner(10), UI.padding(6) })
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.16),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(90, 30, 30),
		Text = "REGISTRE DES RÉSERVATIONS",
		Parent = registry,
	})
	registryList = UI.new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.fromScale(1, 0.82),
		Parent = registry,
	}, {
		UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})

	-- Résultats des outils de détection (lampe UV, scanner thermique)
	toolsLabel = UI.new("TextLabel", {
		Name = "Tools",
		Position = UDim2.fromScale(0, 0.725),
		Size = UDim2.new(1, 0, 0.08, 0),
		BackgroundColor3 = Color3.fromRGB(40, 30, 50),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		RichText = true,
		Text = "",
		Parent = panel,
	}, { UI.corner(8), UI.padding(4), UI.textSize(10, 18) })

	acceptButton = makeButton("Accept", "🔑 Donner la clé", Color3.fromRGB(40, 160, 80), UDim2.fromScale(0, 1))
	captureButton = makeButton("Capture", "🪤 Capturer", Color3.fromRGB(190, 40, 50), UDim2.fromScale(0.52, 1))

	-- Résultat affiché au centre de l'écran (ScreenGui à part, toujours actif)
	local resultGui = UI.new("ScreenGui", {
		Name = "ReceptionResult",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	resultLabel = UI.new("TextLabel", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(0.9, 0, 0.18, 0),
		BackgroundColor3 = Color3.fromRGB(15, 10, 20),
		BackgroundTransparency = 0.2,
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Visible = false,
		Parent = resultGui,
	}, {
		UI.corner(14),
		UI.padding(10),
		UI.textSize(16, 34),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(600, 160) }),
	})
end

-- Affiche la photo d'identité dans le ViewportFrame
local function showPhoto(appearance: Types.Appearance)
	photoFrame:ClearAllChildren()
	UI.corner(6).Parent = photoFrame
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("GuestRig")
	if not template or not template:IsA("Model") then
		return
	end
	local rig = template:Clone()
	RigAppearance.apply(rig, appearance)
	rig:PivotTo(CFrame.new())
	rig.Parent = photoFrame

	local head = rig:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local photoCamera = Instance.new("Camera")
		photoCamera.FieldOfView = 40
		-- Cadrage tête et épaules, de face
		local target = head.Position - Vector3.new(0, 0.5, 0)
		photoCamera.CFrame = CFrame.lookAt(target + head.CFrame.LookVector * 4.5, target)
		photoCamera.Parent = photoFrame
		photoFrame.CurrentCamera = photoCamera
	end
end

local function showRegistry(names: { string })
	for _, child in registryList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, name in names do
		UI.new("TextLabel", {
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1 / #names, -2),
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(30, 30, 60),
			Text = `• {name}`,
			Parent = registryList,
		}, { UI.textSize(11, 20) })
	end
end

-- Rend son propre personnage invisible (localement) pour ne pas gêner la vue
local function setOwnCharacterHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- La caméra cadre le client en entier dans le haut de l'écran :
-- on voit ses yeux ET le sol autour de ses pieds (ombre), au-dessus du panneau
local function focusCamera(guest: Model?)
	local root = guest and guest:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	cameraFocused = true
	camera.CameraType = Enum.CameraType.Scriptable
	setOwnCharacterHidden(true)
	local eye, target = ReceptionCamera.compute(root.CFrame)
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		CFrame = CFrame.lookAt(eye, target),
	}):Play()
end

local function restoreCamera()
	if cameraFocused then
		cameraFocused = false
		camera.CameraType = Enum.CameraType.Custom
		setOwnCharacterHidden(false)
	end
end

local function setButtonsEnabled(enabled: boolean)
	acceptButton.Active = enabled
	captureButton.Active = enabled
	acceptButton.AutoButtonColor = enabled
	captureButton.AutoButtonColor = enabled
	acceptButton.TextTransparency = if enabled then 0 else 0.5
	captureButton.TextTransparency = if enabled then 0 else 0.5
end

-- Texte des outils : résultat si acheté, sinon rappel qu'il existe
local function describeTools(info: Types.ReceptionInfo): string
	local results = info.ToolResults or {}
	local parts = {}
	if results.UV ~= nil then
		table.insert(parts, if results.UV
			then `<font color="#FF5AF0">UV : traces fluorescentes !</font>`
			else "UV : rien")
	else
		table.insert(parts, `<font color="#888888">🔒 Lampe UV</font>`)
	end
	if results.Thermal ~= nil then
		local cold = results.Thermal < 30
		local text = `{string.format("%.1f", results.Thermal)} °C`
		table.insert(parts, if cold then `<font color="#5AC8FF">Temp. : {text} !</font>` else `Temp. : {text}`)
	else
		table.insert(parts, `<font color="#888888">🔒 Scanner</font>`)
	end
	return table.concat(parts, "   •   ")
end

local function setBottomBarVisible(visible: boolean)
	local hud = player.PlayerGui:FindFirstChild("Hud")
	local bar = hud and hud:FindFirstChild("BottomBar")
	if bar and bar:IsA("GuiObject") then
		bar.Visible = visible
	end
	-- Bandeau d'événement et bouton d'invitation (en haut à droite, sous le panneau)
	for _, name in { "Events", "Invite" } do
		local other = player.PlayerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") then
			other.Enabled = visible
		end
	end
end

function ReceptionController.Open(info: Types.ReceptionInfo)
	current = info
	speechLabel.Text = `« Bonsoir, je suis {info.Name}. J'ai réservé une chambre. »`
	cardName.Text = info.Name
	showRegistry(info.Registry)
	showPhoto(info.PhotoAppearance)
	toolsLabel.Text = describeTools(info)
	setButtonsEnabled(true)
	gui.Enabled = true
	ProximityPromptService.Enabled = false -- l'invite cacherait le client
	setBottomBarVisible(false) -- la barre du bas passerait sous le panneau
	focusCamera(info.Guest)
end

function ReceptionController.Close()
	current = nil
	gui.Enabled = false
	ProximityPromptService.Enabled = true
	setBottomBarVisible(true)
	restoreCamera()
end

local function decide(choice: string)
	local info = current
	if not info or not acceptButton.Active then
		return
	end
	setButtonsEnabled(false)
	Remotes.getEvent("ReceptionDecision"):FireServer(info.Token, choice)
	-- Si le serveur refuse (trop loin...), on peut réessayer
	task.delay(1.5, function()
		if current == info then
			setButtonsEnabled(true)
		end
	end)
end

local function clueSummary(clues: { { Type: string, Strength: string } }): string
	local parts = {}
	for _, clue in clues do
		local texts = CLUE_TEXT[clue.Type]
		table.insert(parts, if texts then texts[clue.Strength] or clue.Type else clue.Type)
	end
	return table.concat(parts, ", ")
end

local resultVersion = 0

local function showResult(token: number, outcome: string, details: { [string]: any })
	if current and current.Token == token then
		ReceptionController.Close()
	end

	local name = details.AnomalyName or "?"
	local rarity = details.Rarity and RarityConfig[details.Rarity :: Types.RarityId]
	local clues = clueSummary(details.Clues or {})
	local text, color
	if outcome == "Captured" then
		text, color = `Anomalie capturée : {name} !`, if rarity then rarity.Color else Color3.new(1, 1, 1)
	elseif outcome == "CapturedSold" then
		text = `Cellules pleines ! {name} revendue {Format.money(details.Amount or 0)}`
		color = Color3.fromRGB(255, 220, 90)
	elseif outcome == "Escaped" then
		local percent = math.floor((1 - EconomyConfig.EscapedIncomeMultiplier) * 100 + 0.5)
		text = `C'était une anomalie : {name} ! Revenus -{percent}% pendant {EconomyConfig.EscapedDuration} s\nIndices : {clues}`
		color = Color3.fromRGB(255, 90, 90)
	elseif outcome == "Served" then
		text, color = `Vrai client, bien vu ! Pourboire +{Format.money(details.Amount or 0)}`, Color3.fromRGB(90, 255, 120)
	elseif outcome == "WrongCapture" then
		text, color = `C'était un vrai client... -{Format.money(details.Amount or 0)}`, Color3.fromRGB(255, 90, 90)
	else
		text, color = "Trop lent, le client est parti.", Color3.fromRGB(220, 220, 220)
	end
	if outcome == "Captured" and clues ~= "" then
		text ..= `\nIndices : {clues}`
	end

	resultVersion += 1
	local version = resultVersion
	resultLabel.Text = text
	resultLabel.TextColor3 = color
	resultLabel.Visible = true
	task.delay(RESULT_DURATION, function()
		if resultVersion == version then
			resultLabel.Visible = false
		end
	end)
end

function ReceptionController.Start(_self: typeof(ReceptionController))
	buildGui()

	acceptButton.Activated:Connect(function()
		decide("Accept")
	end)
	captureButton.Activated:Connect(function()
		decide("Capture")
	end)

	Remotes.getEvent("ReceptionShow").OnClientEvent:Connect(ReceptionController.Open)
	Remotes.getEvent("ReceptionResult").OnClientEvent:Connect(showResult)

	-- Barre de temps
	task.spawn(function()
		while true do
			local info = current
			if info then
				local remaining = info.Deadline - workspace:GetServerTimeNow()
				local ratio = math.clamp(remaining / GuestConfig.Patience, 0, 1)
				timerBar.Size = UDim2.fromScale(ratio, 1)
				timerBar.BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 200, 80)
			end
			task.wait(0.1)
		end
	end)

	-- Si le personnage réapparaît, on ferme tout proprement
	player.CharacterAdded:Connect(function()
		ReceptionController.Close()
	end)
end

return ReceptionController
