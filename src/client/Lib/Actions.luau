--!strict
-- The moves the input layer can ask for; JumpController fills this in. It returns whether it acted.
local Actions = {}

-- Space: leave the fish (or start from floating) into the hop; in the hop, grab the locked fish
Actions.jump = function(): boolean
	return false
end

return Actions
