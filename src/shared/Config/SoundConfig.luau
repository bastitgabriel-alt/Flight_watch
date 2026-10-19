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
	Ambience = { Id = "", Volume = 0.3, Looped = true }, -- musique de fond en boucle
	Bell = { Id = "", Volume = 0.5 }, -- un client arrive au comptoir
	Capture = { Id = "", Volume = 0.6, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
	Cash = { Id = "", Volume = 0.5, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
	Scare = { Id = "", Volume = 0.8, Fallback = "rbxasset://sounds/uuhhh.mp3" },
	Alarm = { Id = "", Volume = 0.35 }, -- on te vole une anomalie
	Rebirth = { Id = "", Volume = 0.6 },
	Howl = { Id = "", Volume = 0.6 }, -- Lune de Sang
	PowerDown = { Id = "", Volume = 0.5 }, -- Panne de courant
	Thunder = { Id = "", Volume = 0.6 }, -- éclairs, Ruée fantôme
}

return SoundConfig
