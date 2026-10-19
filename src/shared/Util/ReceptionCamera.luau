--!strict
-- Position de la caméra quand on inspecte un client à la réception.
-- Isolé ici pour être testé (tests/run.luau vérifie que rien ne cache le client).

local ReceptionCamera = {}

-- rootCFrame : le HumanoidRootPart du client (il regarde le comptoir).
-- Renvoie la position de la caméra et le point visé.
function ReceptionCamera.compute(rootCFrame: CFrame): (Vector3, Vector3)
	local rootPosition = rootCFrame.Position
	-- Entre le comptoir et le client : rien ne cache ses pieds ni son ombre
	local eye = rootPosition + rootCFrame.LookVector * 5.5 + Vector3.new(0, 1.5, 0)
	-- On vise à droite du client pour qu'il apparaisse dans la moitié gauche
	-- (le panneau d'inspection occupe la droite de l'écran)
	local toGuest = (rootPosition - eye) * Vector3.new(1, 0, 1)
	local right = toGuest.Unit:Cross(Vector3.yAxis)
	local target = rootPosition - Vector3.new(0, 1.2, 0) + right * 3
	return eye, target
end

return ReceptionCamera
