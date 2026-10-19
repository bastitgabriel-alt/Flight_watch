--!strict
-- Fenêtre « Renaissance » : prix, progression, bonus gagnés, anomalies débloquées.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local RebirthConfig = require(Config:WaitForChild("RebirthConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Util = script.Parent.Parent:WaitForChild("Util")
local UI = require(Util:WaitForChild("UI"))
local HudBar = require(Util:WaitForChild("HudBar"))

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 80)

local RebirthController = {}

local gui: ScreenGui
local title: TextLabel
local progressFill: Frame
local progressText: TextLabel
local rewards: TextLabel
local confirm: TextButton
local hudButton: TextButton

local function rebirths(): number
	return (player:GetAttribute("Rebirths") :: number?) or 0
end

-- Anomalies débloquées par la prochaine renaissance
local function unlockText(next: number): string
	local names = {}
	for _, def in AnomalyConfig.List do
		if def.RequiredRebirth == next then
			table.insert(names, def.DisplayName)
		end
	end
	return if #names > 0 then `\n🔓 Nouvelle anomalie : {table.concat(names, ", ")}` else ""
end

local function refresh()
	local count = rebirths()
	local money = (player:GetAttribute("Money") :: number?) or 0
	if count >= RebirthConfig.MaxRebirths then
		title.Text = `🔁 Renaissance {count} (max)`
		progressFill.Size = UDim2.fromScale(1, 1)
		progressText.Text = "Maximum atteint !"
		rewards.Text = ""
		confirm.Visible = false
		hudButton.BackgroundColor3 = Color3.fromRGB(90, 70, 40)
		return
	end
	local cost = RebirthConfig.cost(count)
	local ratio = math.clamp(money / cost, 0, 1)
	title.Text = `🔁 Renaissance {count + 1}`
	progressFill.Size = UDim2.fromScale(ratio, 1)
	progressText.Text = `{Format.money(money)} / {Format.money(cost)}`
	local nextMultiplier = RebirthConfig.incomeMultiplier(count + 1)
	local nextLuck = math.floor(RebirthConfig.luck(count + 1) * 100 + 0.5)
	rewards.Text = `Tu gagnes pour toujours :\n💰 Revenus x{nextMultiplier}\n🍀 Chance aux raretés {nextLuck} %`
		.. unlockText(count + 1)
		.. `\n\nTu perds ton argent et tes anomalies.\nTu gardes cellules, outils, sécurité et catalogue.`
	confirm.Visible = true
	confirm.Active = ratio >= 1
	confirm.AutoButtonColor = ratio >= 1
	confirm.BackgroundColor3 = if ratio >= 1 then Color3.fromRGB(220, 150, 30) else Color3.fromRGB(70, 60, 60)
	confirm.Text = if ratio >= 1 then "RENAÎTRE !" else `Encore {Format.money(cost - money)}`
	-- Le bouton du bas brille quand la renaissance est possible
	hudButton.BackgroundColor3 = if ratio >= 1 then Color3.fromRGB(230, 160, 30) else Color3.fromRGB(120, 90, 40)
end

local function buildGui()
	gui = UI.new("ScreenGui", {
		Name = "Rebirth",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.6, 0.72),
		BackgroundColor3 = Color3.fromRGB(25, 18, 30),
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(GOLD, 2),
		UI.padding(12),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, 440), MinSize = Vector2.new(300, 300) }),
	})
	title = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 0, 40),
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Parent = window,
	})
	UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(70, 60, 80),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		Parent = window,
	}, { UI.corner(8) }).Activated:Connect(function()
		gui.Enabled = false
	end)
	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(45, 35, 50),
		Parent = window,
	}, { UI.corner(10) })
	progressFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		Parent = bar,
	}, { UI.corner(10) })
	progressText = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
		Parent = bar,
	}, { UI.padding(4) })
	rewards = UI.new("TextLabel", {
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -160),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(230, 220, 240),
		Parent = window,
	}, { UI.textSize(10, 20) })
	confirm = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.8, 0, 0, 56),
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = window,
	}, { UI.corner(14), UI.stroke(Color3.new(0, 0, 0), 2), UI.padding(6) })
	confirm.Activated:Connect(function()
		if confirm.Active then
			Remotes.getEvent("RebirthRequest"):FireServer()
			gui.Enabled = false
		end
	end)
end

function RebirthController.Start(_self: typeof(RebirthController))
	buildGui()
	hudButton = HudBar.addButton("Renaître", 4, Color3.fromRGB(120, 90, 40))
	hudButton.Text = "🔁 Renaître"
	hudButton.Activated:Connect(function()
		gui.Enabled = not gui.Enabled
		refresh()
	end)
	refresh()
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		refresh()
		-- Petit effet de fête
		local scale = Instance.new("UIScale")
		scale.Scale = 1.4
		scale.Parent = hudButton
		TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
		task.delay(0.7, function()
			scale:Destroy()
		end)
	end)
end

return RebirthController
