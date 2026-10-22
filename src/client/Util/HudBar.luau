--!strict
-- Ajoute un bouton dans la barre du bas (à côté de l'argent).

local Players = game:GetService("Players")

local UI = require(script.Parent:WaitForChild("UI"))

local HudBar = {}

function HudBar.addButton(name: string, layoutOrder: number, color: Color3): TextButton
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud")
	local bar = gui:WaitForChild("BottomBar")
	return UI.new("TextButton", {
		Name = name,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(88, 54),
		BackgroundColor3 = color,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = name,
		Parent = bar,
	}, { UI.corner(14), UI.stroke(Color3.new(0, 0, 0), 2), UI.padding(5), UI.textSize(10, 18) })
end

return HudBar
