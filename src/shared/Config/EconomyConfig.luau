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

	-- Gains hors ligne : les anomalies continuent de rapporter (moins vite)
	OfflineRate = 0.3, -- 30 % du revenu normal
	OfflineMaxSeconds = 4 * 3600, -- au maximum 4 h comptées
	OfflineMinSeconds = 120, -- en dessous, rien (simple reconnexion)

	-- Récompense quotidienne : jour 1, 2, 3... de connexion d'affilée (puis on recommence).
	-- Montant = max(montant du jour, revenu par seconde x DailyIncomeSeconds x jour)
	DailyRewards = { 500, 1500, 4000, 10000, 25000, 60000, 150000 },
	DailyIncomeSeconds = 60,

	-- Amis : +X % de revenus par ami présent sur le serveur (plafonné)
	FriendBoostPerFriend = 0.1,
	FriendBoostMax = 0.5,
	-- Invitation : récompense quand un ami rejoint grâce à ton invitation.
	-- Montant = max(InviteRewardMin, revenu par seconde x InviteRewardIncomeSeconds)
	InviteRewardMin = 5000,
	InviteRewardIncomeSeconds = 300,
	InviteWelcomeBonus = 2000, -- offert à l'ami invité
	InviteMaxRewarded = 50, -- nombre d'amis invités récompensés au maximum
}

return EconomyConfig
