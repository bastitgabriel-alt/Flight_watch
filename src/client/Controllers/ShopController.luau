--!strict
-- Boutique : bouton dans la barre du bas, fenêtre avec la liste des achats.
-- Les prix affichés viennent de ShopConfig ; le serveur revérifie tout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local ShopConfig = require(Config:WaitForChild("ShopConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local MarketplaceService = game:GetService("MarketplaceService")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Util = script.Parent.Parent:WaitForChild("Util")
local UI = require(Util:WaitForChild("UI"))
local HudBar = require(Util:WaitForChild("HudBar"))

local player = Players.LocalPlayer

local ShopController = {}

type Row = {
	category: string,
	itemId: string,
	order: number,
	-- Renvoie : titre, description, prix (nil = rien à acheter), texte si pas de prix
	describe: () -> (string, string, number?, string),
	-- Achat en Robux (gamepass ou produit) au lieu de l'argent du jeu
	robux: { kind: "Pass" | "Product", id: number, passName: string? }?,
}

local rows: { Row } = {}
local gui: ScreenGui
local list: ScrollingFrame

local function attribute(name: string): any
	return player:GetAttribute(name)
end

local function buildRows()
	table.insert(rows, {
		category = "Cell",
		itemId = "Cell",
		order = 1,
		describe = function()
			local unlocked = (attribute("CellsUnlocked") :: number?) or GameConfig.BaseCells
			local purchased = unlocked - GameConfig.BaseCells
			local price = ShopConfig.nextCellPrice(purchased)
			return `Cellule supplémentaire ({purchased}/{ShopConfig.Cells.MaxPurchasable})`,
				"Une place de plus pour enfermer une anomalie.",
				price,
				"MAX"
		end,
	})
	for toolId, tool in ShopConfig.Tools do
		table.insert(rows, {
			category = "Tool",
			itemId = toolId,
			order = 10 + tool.Order,
			describe = function()
				local owned = attribute(`Tool_{toolId}`) == true
				return tool.DisplayName, tool.Description, if owned then nil else tool.Price, "Acheté"
			end,
		})
	end
	for upgradeId, upgrade in ShopConfig.Security do
		table.insert(rows, {
			category = "Security",
			itemId = upgradeId,
			order = 20 + upgrade.Order,
			describe = function()
				local level = (attribute(`Sec_{upgradeId}`) :: number?) or 0
				local price = ShopConfig.nextSecurityPrice(upgradeId, level)
				return `{upgrade.DisplayName} (niv. {level}/{#upgrade.Prices})`, upgrade.Description, price, "MAX"
			end,
		})
	end
	-- Achats Robux (cachés tant que leur Id n'est pas renseigné dans MonetizationConfig)
	for passName, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 then
			table.insert(rows, {
				category = "Robux",
				itemId = passName,
				order = 30,
				describe = function()
					return `⭐ {pass.DisplayName}`, pass.Description, nil, "Acheté"
				end,
				robux = { kind = "Pass", id = pass.Id, passName = passName },
			})
		end
	end
	for _, product in MonetizationConfig.Products do
		if product.Id ~= 0 then
			table.insert(rows, {
				category = "Robux",
				itemId = tostring(product.Id),
				order = 40,
				describe = function()
					return `⭐ {product.DisplayName}`, product.Description, nil, ""
				end,
				robux = { kind = "Product", id = product.Id },
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.order < b.order
	end)
end

type RowWidgets = { row: Row, title: TextLabel, button: TextButton }
local widgets: { RowWidgets } = {}

-- Crée les lignes une seule fois (les recréer à chaque seconde ferait rater des clics)
local function createRowWidgets()
	for index, row in rows do
		local frame = UI.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 70),
			BackgroundColor3 = Color3.fromRGB(45, 35, 55),
			Parent = list,
		}, { UI.corner(10), UI.padding(6) })
		local _, description = row.describe()
		local title = UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.68, 0.45),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = frame,
		}, { UI.textSize(10, 20) })
		UI.new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.48),
			Size = UDim2.fromScale(0.68, 0.52),
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(200, 190, 210),
			Text = description,
			Parent = frame,
		}, { UI.textSize(8, 16) })
		local button = UI.new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromScale(0.3, 0.9),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = frame,
		}, { UI.corner(10), UI.padding(4), UI.textSize(10, 22) })
		button.Activated:Connect(function()
			local robux = row.robux
			if robux then
				if robux.kind == "Pass" then
					if not attribute(`Pass_{robux.passName}`) then
						MarketplaceService:PromptGamePassPurchase(player, robux.id)
					end
				else
					MarketplaceService:PromptProductPurchase(player, robux.id)
				end
				return
			end
			local _, _, price = row.describe()
			if price then
				Remotes.getEvent("ShopBuy"):FireServer(row.category, row.itemId)
			end
		end)
		table.insert(widgets, { row = row, title = title, button = button })
	end
end

-- Met à jour textes, prix et couleurs (argent, achats)
local function refresh()
	if not gui or not gui.Enabled then
		return
	end
	local money = (attribute("Money") :: number?) or 0
	for _, w in widgets do
		local title, _, price, doneText = w.row.describe()
		w.title.Text = title
		local robux = w.row.robux
		if robux then
			local owned = robux.kind == "Pass" and attribute(`Pass_{robux.passName}`) == true
			w.button.Text = if owned then doneText else "Robux"
			w.button.AutoButtonColor = not owned
			w.button.BackgroundColor3 = if owned then Color3.fromRGB(70, 70, 80) else Color3.fromRGB(0, 150, 90)
			continue
		end
		w.button.Text = if price then Format.money(price) else doneText
		w.button.AutoButtonColor = price ~= nil
		w.button.BackgroundColor3 = if price == nil
			then Color3.fromRGB(70, 70, 80)
			elseif money >= price then Color3.fromRGB(40, 160, 80)
			else Color3.fromRGB(120, 60, 60)
	end
end

local function buildGui()
	gui = UI.new("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.7, 0.75),
		BackgroundColor3 = Color3.fromRGB(25, 18, 30),
		Parent = gui,
	}, {
		UI.corner(18),
		UI.stroke(Color3.fromRGB(255, 200, 80), 2),
		UI.padding(10),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 480), MinSize = Vector2.new(300, 240) }),
	})
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 220, 90),
		Text = "🛒 Boutique",
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
	list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		UI.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
	})
end

function ShopController.Start(_self: typeof(ShopController))
	buildRows()
	buildGui()
	createRowWidgets()

	local button = HudBar.addButton("Boutique", 1, Color3.fromRGB(200, 130, 30))
	button.Text = "🛒 Boutique"
	button.Activated:Connect(function()
		gui.Enabled = not gui.Enabled
		refresh()
	end)

	-- Mise à jour quand l'argent ou les possessions changent
	player.AttributeChanged:Connect(function(name)
		local prefix4, prefix5 = string.sub(name, 1, 4), string.sub(name, 1, 5)
		if name == "Money" or name == "CellsUnlocked" or prefix5 == "Tool_" or prefix4 == "Sec_" or prefix5 == "Pass_" then
			refresh()
		end
	end)
end

return ShopController
