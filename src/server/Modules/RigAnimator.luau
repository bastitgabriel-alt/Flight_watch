--!strict
-- Animations des personnages non-joueurs (clients et anomalies).
-- Ce sont les animations R15 par défaut de Roblox : marche quand le personnage
-- bouge, respiration (« idle ») quand il est immobile.

local WALK_ANIMATION = "rbxassetid://913402848"
local IDLE_ANIMATION = "rbxassetid://507766666"
local MOVING_SPEED = 0.5 -- vitesse au-dessus de laquelle on joue la marche

local RigAnimator = {}

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[RigAnimator] Animation impossible à charger ({id})`)
		return nil
	end
	track.Priority = priority
	track.Looped = true
	return track
end

local function getAnimator(model: Model): (Humanoid?, Animator?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return humanoid, animator
end

-- Respiration seule (anomalie dans sa cellule). À appeler une fois le modèle dans workspace.
function RigAnimator.idle(model: Model)
	local _, animator = getAnimator(model)
	if not animator then
		return
	end
	local track = loadTrack(animator, IDLE_ANIMATION, Enum.AnimationPriority.Idle)
	if track then
		-- Décalage aléatoire : les anomalies ne respirent pas toutes en même temps
		track:Play(0.1, 1, 0.8 + math.random() * 0.4)
	end
end

-- Marche / respiration selon la vitesse (clients). À appeler une fois le modèle dans workspace.
function RigAnimator.walker(model: Model)
	local humanoid, animator = getAnimator(model)
	if not humanoid or not animator then
		return
	end
	local idle = loadTrack(animator, IDLE_ANIMATION, Enum.AnimationPriority.Idle)
	local walk = loadTrack(animator, WALK_ANIMATION, Enum.AnimationPriority.Movement)
	if idle then
		idle:Play()
	end
	local walking = false
	humanoid.Running:Connect(function(speed)
		local moving = speed > MOVING_SPEED
		if moving == walking or not walk then
			return
		end
		walking = moving
		if moving then
			walk:Play(0.2, 1, humanoid.WalkSpeed / 16)
		else
			walk:Stop(0.2)
		end
	end)
end

return RigAnimator
