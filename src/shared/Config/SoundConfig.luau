--!strict
-- Sons du jeu.
--
-- Les sons « rbxasset:// » sont fournis par Roblox. Les autres sont nos propres
-- sons (dossier assets/sounds du projet) : une fois importés sur Roblox, colle
-- leur numéro ici, ex. Id = "rbxassetid://1234567890". Un Id vide = son coupé.
-- Fallback : son de remplacement si l'Id est vide.

export type SoundEntry = {
	Id: string,
	Volume: number,
	Fallback: string?,
	Looped: boolean?,
}

local SoundConfig: { [string]: SoundEntry } = {
	Good = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 },
	Bad = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.5 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.4 },

	-- Nos sons (assets/sounds/<Nom>.mp3)
	Ambience = { Id = "rbxassetid://73312698026917", Volume = 0.3, Looped = true }, -- musique de fond en boucle
	Bell = { Id = "rbxassetid://138973671128228", Volume = 0.5, Fallback = "rbxasset://sounds/electronicpingshort.wav" }, -- un client arrive au comptoir
	Capture = { Id = "rbxassetid://71620312159873", Volume = 0.6, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
	Cash = { Id = "rbxassetid://123666323626030", Volume = 0.5, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
	Scare = { Id = "rbxassetid://134580039054861", Volume = 0.8, Fallback = "rbxasset://sounds/uuhhh.mp3" },
	Alarm = { Id = "rbxassetid://83862393324409", Volume = 0.35 }, -- on te vole une anomalie
	Rebirth = { Id = "rbxassetid://94849013484801", Volume = 0.6, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
	Howl = { Id = "rbxassetid://109095539266532", Volume = 0.6 }, -- Lune de Sang
	PowerDown = { Id = "rbxassetid://106927088380839", Volume = 0.5 }, -- Panne de courant
	Thunder = { Id = "rbxassetid://136496729957078", Volume = 0.6 }, -- éclairs, Ruée fantôme
}

return SoundConfig
