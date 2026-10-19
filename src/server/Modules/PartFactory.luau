--!strict
-- Création de pièces ancrées pour la carte.

local PartFactory = {}

-- Pièce ancrée avec ses propriétés : PartFactory.part({ Name = "Mur", Size = ..., Parent = ... })
function PartFactory.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Repère invisible (position où quelque chose doit apparaître)
function PartFactory.marker(name: string, cframe: CFrame, parent: Instance): Part
	return PartFactory.part({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		CFrame = cframe,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
end

-- Décoration : ne gêne ni les joueurs ni les clics
function PartFactory.decor(props: { [string]: any }): Part
	local part = PartFactory.part(props)
	if props.CanCollide == nil then
		part.CanCollide = false
	end
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Lumière ponctuelle accrochée à une pièce
function PartFactory.light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

return PartFactory
