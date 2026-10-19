--!strict
-- Interface permanente : argent (compteur animé), revenu par seconde,
-- pénalité en cours, et messages (notifications) en haut de l'écran.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local MAX_TOASTS = 4
local TOAST_DURATION = 3
local KIND_COLORS: { [string]: Color3 } = {
	Info = Color3.fromRGB(255, 255, 255),
	Good = Color3.fromRGB(90, 255, 120),
	Bad = Color3.fromRGB(255, 90, 90),
}

local HudController = {}

local moneyLabel: TextLabel
local incomeLabel: TextLabel
local moneyScale: UIScale
local toastList: Frame
local displayedMoney = 0

local function buildGui()
	local gui = UI.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Barre du bas : [Boutique] [Argent] [Verrou]. Libre sur PC comme sur téléphone
	-- (chat en haut à gauche, joystick en bas à gauche, saut en bas à droite).
	-- Les boutons Boutique et Verrou sont ajoutés par leurs contrôleurs.
	local bar = UI.new("Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	local panel = UI.new("Frame", {
		Name = "MoneyPanel",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(210, 70),
		BackgroundColor3 = Color3.fromRGB(20, 14, 26),
		BackgroundTransparency = 0.15,
		Parent = bar,
	}, {
		UI.corner(16),
		UI.stroke(Color3.fromRGB(255, 200, 80), 2),
	})
	moneyScale = UI.new("UIScale", { Parent = panel })

	moneyLabel = UI.new("TextLabel", {
		Name = "Money",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.62),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		Text = "$0",
		Parent = panel,
	}, { UI.textSize(18, 40) })

	incomeLabel = UI.new("TextLabel", {
		Name = "Income",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.36),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(200, 255, 200),
		Text = "+$0/s",
		Parent = panel,
	}, { UI.textSize(12, 20) })

	-- Pile de notifications sous le panneau
	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }),
	})
end

local toastCount = 0

local function showToast(text: string, kind: any)
	local color = if typeof(kind) == "Color3" then kind else (KIND_COLORS[kind] or KIND_COLORS.Info)

	-- On retire la plus ancienne s'il y en a trop
	local existing = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(existing, child)
		end
	end
	if #existing >= MAX_TOASTS then
		table.sort(existing, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		existing[1]:Destroy()
	end

	toastCount += 1
	local label = UI.new("TextLabel", {
		LayoutOrder = toastCount,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(15, 10, 20),
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = color,
		Text = text,
		Parent = toastList,
	}, { UI.corner(10), UI.padding(6), UI.textSize(12, 22) })

	task.delay(TOAST_DURATION, function()
		if label.Parent then
			local tween = TweenService:Create(label, TweenInfo.new(0.4), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
			label:Destroy()
		end
	end)
end

local function updateIncomeText()
	local income = (player:GetAttribute("Income") :: number?) or 0
	local text = `+{Format.money(income)}/s`
	local debuffEnds = player:GetAttribute("DebuffEndsAt") :: number?
	local remaining = if debuffEnds then math.ceil(debuffEnds - workspace:GetServerTimeNow()) else 0
	if remaining > 0 then
		local multiplier = (player:GetAttribute("DebuffMultiplier") :: number?) or 1
		local percent = math.floor((1 - multiplier) * 100 + 0.5)
		text ..= `  (-{percent}% • {remaining}s)`
		incomeLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		incomeLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
	end
	incomeLabel.Text = text
end

function HudController.Start(_self: typeof(HudController))
	buildGui()

	displayedMoney = (player:GetAttribute("Money") :: number?) or 0
	local lastTarget = displayedMoney

	-- Le compteur « rattrape » la vraie valeur en douceur
	RunService.RenderStepped:Connect(function(dt)
		local target = (player:GetAttribute("Money") :: number?) or 0
		local income = (player:GetAttribute("Income") :: number?) or 0
		if target > lastTarget + income * 1.5 + 0.5 then
			-- Petit rebond quand on gagne un gros coup (pas à chaque seconde de revenu)
			moneyScale.Scale = 1.08
			TweenService:Create(moneyScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastTarget = target
		local diff = target - displayedMoney
		if math.abs(diff) < 1 then
			displayedMoney = target
		else
			displayedMoney += diff * math.min(1, dt * 8)
		end
		moneyLabel.Text = Format.money(displayedMoney)
	end)

	player:GetAttributeChangedSignal("Income"):Connect(updateIncomeText)
	task.spawn(function()
		while true do
			updateIncomeText()
			task.wait(0.5)
		end
	end)

	Remotes.getEvent("Notify").OnClientEvent:Connect(showToast)
end

return HudController
