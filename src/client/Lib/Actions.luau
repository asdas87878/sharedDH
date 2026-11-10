--!strict
-- The moves the input layer can ask for; JumpController fills this in. It returns whether it acted.
local Actions = {}

-- Space: jump off the fish (or up from floating) into the flight; in the flight, drop at once
Actions.jump = function(): boolean
	return false
end

return Actions
