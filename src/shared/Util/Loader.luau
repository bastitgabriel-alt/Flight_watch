--!strict
-- Charge les modules (services serveur ou contrôleurs client) d'un dossier.
-- Chaque module peut définir :
--   Init(self)  : appelé en premier, dans l'ordre, pour se préparer
--   Start(self) : appelé ensuite, chacun dans son propre thread
-- Un module qui plante n'empêche pas les autres de se charger.

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local Loader = {}

function Loader.loadModules(folder: Instance): { [string]: Module }
	local loaded: { [string]: Module } = {}

	-- 1) require de chaque ModuleScript
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok and type(result) == "table" then
				loaded[child.Name] = result :: Module
			else
				warn(`[Loader] Impossible de charger {child.Name} : {result}`)
			end
		end
	end

	-- 2) Init de chaque module (synchrone)
	for name, module in loaded do
		if module.Init then
			local ok, err = pcall(module.Init, module)
			if not ok then
				warn(`[Loader] Erreur dans {name}.Init : {err}`)
			end
		end
	end

	-- 3) Start de chaque module (chacun dans son thread)
	for name, module in loaded do
		local start = module.Start
		if start then
			task.spawn(function()
				local ok, err = pcall(start, module)
				if not ok then
					warn(`[Loader] Erreur dans {name}.Start : {err}`)
				end
			end)
		end
	end

	return loaded
end

return Loader
