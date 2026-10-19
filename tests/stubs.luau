--!nocheck
-- Imitation minimale de l'API Roblox pour tester la carte hors de Roblox :
-- Vector3, CFrame, Instance, Enum, Color3, UDim2...

local S = {}

------------------------------------------------------------------ Vector3
local Vector3 = {}
Vector3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return Vector3[key]
end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
Vector3.__tostring = function(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
function Vector3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zero = Vector3.new(0, 0, 0)
S.Vector3 = Vector3

------------------------------------------------------------------ CFrame
-- m = matrice 3x3 (lignes), p = position. Monde = p + m * local
local CFrame = {}
local function mat(m00, m01, m02, m10, m11, m12, m20, m21, m22)
	return { m00, m01, m02, m10, m11, m12, m20, m21, m22 }
end
local function mulMat(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local sum = 0
			for k = 0, 2 do
				sum += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = sum
		end
	end
	return r
end
local function mulVec(m, v)
	return Vector3.new(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end
local function transpose(m)
	return mat(m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9])
end
local function make(p, m)
	return setmetatable({ p = p, m = m }, CFrame)
end
CFrame.__index = function(cf, key)
	local m = cf.m
	if key == "Position" then
		return cf.p
	elseif key == "LookVector" then
		return Vector3.new(-m[3], -m[6], -m[9])
	elseif key == "RightVector" then
		return Vector3.new(m[1], m[4], m[7])
	elseif key == "UpVector" then
		return Vector3.new(m[2], m[5], m[8])
	end
	return CFrame[key]
end
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return make(x, mat(1, 0, 0, 0, 1, 0, 0, 0, 1))
	end
	return make(Vector3.new(x or 0, y or 0, z or 0), mat(1, 0, 0, 0, 1, 0, 0, 0, 1))
end
CFrame.identity = CFrame.new()
function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local mx = mat(1, 0, 0, 0, cx, -sx, 0, sx, cx)
	local my = mat(cy, 0, sy, 0, 1, 0, -sy, 0, cy)
	local mz = mat(cz, -sz, 0, sz, cz, 0, 0, 0, 1)
	return make(Vector3.zero, mulMat(mulMat(mx, my), mz))
end
function CFrame.lookAt(at, target)
	local look = (target - at).Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look)
	-- colonnes : X = right, Y = up, Z = -look
	return make(at, mat(right.X, up.X, -look.X, right.Y, up.Y, -look.Y, right.Z, up.Z, -look.Z))
end
CFrame.__mul = function(a, b)
	if getmetatable(b) == CFrame then
		return make(a.p + mulVec(a.m, b.p), mulMat(a.m, b.m))
	end
	return a.p + mulVec(a.m, b)
end
CFrame.__add = function(a, v)
	return make(a.p + v, a.m)
end
CFrame.__sub = function(a, v)
	return make(a.p - v, a.m)
end
function CFrame.Inverse(cf)
	local t = transpose(cf.m)
	return make(-mulVec(t, cf.p), t)
end
function CFrame.PointToObjectSpace(cf, v)
	return CFrame.Inverse(cf) * v
end
function CFrame.PointToWorldSpace(cf, v)
	return cf * v
end
S.CFrame = CFrame

------------------------------------------------------------------ Instance
local Instance = {}
local InstanceMeta = {}
InstanceMeta.__index = function(inst, key)
	local method = Instance[key]
	if method then
		return method
	end
	local raw = rawget(inst, "_props")[key]
	if raw ~= nil then
		return raw
	end
	if key == "Position" and rawget(inst, "_props").CFrame then
		return rawget(inst, "_props").CFrame.Position
	end
	return Instance.FindFirstChild(inst, key)
end
InstanceMeta.__newindex = function(inst, key, value)
	if key == "Parent" then
		local old = rawget(inst, "_props").Parent
		if old then
			local list = rawget(old, "_children")
			table.remove(list, table.find(list, inst))
		end
		if value then
			table.insert(rawget(value, "_children"), inst)
		end
	end
	rawget(inst, "_props")[key] = value
end
function Instance.new(className)
	local inst = setmetatable({ _props = { ClassName = className, Name = className }, _children = {}, _attributes = {} }, InstanceMeta)
	if className == "Part" or className == "SpawnLocation" or className == "WedgePart" or className == "CornerWedgePart" then
		inst.Size = Vector3.new(4, 1, 2)
		inst.CFrame = CFrame.new()
		inst.Transparency = 0
		inst.CanCollide = true
	end
	return inst
end
function Instance.GetChildren(inst)
	return table.clone(rawget(inst, "_children"))
end
function Instance.GetDescendants(inst)
	local out = {}
	for _, child in rawget(inst, "_children") do
		table.insert(out, child)
		for _, d in Instance.GetDescendants(child) do
			table.insert(out, d)
		end
	end
	return out
end
function Instance.FindFirstChild(inst, name, recursive)
	for _, child in rawget(inst, "_children") do
		if rawget(child, "_props").Name == name then
			return child
		end
	end
	if recursive then
		for _, child in rawget(inst, "_children") do
			local found = Instance.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Instance.WaitForChild(inst, name)
	return assert(Instance.FindFirstChild(inst, name), "WaitForChild : " .. name .. " introuvable")
end
function Instance.IsA(inst, className)
	local c = rawget(inst, "_props").ClassName
	if className == "BasePart" then
		return c == "Part" or c == "SpawnLocation" or c == "WedgePart" or c == "CornerWedgePart"
	end
	return c == className
end
function Instance.SetAttribute(inst, k, v)
	rawget(inst, "_attributes")[k] = v
end
function Instance.GetAttribute(inst, k)
	return rawget(inst, "_attributes")[k]
end
S.Instance = Instance

------------------------------------------------------------------ divers
S.Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return enumName .. "." .. item
			end,
		})
	end,
})
local function udim2(...)
	return { ... }
end
S.UDim2 = { new = udim2, fromScale = udim2, fromOffset = udim2 }
S.UDim = { new = udim2 }

S.workspace = Instance.new("Workspace")
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = S.workspace
-- Terrain : les remplissages ne font rien hors de Roblox
function Instance.FillBlock() end
function Instance.FillBall() end
function Instance.FillCylinder() end

-- Types de valeurs utilisés seulement pour l'affichage (particules...)
local function opaque(...)
	return { ... }
end
S.ColorSequence = { new = opaque }
S.NumberSequence = { new = opaque }
S.NumberSequenceKeypoint = { new = opaque }
S.NumberRange = { new = opaque }
S.Vector2 = { new = opaque }
S.Lighting = Instance.new("Lighting")

------------------------------------------------------------------ géométrie
-- Le point est-il à l'intérieur de la pièce (boîte orientée) ?
function S.pointInPart(point, part, margin)
	local m = margin or 0
	local l = part.CFrame:PointToObjectSpace(point)
	return math.abs(l.X) < part.Size.X / 2 + m and math.abs(l.Y) < part.Size.Y / 2 + m and math.abs(l.Z) < part.Size.Z / 2 + m
end

-- Première pièce qui coupe le segment a -> b (échantillonné), ou nil
function S.segmentHits(a, b, parts)
	for i = 1, 199 do
		local p = a + (b - a) * (i / 200)
		for _, part in parts do
			if S.pointInPart(p, part) then
				return part
			end
		end
	end
	return nil
end

return S
