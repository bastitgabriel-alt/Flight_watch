--!strict
-- Limiteur de fréquence par joueur, à utiliser sur chaque RemoteEvent.
-- Exemple : local limiter = RateLimiter.new(5, 1) -- 5 appels max par seconde
--           if not limiter:allow(player) then return end

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_maxCalls: number,
		_window: number,
		_calls: { [Player]: { count: number, windowStart: number } },
		_connection: RBXScriptConnection,
	},
	RateLimiter
))

function RateLimiter.new(maxCalls: number, windowSeconds: number): RateLimiter
	local self = setmetatable({
		_maxCalls = maxCalls,
		_window = windowSeconds,
		_calls = {},
		_connection = (nil :: any) :: RBXScriptConnection,
	}, RateLimiter)

	-- Nettoyage quand le joueur quitte
	self._connection = Players.PlayerRemoving:Connect(function(player)
		self._calls[player] = nil
	end)

	return self
end

-- Renvoie true si le joueur a le droit de faire un appel maintenant
function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local entry = self._calls[player]
	if not entry or now - entry.windowStart >= self._window then
		self._calls[player] = { count = 1, windowStart = now }
		return true
	end
	if entry.count >= self._maxCalls then
		return false
	end
	entry.count += 1
	return true
end

function RateLimiter.destroy(self: RateLimiter)
	self._connection:Disconnect()
	table.clear(self._calls)
end

return RateLimiter
