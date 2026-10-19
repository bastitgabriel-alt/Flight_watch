--!strict
-- Catalogue des anomalies (Anomalydex) : toutes les anomalies, en silhouette
-- tant qu'elles n'ont pas été capturées, et la prochaine récompense.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local AnomalyConfig = require(Config:WaitForChild("AnomalyConfig"))
local CatalogConfig = require(Config:WaitForChild("CatalogConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Util = script.Parent.Parent:WaitForChild("Util")
local UI = require(Util:WaitForChild("UI"))
local HudBar = require(Util:WaitForChild("HudBar"))

local player = Players.LocalPlayer

local CatalogController = {}

local gui: ScreenGui
local header: TextLabel
local cards: { [string]: { frame: Frame, name: TextLabel, info: TextLabel, stroke: UIStroke } } = {}

-- Anomalies triées par rareté puis par revenu
local function sortedAnomalies()
	local list = table.clone(AnomalyConfig.List)
	table.sort(list, function(a, b)
		local ra, rb = RarityConfig[a.Rarity].Order, RarityConfig[b.Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return a.Income < b.Income
	end)
	return list
end

local function buildGui()
	gui = UI.new("ScreenGui", {
		Name = "Catalog",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.78),
		BackgroundColor3 = Color3.fromRGB(25, 18, 30),
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(Color3.fromRGB(170, 80, 255), 2),
		UI.padding(10),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(720, 520), MinSize = Vector2.new(320, 260) }),
	})
	header = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 0, 40),
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(220, 180, 255),
		Text = "📖 Catalogue",
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

	local grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -8, 0, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for index, def in sortedAnomalies() do
		local stroke = UI.stroke(Color3.fromRGB(60, 60, 60), 2)
		local frame = UI.new("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = Color3.fromRGB(40, 32, 48),
			Parent = grid,
		}, { UI.corner(10), UI.padding(6), stroke })
		local name = UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.4),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = frame,
		}, { UI.textSize(8, 18) })
		local info = UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.42),
			Size = UDim2.fromScale(1, 0.58),
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(200, 190, 210),
			Parent = frame,
		}, { UI.textSize(7, 14) })
		cards[def.Id] = { frame = frame, name = name, info = info, stroke = stroke }
	end
end

local function refresh()
	local count = 0
	for _, def in AnomalyConfig.List do
		local card = cards[def.Id]
		local rarity = RarityConfig[def.Rarity]
		if player:GetAttribute(`Disc_{def.Id}`) then
			count += 1
			card.name.Text = def.DisplayName
			card.name.TextColor3 = rarity.Color
			card.info.Text = `{rarity.DisplayName} • {Format.money(def.Income)}/s\n{def.Description}`
			card.stroke.Color = rarity.Color
			card.frame.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
		else
			-- Silhouette : on ne montre que la rareté
			card.name.Text = "???"
			card.name.TextColor3 = Color3.fromRGB(120, 120, 120)
			card.info.Text = `{rarity.DisplayName}\nPas encore capturée`
			card.stroke.Color = Color3.fromRGB(60, 60, 60)
			card.frame.BackgroundColor3 = Color3.fromRGB(15, 12, 18)
		end
	end
	local nextReward = nil
	for _, reward in CatalogConfig.Rewards do
		if count < reward.Count then
			nextReward = reward
			break
		end
	end
	header.Text = `📖 Catalogue {count}/{#AnomalyConfig.List}`
		.. if nextReward then `  •  à {nextReward.Count} : +{Format.money(nextReward.Money)}` else "  •  complet !"
end

function CatalogController.Start(_self: typeof(CatalogController))
	buildGui()
	refresh()
	local button = HudBar.addButton("Catalogue", 0, Color3.fromRGB(110, 60, 160))
	button.Text = "📖 Catalogue"
	button.Activated:Connect(function()
		gui.Enabled = not gui.Enabled
		refresh()
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Disc_" then
			refresh()
		end
	end)
end

return CatalogController
