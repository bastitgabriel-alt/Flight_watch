--!strict
-- Fenêtre « Bon retour » : gains hors ligne + récompense quotidienne (7 jours).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local UI = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("UI"))

local player = Players.LocalPlayer

local WelcomeController = {}

local function duration(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	return if hours > 0 then `{hours} h {string.format("%02d", minutes)}` else `{minutes} min`
end

local function show(offline: number, seconds: number, day: number, daily: number)
	local gui = UI.new("ScreenGui", {
		Name = "Welcome",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.5, 0.62),
		BackgroundColor3 = Color3.fromRGB(25, 18, 30),
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(Color3.fromRGB(170, 80, 255), 3),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(420, 340), MinSize = Vector2.new(280, 320) }),
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = window })
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local function line(order: number, text: string, color: Color3, height: number, font: Enum.Font?)
		UI.new("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			Font = font or Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = color,
			Text = text,
			Parent = window,
		})
	end

	line(1, "Bon retour à l'hôtel !", Color3.fromRGB(220, 180, 255), 42, Enum.Font.Creepster)
	if offline > 0 then
		line(2, `Pendant ton absence ({duration(seconds)}), tes anomalies ont rapporté`, Color3.new(1, 1, 1), 34)
		line(3, `+{Format.money(offline)}`, Color3.fromRGB(255, 220, 90), 34, Enum.Font.FredokaOne)
	end
	if daily > 0 then
		line(4, `🔥 Récompense du jour {day}/{#EconomyConfig.DailyRewards} : +{Format.money(daily)}`, Color3.fromRGB(255, 160, 80), 28)
		-- Les 7 jours de la série
		local row = UI.new("Frame", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Parent = window,
		}, {
			UI.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
			}),
		})
		for i = 1, #EconomyConfig.DailyRewards do
			UI.new("TextLabel", {
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = if i <= day then Color3.fromRGB(230, 130, 40) else Color3.fromRGB(60, 50, 65),
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = tostring(i),
				Parent = row,
			}, { UI.corner(14) })
		end
		line(6, "Reviens demain pour une plus grosse récompense !", Color3.fromRGB(190, 180, 200), 20)
	end
	local ok = UI.new("TextButton", {
		LayoutOrder = 7,
		Size = UDim2.new(0.6, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(60, 170, 80),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Récupérer",
		Parent = window,
	}, { UI.corner(12), UI.stroke(Color3.new(0, 0, 0), 2), UI.padding(6) })
	ok.Activated:Connect(function()
		gui:Destroy()
	end)
end

function WelcomeController.Start(_self: typeof(WelcomeController))
	Remotes.getEvent("WelcomeBack").OnClientEvent:Connect(show)
end

return WelcomeController
