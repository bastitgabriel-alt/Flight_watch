--!strict
-- Chiffres d'économie. Modifie-les librement pour équilibrer le jeu.

local EconomyConfig = {
	StartingMoney = 0,

	-- Revenu passif : argent versé toutes les X secondes
	IncomeTickSeconds = 1,

	-- Pourboire d'un vrai client à qui on donne la clé :
	-- max(TipBase, revenu par seconde x TipIncomeSeconds)
	TipBase = 5,
	TipIncomeSeconds = 2,

	-- Capturer un vrai client par erreur :
	-- perte = WrongCaptureBase + revenu par seconde x WrongCaptureIncomeSeconds
	WrongCaptureBase = 10,
	WrongCaptureIncomeSeconds = 10,

	-- Laisser entrer une anomalie : revenus multipliés par X pendant Y secondes
	EscapedIncomeMultiplier = 0.5,
	EscapedDuration = 30,

	-- Capture quand toutes les cellules sont pleines : l'anomalie est revendue
	-- immédiatement pour X secondes de son revenu
	FullCellsSellSeconds = 60,
}

return EconomyConfig
