--!strict
-- Signal minimal pour la communication entre services d'un même côté
-- (serveur <-> serveur ou client <-> client).
-- Exemple : local onLoaded = Signal.new()
--           onLoaded:Connect(function(player) ... end)
--           onLoaded:Fire(player)

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { (...any) -> () } = {}

	local signal = {}

	function signal.Connect(_self: Signal, handler: (...any) -> ()): Connection
		table.insert(handlers, handler)
		local connection = {}
		function connection.Disconnect(_conn: Connection)
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
		return connection :: Connection
	end

	function signal.Fire(_self: Signal, ...: any)
		-- Copie : un handler peut se déconnecter pendant l'appel
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return signal :: Signal
end

return Signal
