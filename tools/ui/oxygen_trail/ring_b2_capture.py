"""Oxygen ring B, second pass (task o1, 2026-11-19): a full fish at 4500 max Oxygen, three rings of 1500, the thin
rings emptying first (outermost first), then the big ring, then the red zone's six even ticks.
    python tools/ui/oxygen_trail/ring_b2_capture.py plan [seconds]      print the ticks the server would take
    python tools/ui/oxygen_trail/ring_b2_capture.py live <slow> <x0,y0,x1,y1> [seconds]
    python tools/ui/oxygen_trail/ring_b2_capture.py ticklog install|listen|read|remove
`live` drives trail_client.luau (install it first: trail_capture.py install, then listen) with the ticks of
`sim` below, a copy of RideService.tickDrain with Config's numbers (60 ticks, 0.2 s floor, RedTime 2.5 in 6 ticks).
`ticklog` logs the real server's OxygenTick messages on a real ride, to check the plan against the game.
Writes docs/attachments/oxygen-trail-b-2.gif and copies it to ~/Pictures/ride-a-fish/sheets/.
"""
import json
import sys
import tempfile

import trail_capture as tc

MAX = 4500
TICKS = 60
FLOOR = 0.2
RED_AT = 1 / 3
RED_TIME = 2.5
RED_TICKS = 6
RED_MOST = 0.45


def sim(seconds):
    """The ticks of one ride from a full meter: (t, from, to). Config.drainFor, tickOf, redSeconds, redTicks"""
    red = min(RED_TIME, RED_MOST * seconds)
    line = MAX * RED_AT
    rate = (MAX - line) / (seconds - red)
    piece = max(MAX / TICKS, rate * FLOOR)
    gap = piece / rate
    t, a, out = 0.0, float(MAX), []
    red_piece = None
    while a > 0:
        t += gap
        size = red_piece or piece
        if a - size < MAX * 1e-6:
            size = a
        out.append([round(t, 3), round(a, 2), round(a - size, 2)])
        a -= size
        if red_piece is None and 0 < a <= line:
            count = max(1, min(RED_TICKS, int(red / FLOOR + 1e-6)))
            red_piece, gap = a / count, red / count
    return out


def plan(seconds, lead=0.4):
    ev = sim(seconds)
    events = [[round(e[0] + lead - ev[0][0], 3), e[1], e[2]] for e in ev]
    end = events[-1][0] + 0.8
    return {"max": MAX, "start": MAX, "events": events, "finish": round(end, 3)}, end


TICKLOG = """local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZTickLog") if old then old:Destroy() end
if %s then return "removed" end
local s = Instance.new("LocalScript") s.Name = "ZZTickLog"
s.Source = [==[
local RS = game:GetService("ReplicatedStorage")
local Net = require(RS.Shared.Net)
local t0 = os.clock()
Net.Ride.OnClientEvent:Connect(function(kind, lost, now, gap, what)
	if kind == "OxygenTick" then
		local r = RS:FindFirstChild("ZZTrailReport")
		if r then r:FireServer(string.format("%%.2f %%s lost %%.1f now %%.1f gap %%.3f", os.clock() - t0, tostring(what), lost, now, gap)) end
	elseif kind == "Mounted" then
		t0 = os.clock()
		local r = RS:FindFirstChild("ZZTrailReport") if r then r:FireServer("mounted") end
	end
end)
]==]
s.Parent = sps
return "installed"
"""

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "plan":
        p, end = plan(float(sys.argv[2]) if len(sys.argv) > 2 else 9)
        for e in p["events"]:
            print(e, f"{(e[1] - e[2]) / MAX * 3 * 100:.1f}% of a ring")
        print("ticks", len(p["events"]), "end", end)
    elif cmd == "live":
        p, end = plan(float(sys.argv[4]) if len(sys.argv) > 4 else 9)
        tc.PLAN, tc.END = p, end
        tc.LETTER[2] = "b-2"
        tc.NAMES[2] = "ring B, 3 rings at 4500"
        crop = tuple(int(x) for x in sys.argv[3].split(","))
        print(tc.live(2, float(sys.argv[2]), crop))
    elif cmd == "ticklog":
        sub = sys.argv[2]
        if sub in ("install", "remove"):
            with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
                f.write(TICKLOG % ("true" if sub == "remove" else "false"))
            print(tc.run([f.name]))
        elif sub == "listen":
            print(tc.server(tc.LISTEN))
        elif sub == "read":
            print(tc.log())
