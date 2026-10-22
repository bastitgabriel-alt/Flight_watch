--!strict
-- Tutoriel des nouveaux joueurs, en 3 étapes avec flèche et texte court :
--   1. recevoir le client au comptoir
--   2. décider (clé ou capture)
--   3. ouvrir la boutique

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local STEPS = {
	"Un client arrive au comptoir ! Approche-toi et appuie sur « Recevoir ».",
	"Compare le registre, la photo, son ombre et ses yeux. Puis donne la clé… ou capture-le !",
	"Tes anomalies rapportent de l'argent chaque seconde. Ouvre la Boutique pour t'agrandir !",
}

local TutorialController = {}

local function waitForTutorialState(): boolean
	while player:GetAttribute("TutorialDone") == nil do
		player:GetAttributeChangedSignal("TutorialDone"):Wait()
	end
	return player:GetAttribute("TutorialDone") == true
end

-- Flèche qui rebondit au-dessus d'un objet du monde
local function makeArrow(adornee: BasePart): BillboardGui
	local billboard = UI.new("BillboardGui", {
		Name = "TutorialArrow",
		Adornee = adornee,
		Size = UDim2.fromOffset(80, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 8, 0),
		AlwaysOnTop = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local label = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 60),
		TextStrokeTransparency = 0,
		Text = "⬇",
		Parent = billboard,
	})
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromScale(0, 0.3) }
	):Play()
	return billboard
end

local function getGuestSpot(): BasePart?
	local index = player:GetAttribute("HotelIndex")
	local map = workspace:WaitForChild("Map")
	local hotel = index and map:WaitForChild("Hotels"):FindFirstChild(`Hotel{index}`)
	local spot = hotel and hotel:FindFirstChild("GuestSpot")
	return if spot and spot:IsA("BasePart") then spot else nil
end

function TutorialController.Start(_self: typeof(TutorialController))
	if waitForTutorialState() then
		return
	end

	local gui = UI.new("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local banner = UI.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -95),
		Size = UDim2.new(0.5, 0, 0, 70),
		BackgroundColor3 = Color3.fromRGB(255, 200, 60),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(30, 20, 10),
		Parent = gui,
	}, {
		UI.corner(12),
		UI.padding(8),
		UI.textSize(12, 22),
		UI.new("UISizeConstraint", { MinSize = Vector2.new(260, 60), MaxSize = Vector2.new(560, 90) }),
	})

	local function show(step: number)
		banner.Text = `({step}/3) {STEPS[step]}`
	end

	-- Placement : au-dessus de la barre du bas, masqué pendant la réception
	local receptionGui = player:WaitForChild("PlayerGui"):WaitForChild("Reception") :: ScreenGui
	local function place()
		-- Pendant la réception, le bandeau cacherait le client : on le masque
		banner.Visible = not receptionGui.Enabled
		banner.Position = UDim2.new(0.5, 0, 1, -80)
	end
	receptionGui:GetPropertyChangedSignal("Enabled"):Connect(place)
	place()

	-- Étape 1 : recevoir
	while not player:GetAttribute("HotelIndex") do
		player:GetAttributeChangedSignal("HotelIndex"):Wait()
	end
	show(1)
	local spot = getGuestSpot()
	local arrow = if spot then makeArrow(spot) else nil
	Remotes.getEvent("ReceptionShow").OnClientEvent:Wait()
	if arrow then
		arrow:Destroy()
	end
	Remotes.getEvent("TutorialStep"):FireServer(1)

	-- Étape 2 : décider
	show(2)
	Remotes.getEvent("ReceptionResult").OnClientEvent:Wait()
	Remotes.getEvent("TutorialStep"):FireServer(2)

	-- Étape 3 : ouvrir la boutique (on fait clignoter son bouton)
	task.wait(2.5) -- laisse le temps de lire le résultat
	show(3)
	local playerGui = player:WaitForChild("PlayerGui")
	local shopGui = playerGui:WaitForChild("Shop") :: ScreenGui
	local shopButton = playerGui:WaitForChild("Hud"):WaitForChild("BottomBar"):WaitForChild("Boutique") :: TextButton
	local stroke = shopButton:FindFirstChildOfClass("UIStroke")
	local pulse = if stroke
		then TweenService:Create(
			stroke,
			TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Color = Color3.fromRGB(255, 230, 80), Thickness = 5 }
		)
		else nil
	if pulse then
		pulse:Play()
	end
	while not shopGui.Enabled do
		shopGui:GetPropertyChangedSignal("Enabled"):Wait()
	end
	if pulse and stroke then
		pulse:Cancel()
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
	end
	Remotes.getEvent("TutorialStep"):FireServer(3)

	banner.Text = "Bravo, tu es prêt ! Attention aux voleurs : pense à verrouiller ta porte. 🔒"
	task.wait(5)
	gui:Destroy()
end

return TutorialController
