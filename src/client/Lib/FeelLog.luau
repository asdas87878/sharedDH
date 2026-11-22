--!strict
-- The feel log's notebook (Config.FeelLog; Controllers/FeelLogController writes it out and keeps the black box).
-- The hop's code tells it what happens as it happens: FeelLog.event(kind, info). With it off (FeelLog.On false: any
-- real server, or Config.FeelLog.On 0) a call does nothing at all.
-- The kinds: "hop" (From, Launch, Reach, Kept), "press" (Did: "grab", "nothing", "early", "mash", "kept", "wait",
-- "guard"), "reel" (How: "press", "early", "glide", "window", "dive"; Gap, Time), "touch" (Onto), "mount" (Onto),
-- "lost", "miss".
local FeelLog = {}

export type Event = { At: number, Kind: string, Info: { [string]: any }? }

FeelLog.On = false
-- While the feel log asks for a number (its numbered tags over the fish), the number keys are its alone: the hotbar
-- leaves them (EquipController). TakenInput is the last key press it answered, so whichever handler hears a press first,
-- the other one knows (grade issue 5)
FeelLog.TakesNumbers = false
FeelLog.TakenInput = nil :: InputObject?
-- fired with (kind, info, os.clock()) for every event: the controller's hop lines listen
FeelLog.Fired = Instance.new("BindableEvent")

local events: { Event } = {}
local MOST = 600 -- events kept (a few minutes of play)

function FeelLog.event(kind: string, info: { [string]: any }?)
	if not FeelLog.On then
		return
	end
	local at = os.clock()
	table.insert(events, { At = at, Kind = kind, Info = info })
	if #events > MOST then
		table.remove(events, 1)
	end
	FeelLog.Fired:Fire(kind, info, at)
end

-- The events since `from` (an os.clock()), oldest first
function FeelLog.since(from: number): { Event }
	local out = {}
	for _, e in events do
		if e.At >= from then
			table.insert(out, e)
		end
	end
	return out
end

return FeelLog
