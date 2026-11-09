--!strict
-- The moves the input layer can ask for; the Dash and Grapple controllers fill these in. Each returns whether it acted.
local Actions = {}

Actions.dash = function(): boolean
	return false
end

Actions.beginAim = function(): boolean
	return false
end

Actions.fire = function(): boolean
	return false
end

return Actions
