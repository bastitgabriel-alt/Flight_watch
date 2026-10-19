--!strict
-- Animations des clients et des anomalies, calculées sur l'écran du joueur.
-- On fait bouger les articulations (Motor6D) directement : pas besoin de
-- fichiers d'animation Roblox, donc ça marche partout et ne coûte rien au réseau.
--
-- Le serveur choisit le style avec l'attribut « Motion » du modèle :
--   Guest   client normal (marche, respire, regarde autour de lui)
--   Creepy  tête qui penche lentement, petits sursauts nerveux
--   Float   bras tendus, jambes qui pendent (fantômes)
--   Zombie  bras tendus droit devant, tête tombante (somnambule)
--   Twitch  secousses violentes et fréquentes
--   Regal   torse bombé, regard hautain, bras levé
--   Feral   courbé, respiration haletante, bras qui pendent
--   Doll    mouvements saccadés de poupée

local RunService = game:GetService("RunService")

local MAX_DISTANCE = 140 -- au-delà, on n'anime pas (économie)
local WALK_SPEED_MIN = 0.6

local JOINTS = {
	"Root", "Waist", "Neck",
	"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
	"LeftHip", "RightHip", "LeftKnee", "RightKnee",
}

type Pose = { [string]: Vector3 } -- articulation -> (avant/arrière, rotation, inclinaison) en radians
type Rig = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	style: string,
	seed: number,
	phase: number,
	walk: number, -- 0 = immobile, 1 = marche (transition douce)
	twitchUntil: number,
	nextTwitch: number,
	twitch: Pose,
}

local RigMotionController = {}

local rigs: { [Model]: Rig } = {}

local function add(pose: Pose, joint: string, pitch: number, yaw: number, roll: number)
	local current = pose[joint] or Vector3.zero
	pose[joint] = current + Vector3.new(pitch, yaw, roll)
end

-- Pose immobile selon le style. t = temps, s = graine propre au modèle
local STYLES: { [string]: (pose: Pose, t: number, s: number) -> () } = {}

STYLES.Guest = function(pose, t, s)
	local breath = math.sin(t * 1.8 + s)
	add(pose, "Waist", breath * 0.02, 0, 0)
	add(pose, "Neck", -breath * 0.02, math.sin(t * 0.35 + s) * 0.35, 0)
	add(pose, "LeftShoulder", 0, 0, -0.06 - breath * 0.02)
	add(pose, "RightShoulder", 0, 0, 0.06 + breath * 0.02)
	add(pose, "LeftElbow", 0.12, 0, 0)
	add(pose, "RightElbow", 0.12, 0, 0)
end

STYLES.Creepy = function(pose, t, s)
	local breath = math.sin(t * 1.2 + s)
	add(pose, "Waist", -0.12 + breath * 0.03, math.sin(t * 0.3 + s) * 0.08, 0)
	add(pose, "Neck", -0.15, math.sin(t * 0.25 + s) * 0.25, math.sin(t * 0.55 + s) * 0.4)
	add(pose, "LeftShoulder", math.sin(t * 0.8 + s) * 0.08, 0, -0.05)
	add(pose, "RightShoulder", math.sin(t * 0.8 + s + 1.5) * 0.08, 0, 0.05)
end

STYLES.Float = function(pose, t, s)
	local sway = math.sin(t * 1.1 + s)
	add(pose, "Waist", 0.05, sway * 0.06, 0)
	add(pose, "Neck", -0.1, 0, sway * 0.15)
	add(pose, "LeftShoulder", 0.7 + sway * 0.15, 0, -0.35)
	add(pose, "RightShoulder", 0.7 - sway * 0.15, 0, 0.35)
	add(pose, "LeftElbow", 0.3, 0, 0)
	add(pose, "RightElbow", 0.3, 0, 0)
	add(pose, "LeftHip", -0.25 + sway * 0.1, 0, 0)
	add(pose, "RightHip", -0.15 - sway * 0.1, 0, 0)
	add(pose, "LeftKnee", -0.4, 0, 0)
	add(pose, "RightKnee", -0.3, 0, 0)
end

STYLES.Zombie = function(pose, t, s)
	local sway = math.sin(t * 0.9 + s)
	add(pose, "Waist", -0.05, sway * 0.1, sway * 0.04)
	add(pose, "Neck", -0.45, 0, sway * 0.25)
	add(pose, "LeftShoulder", 1.45 + sway * 0.05, 0, 0)
	add(pose, "RightShoulder", 1.45 - sway * 0.05, 0, 0)
	add(pose, "LeftElbow", 0.05, 0, 0)
	add(pose, "RightElbow", 0.05, 0, 0)
end

STYLES.Twitch = function(pose, t, s)
	STYLES.Creepy(pose, t, s)
	add(pose, "Neck", 0, 0, math.sin(t * 9 + s) * 0.06)
end

STYLES.Regal = function(pose, t, s)
	local breath = math.sin(t * 1.4 + s)
	add(pose, "Waist", 0.1 + breath * 0.02, math.sin(t * 0.25 + s) * 0.15, 0)
	add(pose, "Neck", 0.15, math.sin(t * 0.2 + s) * 0.5, 0)
	-- Bras droit levé, comme un chef d'orchestre
	add(pose, "RightShoulder", 1.9 + math.sin(t * 2 + s) * 0.35, 0, 0.3)
	add(pose, "RightElbow", 0.6 + math.sin(t * 2 + s + 0.5) * 0.3, 0, 0)
	add(pose, "LeftShoulder", 0.2, 0, -0.15)
	add(pose, "LeftElbow", 0.8, 0, 0)
end

STYLES.Feral = function(pose, t, s)
	local breath = math.sin(t * 4 + s)
	add(pose, "Waist", -0.45 + breath * 0.05, 0, 0)
	add(pose, "Neck", 0.3, math.sin(t * 0.7 + s) * 0.4, 0)
	add(pose, "LeftShoulder", 0.35 + breath * 0.05, 0, -0.2)
	add(pose, "RightShoulder", 0.35 - breath * 0.05, 0, 0.2)
	add(pose, "LeftElbow", 0.5, 0, 0)
	add(pose, "RightElbow", 0.5, 0, 0)
	add(pose, "LeftHip", 0.3, 0, -0.1)
	add(pose, "RightHip", 0.3, 0, 0.1)
	add(pose, "LeftKnee", -0.6, 0, 0)
	add(pose, "RightKnee", -0.6, 0, 0)
end

STYLES.Doll = function(pose, t, s)
	-- Positions qui changent d'un coup, comme une poupée mécanique
	local step = math.floor(t * 0.8 + s)
	local tilt = ((step * 37) % 7 - 3) / 3
	add(pose, "Neck", 0, tilt * 0.4, tilt * 0.35)
	add(pose, "LeftShoulder", 0, 0, -0.25)
	add(pose, "RightShoulder", 0, 0, 0.25)
end

-- Secousse aléatoire (tête, bras ou torse qui sursaute)
local function randomTwitch(intensity: number): Pose
	local pose: Pose = {}
	local r = Random.new()
	add(pose, "Neck", r:NextNumber(-0.6, 0.6) * intensity, r:NextNumber(-0.8, 0.8) * intensity, r:NextNumber(-0.9, 0.9) * intensity)
	if r:NextNumber() < 0.5 then
		local side = if r:NextNumber() < 0.5 then "Left" else "Right"
		add(pose, `{side}Shoulder`, r:NextNumber(0.3, 1.2) * intensity, 0, r:NextNumber(-0.5, 0.5) * intensity)
		add(pose, `{side}Elbow`, r:NextNumber(0.2, 1.2) * intensity, 0, 0)
	end
	add(pose, "Waist", r:NextNumber(-0.2, 0.2) * intensity, r:NextNumber(-0.3, 0.3) * intensity, 0)
	return pose
end

local TWITCHY: { [string]: { every: number, intensity: number } } = {
	Creepy = { every = 4, intensity = 0.6 },
	Twitch = { every = 1.2, intensity = 1 },
	Feral = { every = 3, intensity = 0.5 },
	Doll = { every = 6, intensity = 0.4 },
}

local function track(model: Model)
	if rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") or not model.Parent then
		return
	end
	local joints: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and table.find(JOINTS, descendant.Name) then
			joints[descendant.Name] = descendant
		end
	end
	rigs[model] = {
		model = model,
		root = root,
		joints = joints,
		style = (model:GetAttribute("Motion") :: string?) or "Guest",
		seed = math.random() * 100,
		phase = 0,
		walk = 0,
		twitchUntil = 0,
		nextTwitch = os.clock() + math.random() * 4,
		twitch = {},
	}
	model:GetAttributeChangedSignal("Motion"):Connect(function()
		local rig = rigs[model]
		if rig then
			rig.style = (model:GetAttribute("Motion") :: string?) or "Guest"
		end
	end)
end

local function update(rig: Rig, dt: number, now: number)
	local velocity = rig.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local speed = if rig.root.Anchored then 0 else velocity.Magnitude
	local moving = speed > WALK_SPEED_MIN
	rig.walk += ((if moving then 1 else 0) - rig.walk) * math.min(1, dt * 8)
	if moving then
		rig.phase += dt * speed * 0.55
	end

	local pose: Pose = {}
	local style = STYLES[rig.style] or STYLES.Guest
	style(pose, now, rig.seed)

	-- Petits sursauts
	local twitchy = TWITCHY[rig.style]
	if twitchy then
		if now >= rig.nextTwitch then
			rig.twitch = randomTwitch(twitchy.intensity)
			rig.twitchUntil = now + 0.12 + math.random() * 0.15
			rig.nextTwitch = now + twitchy.every * (0.5 + math.random())
		end
		if now < rig.twitchUntil then
			for joint, angles in rig.twitch do
				add(pose, joint, angles.X, angles.Y, angles.Z)
			end
		end
	end

	-- Marche : on remplace bras et jambes par le cycle de marche
	local w = rig.walk
	local bob = 0
	if w > 0.01 then
		local p = rig.phase
		local swing = math.sin(p)
		for _, joint in { "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" } do
			if pose[joint] then
				pose[joint] *= (1 - w)
			end
		end
		add(pose, "LeftHip", swing * 0.6 * w, 0, 0)
		add(pose, "RightHip", -swing * 0.6 * w, 0, 0)
		add(pose, "LeftKnee", -math.max(0, math.cos(p)) * 0.9 * w, 0, 0)
		add(pose, "RightKnee", -math.max(0, -math.cos(p)) * 0.9 * w, 0, 0)
		add(pose, "LeftShoulder", -swing * 0.5 * w, 0, 0)
		add(pose, "RightShoulder", swing * 0.5 * w, 0, 0)
		add(pose, "LeftElbow", 0.35 * w, 0, 0)
		add(pose, "RightElbow", 0.35 * w, 0, 0)
		add(pose, "Waist", 0, swing * 0.1 * w, 0)
		bob = (math.abs(math.cos(p)) - 0.6) * 0.15 * w
	end

	for name, joint in rig.joints do
		local angles = pose[name]
		local transform = if angles then CFrame.Angles(angles.X, angles.Y, angles.Z) else CFrame.identity
		if name == "Root" then
			transform = CFrame.new(0, bob, 0) * transform
		end
		joint.Transform = transform
	end
end

function RigMotionController.Start(_self: typeof(RigMotionController))
	local function consider(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("Motion") then
			task.spawn(track, instance)
		end
	end
	workspace.DescendantAdded:Connect(consider)
	for _, instance in workspace:GetDescendants() do
		consider(instance)
	end

	RunService.PreSimulation:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for model, rig in rigs do
			if not model.Parent or not rig.root.Parent then
				rigs[model] = nil
			elseif (rig.root.Position - eye).Magnitude < MAX_DISTANCE then
				update(rig, dt, now)
			end
		end
	end)
end

return RigMotionController
