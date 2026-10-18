--!strict
-- Petits outils pour créer l'interface par code.

local UI = {}

-- Crée une instance avec ses propriétés et ses enfants :
-- UI.new("TextLabel", { Text = "Salut", Parent = frame })
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	-- Parent en dernier (plus performant)
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(pixels: number): UIPadding
	local udim = UDim.new(0, pixels)
	return UI.new("UIPadding", { PaddingTop = udim, PaddingBottom = udim, PaddingLeft = udim, PaddingRight = udim })
end

-- Texte qui s'adapte à la place disponible, sans devenir illisible
function UI.textSize(min: number, max: number): UITextSizeConstraint
	return UI.new("UITextSizeConstraint", { MinTextSize = min, MaxTextSize = max })
end

return UI
