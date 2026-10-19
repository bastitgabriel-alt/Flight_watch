--!strict
-- Charge et sauvegarde les données des joueurs avec ProfileStore
-- (verrouillage de session : pas de perte ni de duplication entre serveurs).
-- Dans Studio sans accès aux API, ProfileStore utilise une sauvegarde factice
-- (les données ne sont pas conservées entre deux tests).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProfileStore = require(Server:WaitForChild("Vendor"):WaitForChild("ProfileStore"))
local DataSchema = require(Server:WaitForChild("Modules"):WaitForChild("DataSchema"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))

local PlayerDataService = {}

-- Déclenché quand les données d'un joueur sont prêtes : (player, data)
PlayerDataService.DataLoaded = Signal.new()

local store = ProfileStore.New(GameConfig.DataStoreName, DataSchema.TEMPLATE)
local profiles: { [Player]: any } = {}

local function profileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(profileKey(player), {
		-- Arrête d'essayer si le joueur part pendant le chargement
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Un autre serveur garde la session ou Roblox est en panne
		if player.Parent == Players then
			player:Kick("Impossible de charger tes données. Réessaie dans un instant.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- conformité RGPD
	profile:Reconcile() -- ajoute les champs manquants depuis le modèle
	DataSchema.migrate(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Ta session a été ouverte ailleurs. Reconnecte-toi.")
		end
	end)

	if player.Parent ~= Players then
		-- Parti pendant le chargement
		profile:EndSession()
		return
	end

	profiles[player] = profile
	local data = profile.Data
	data.LastLogin = os.time()

	player:SetAttribute("Money", data.Money)
	PlayerDataService.DataLoaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

-- Données du joueur, ou nil si pas (encore) chargées.
-- Les modifications sont sauvegardées automatiquement.
function PlayerDataService.GetData(player: Player): any?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function PlayerDataService.GetMoney(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then data.Money else 0
end

local function setMoney(player: Player, data: any, amount: number)
	data.Money = math.max(0, amount)
	player:SetAttribute("Money", data.Money)
end

-- Ajoute (ou retire si négatif) de l'argent. Ne descend jamais sous 0.
function PlayerDataService.AddMoney(player: Player, amount: number)
	local data = PlayerDataService.GetData(player)
	if not data or amount ~= amount then -- amount ~= amount : NaN
		return
	end
	setMoney(player, data, data.Money + amount)
end

-- Dépense si le joueur a assez. Renvoie true si l'achat est passé.
function PlayerDataService.TrySpend(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data or amount < 0 or data.Money < amount then
		return false
	end
	setMoney(player, data, data.Money - amount)
	return true
end

-- Sauvegarde tout de suite et attend que check(dernières données sauvegardées)
-- soit vrai. Sert aux achats Robux : on ne confirme qu'une fois l'achat sauvegardé.
function PlayerDataService.SaveAndWait(player: Player, check: (any) -> boolean, timeout: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if profile.LastSavedData and check(profile.LastSavedData) then
		return true
	end
	local saved = false
	local connection = profile.OnAfterSave:Connect(function(lastSavedData)
		if check(lastSavedData) then
			saved = true
		end
	end)
	profile:Save()
	local elapsed = 0
	while not saved and elapsed < timeout and profile:IsActive() do
		elapsed += task.wait(0.2)
	end
	connection:Disconnect()
	return saved
end

-- Remet les données à zéro (commande debug) puis expulse le joueur
function PlayerDataService.ResetData(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for key in profile.Data do
		profile.Data[key] = nil
	end
	for key, value in DataSchema.TEMPLATE do
		profile.Data[key] = if type(value) == "table" then table.clone(value) else value
	end
	player:Kick("Données réinitialisées. Relance le jeu.")
end

function PlayerDataService.Init(_self: typeof(PlayerDataService))
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlayerDataService.Start(_self: typeof(PlayerDataService))
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Joueurs déjà présents (fréquent dans Studio)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
