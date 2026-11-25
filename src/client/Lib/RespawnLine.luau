--!strict
-- When the dock's line is up (Hugo, 2026-11-25: "make sure this text only shows up when you respawn, it should only stay
-- for a couple of seconds before fading out"; Config.DockLine). One showing each respawn, the first spawn's too:
--   Wait   respawned, and the screen not clear yet (the black, the last words, the catch): the line waits for it
--   Open   slapped on, held, faded
--   Done   nothing more until the next respawn, whatever there is to say
-- Plain sums (no Roblox in it): tools/ui/texts_b1_a3/check.luau runs it.
local RespawnLine = {}

export type Times = { Settle: number, In: number, Hold: number, Fade: number, Cut: number, Give: number }
export type Line = {
	Stage: "Wait" | "Open" | "Done",
	Docked: boolean, -- on the dock since the respawn (its word can come a moment before our state's does)
	ReadyAt: number?, -- in Wait: since when it could have come
	BareAt: number?, -- in Wait: since when the screen is clear with nothing to say
	At: number, -- in Open: when it came
	GoneAt: number?, -- in Open: since when there is nothing to say
}

function RespawnLine.new(): Line
	return { Stage = "Wait", Docked = false, ReadyAt = nil, BareAt = nil, At = 0, GoneAt = nil }
end

function RespawnLine.respawned(line: Line)
	line.Stage, line.Docked = "Wait", false
	line.ReadyAt, line.BareAt, line.GoneAt = nil, nil, nil
end

-- One frame. docked: on the dock; clear: nothing else has the screen; words: there is something to say.
-- Gives how far it is slapped on and how see-through it is, both 0 to 1 (1 see-through: not there).
function RespawnLine.step(
	line: Line,
	now: number,
	docked: boolean,
	clear: boolean,
	words: boolean,
	times: Times
): (number, number)
	if line.Stage == "Wait" then
		line.Docked = line.Docked or docked
		if not docked then
			if line.Docked then
				line.Stage = "Done" -- (off again before it could come)
			end
		elseif not clear then
			line.ReadyAt, line.BareAt = nil, nil
		elseif words then
			line.BareAt = nil
			local since = line.ReadyAt or now
			line.ReadyAt = since
			if now - since >= times.Settle then
				line.Stage, line.At, line.GoneAt = "Open", now, nil
			end
		else
			line.ReadyAt = nil
			local since = line.BareAt or now
			line.BareAt = since
			if now - since >= times.Give then
				line.Stage = "Done"
			end
		end
	end
	if line.Stage ~= "Open" then
		return 0, 1
	end
	local t = now - line.At
	local cut = 0
	if words and docked then
		line.GoneAt = nil
	else
		local since = line.GoneAt or now
		line.GoneAt = since
		cut = if times.Cut > 0 then math.min((now - since) / times.Cut, 1) else 1
	end
	if cut >= 1 or t >= times.Hold + times.Fade then
		line.Stage = "Done"
		return 0, 1
	end
	local fade = if t > times.Hold and times.Fade > 0 then (t - times.Hold) / times.Fade else 0
	return if times.In > 0 then math.min(t / times.In, 1) else 1, math.max(fade, cut)
end

return RespawnLine
