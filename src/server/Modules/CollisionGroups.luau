--!strict
-- Groupes de collision : la barrière de verrou d'un hôtel bloque tout le monde
-- sauf son propriétaire et les clients de la réception.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.GUESTS = "Guests"

function CollisionGroups.barrier(hotelIndex: number): string
	return `Barrier{hotelIndex}`
end

function CollisionGroups.owner(hotelIndex: number): string
	return `Owner{hotelIndex}`
end

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

-- À appeler une fois au démarrage (sans risque si appelé plusieurs fois)
function CollisionGroups.setup(hotelCount: number)
	register(CollisionGroups.GUESTS)
	for index = 1, hotelCount do
		local barrier = CollisionGroups.barrier(index)
		local owner = CollisionGroups.owner(index)
		register(barrier)
		register(owner)
		PhysicsService:CollisionGroupSetCollidable(owner, barrier, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.GUESTS, barrier, false)
	end
end

-- Met toutes les pièces d'un modèle (et celles ajoutées plus tard) dans un groupe
function CollisionGroups.assign(model: Instance, group: string): RBXScriptConnection
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
	return model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end)
end

return CollisionGroups
