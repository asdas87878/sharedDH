"""The air hop onto the sub, measured in a playtest (docs/design/submarine.md, "The air hop"; NULLROOM z1, 2026-11-25).
IT PUTS THE PLAYER ON A RIDE FISH, WALKS THEM OFF THE DOCK AND SENDS THEM ON TRIPS: run it only in a playtest you started
yourself, with nobody playing in it. It stands on tools/studio/fish_sub_check.py and sub_camera_check.py (their helpers,
their walk), with the hop's own readings added. Hugo's PC, studio-runner.
    python tools/studio/air_hop_check.py install             (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/air_hop_check.py mine                (is this Play ours?)
    python tools/studio/air_hop_check.py gate                (are the stills live?)
    python tools/studio/air_hop_check.py all                 (every hop, the cases with none, the given up ones)
    python tools/studio/air_hop_check.py hop <tier> <land> <fish> <size> [side]
    python tools/studio/air_hop_check.py giveup <unequip|die|reset> <seconds> [tier] [land] [fish]
    python tools/studio/air_hop_check.py stills <tier> <land> <fish> <size> [tries]   (the hop's moments, docs/attachments)
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/air_hop_check.py remove              (in Edit, after the stop)
Read on each hop, every frame on the player's own machine, after every camera step:
  the word     how long after the leap began the trip was back (the plan waits for nobody: 0.3 s, Sub.AirAtLeast), and the
               longest server frame around it (what one leap costs everyone else);
  the times    jump, seat, splash, run, of the trip's plan;
  the swap     never neither and never both of the land fish and the trip's, as seen (LocalTransparencyModifier);
  the rider    its move in a frame against the last (a jolt), from the jump on;
  the camera   its move and turn in a frame against the last (shaken frames left out), the side and the bearing off the
               leap's line, and back above the water once it was under;
  the trail    the sub's bubble rate in the air, from the splash, in the run; and how many frames a second.
Limits: the offline check's (tools/subs/air_check.luau), a third more for Studio's uneven frames. Log: work/subcam/airhop.
"""
import json
import math
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_sub_check as fs  # noqa: E402

sc = fs.sc
sc.OUT = sc.OUT.parent / "airhop"
sc.OUT.mkdir(parents=True, exist_ok=True)
sc.VIEW_FILE = sc.OUT / "view.json"
sc.TOKEN_FILE = sc.OUT / "token.txt"
sc.COLOURS["Leap"] = (255, 128, 0)
sc.COLOURS["Hop"] = (128, 0, 255)

HOPS = [
    (1, 2, "Clownfish", "Normal", 0),
    (5, 6, "Clownfish", "Tiny", 0),
    (9, 10, "Clownfish", "Normal", 0),
    (1, 2, "GreatWhite", "Normal", 0),
    (5, 6, "GreatWhite", "Normal", 0),
    (9, 10, "GreatWhite", "Big", 0),
    (5, 6, "GreatWhite", "Normal", -28),
    (5, 6, "GreatWhite", "Normal", 28),
    (1, 2, "BlueWhale", "Colossal", 0),
    (5, 6, "BlueWhale", "Colossal", 0),
    (9, 10, "BlueWhale", "Colossal", 0),
    (9, 5, "Kraken", "Colossal", 0),
]

SERVER_EXTRA = r'''
-- the server's frames round a trip's making (air_hop_check.py)
do
	local RunService = game:GetService("RunService")
	local frames = {}
	RunService.Heartbeat:Connect(function(dt)
		table.insert(frames, { os.clock(), dt })
		if #frames > 240 then table.remove(frames, 1) end
	end)
	local function watch(player)
		player:GetAttributeChangedSignal("SubTrip"):Connect(function()
			local json = player:GetAttribute("SubTrip")
			if type(json) ~= "string" then return end
			local made = workspace:GetServerTimeNow() - game:GetService("HttpService"):JSONDecode(json).S
			local at = os.clock()
			local before = {}
			for _, f in frames do table.insert(before, f[2]) end
			table.sort(before)
			local usual = before[math.ceil(#before / 2)] or 0
			task.delay(0.4, function()
				local worst = 0
				for _, f in frames do
					if math.abs(f[1] - at) < 0.5 then worst = math.max(worst, f[2]) end
				end
				player:SetAttribute("AHMade", string.format("%.4f,%.4f,%.4f", made, worst, usual))
			end)
		end)
	end
	for _, p in Players:GetPlayers() do watch(p) end
	Players.PlayerAdded:Connect(watch)
end
'''

CLIENT_EXTRA = r'''
-- the hop's own readings, every frame (air_hop_check.py)
local SubAir = require(RS.Shared:WaitForChild("SubAir"))
airRec = nil
local airFor = nil
local function shownShare(model)
	local n, seen = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			n += 1
			if d.LocalTransparencyModifier < 0.95 then seen += 1 end
		end
	end
	return if n > 0 then seen / n else 0
end
local function airStep(dt)
	local r = rec
	if not r or r.done then return end
	if airFor ~= r then
		airFor = r
		airRec = { rows = {}, wordAt = -1 }
	end
	local e = airRec
	local trip = r.trip
	if not trip then return end
	local t = workspace:GetServerTimeNow() - trip.Start
	if e.wordAt < 0 then
		e.wordAt = t
		local air = trip.Air
		if air then
			e.air = { hop = air.HopAt, seat = air.SeatAt, splash = air.SplashAt, ride = air.RideAt, entry = SubAir.entry(air) }
		end
	end
	if not trip.Air or t > trip.Air.RideAt + 2 or #e.rows > 900 then return end
	local ours, oursN = 0, 0
	local folder = workspace:FindFirstChild("Fish")
	for _, m in folder and folder:GetChildren() or {} do
		if m:IsA("Model") and m:GetAttribute("SubFor") == player.UserId then
			oursN += 1
			ours = math.max(ours, shownShare(m))
		end
	end
	local land, landN = 0, 0
	local lands = workspace:FindFirstChild("LandFish")
	for _, m in lands and lands:GetChildren() or {} do
		if m:GetAttribute("LandRider") == player.UserId then
			landN += 1
			land = math.max(land, shownShare(m))
		end
	end
	local rate, live = -1, 0
	local model = ourSub()
	for _, d in model and model:GetDescendants() or {} do
		if d:IsA("ParticleEmitter") then
			rate = math.max(rate, if d.Enabled then d.Rate else 0)
			live += 1
		end
	end
	table.insert(e.rows, { math.floor(t * 1000) / 1000, math.floor(dt * 10000) / 10000, oursN, math.floor(ours * 100) / 100, landN,
		math.floor(land * 100) / 100, math.floor(rate * 10) / 10, tostring(State.Mode), tostring(player:GetAttribute("SubPhase")) })
end
RunService:BindToRenderStep("ZZAirHop", Enum.RenderPriority.Last.Value + 2, function(dt)
	local ok, why = pcall(airStep, dt)
	if not ok and airRec then airRec.error = tostring(why) end
end)

'''

CLIENT_VERBS = r'''
		elseif verb == "air" then
			if not airRec then return "no hop record" end
			airRec.made = player:GetAttribute("AHMade")
			report:FireServer("data", words[2] .. ":air", HttpService:JSONEncode(airRec))
			return "hop rows=" .. #airRec.rows
'''

# (the view behind the player before the walk: left as the last trip left it, the leap has to swing it round first)
BEHIND = "character:PivotTo(CFrame.lookAt(stand, stand + out))\n"
assert BEHIND in sc.CLIENT
sc.CLIENT = sc.CLIENT.replace(BEHIND, BEHIND + "\t\t\tdo local eye = stand - out * 13 + Vector3.new(0, 5, 0) workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, eye + out * 10 - Vector3.new(0, 2, 0)) end\n", 1)
sc.SERVER = sc.SERVER + SERVER_EXTRA
sc.CLIENT = fs.patch(sc.CLIENT, "local function v3(v)", CLIENT_EXTRA, "the hop's step")
sc.CLIENT = fs.patch(sc.CLIENT, '\t\telseif verb == "state" then', CLIENT_VERBS.lstrip("\n"), "the hop's verbs")
sc.CLIENT = fs.patch(sc.CLIENT, "local rec = nil -- the trip being written down", "local airRec = nil\n", "the hop's record")


def dist(a, b):
    return sum((p - q) ** 2 for p, q in zip(a, b)) ** 0.5


def hop(tier, land, fish, size="Normal", side=0):
    label = f"{tier}-{land}-{fish}-{size}" + (f"-{side}" if side else "")
    if not fs.go(tier, land, fish, size, label, side):
        sc.note("  ! no trip began")
        fs.home()
        sc.save_log()
        return False
    before, _ = fs.hands()
    end = time.time() + 45
    while time.time() < end and "done=true" not in sc.do("state", 0.2):
        time.sleep(0.4)
    after, said = fs.hands()
    sc.do(f"air|{label}", 1.2)
    air = json.loads(sc.value(label + ":air").strip().splitlines()[-1])
    meta, rows = sc.end_trip(label)
    (sc.OUT / f"{label}-air.json").write_text(json.dumps(air))
    results = []

    def ok(what, good, seen=""):
        results.append(bool(good))
        sc.note(f"  {'ok  ' if good else 'FAIL'}  {what}  {seen}")

    a = air.get("air")
    if not a:
        ok("the air hop, not the one under water", False, f"word at {air.get('wordAt'):.2f}")
        sc.save_log()
        return False
    made, worst, usual = [float(v) for v in (air.get("made") or "-1,-1,-1").split(",")]
    ok("the word is back by the jump", air["wordAt"] < a["hop"],
       f"made {made:.3f} s, back {air['wordAt']:.3f} s after the leap began; jump at {a['hop']:.3f}; longest server frame {worst * 1000:.0f} ms (usual {usual * 1000:.0f})")
    sc.note(f"  the plan: jump {a['hop']:.2f}, seat {a['seat']:.2f} ({a['seat'] - a['hop']:.2f} s), splash {a['splash']:.2f}, run {a['ride']:.2f}, the fish in {a['entry']:.2f}")
    R = air["rows"]
    span = [r for r in R if a["hop"] <= r[0] <= a["ride"]]
    fps = len(span) / max(sum(r[1] for r in span), 1e-3)
    ok("40 frames a second and more in the hop", fps >= 40, f"{fps:.0f} on average, longest frame {max(r[1] for r in R) * 1000:.0f} ms")
    neither = [r[0] for r in R if 0 < r[0] < a["ride"] and r[3] < 0.05 and r[5] < 0.05]
    both = [r[0] for r in R if 0 < r[0] < a["ride"] and r[3] > 0.3 and r[5] > 0.3]
    ok("never neither fish", len(neither) <= 1, f"{len(neither)} frames {neither[:3]}")
    ok("never both", len(both) <= 1, f"{len(both)} frames {both[:3]}")
    air_rate = max((r[6] for r in R if 0 < r[0] < a["splash"] - 0.05), default=-1)
    wake = [r[6] for r in R if a["splash"] + 0.05 < r[0] < a["ride"]]
    run = [r[6] for r in R if r[0] > a["ride"] + 1]
    ok("no trail in the air", air_rate <= 0, f"{air_rate}")
    ok("a weaker trail from the splash", wake and run and max(wake) <= max(run) * 0.55,
       f"splash to run {min(wake or [0]):.0f} to {max(wake or [0]):.0f} a second, the run's own {max(run or [0]):.0f}")
    frames = sc.parse(rows)
    fl = [f for f in frames if 0 <= f["t"] <= a["ride"] + 0.5]
    move, turn, jolt = [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]
    moveAll, turnAll, calm = [0.0, 0.0], [0.0, 0.0], 0
    for p, q, r in zip(fl, fl[1:], fl[2:]):
        # (uneven frames: each move as studs in a 60th of a second by the trip's own clock, the change of it against the last)
        d1, d2 = max(q["t"] - p["t"], 0.004) * 60, max(r["t"] - q["t"], 0.004) * 60
        still = max(p["shake"], q["shake"], r["shake"]) < 0.02
        calm += still
        for key in ("cam", "rider"):
            d = dist([(y - x) / d1 for x, y in zip(p[key], q[key])], [(y - x) / d2 for x, y in zip(q[key], r[key])])
            for worst_of in ((jolt,) if key == "rider" else (moveAll, move) if still else (moveAll,)):
                if d > worst_of[0]:
                    worst_of[0], worst_of[1] = d, r["t"]
        g = sc.angle_between(q["look"], r["look"]) / d2
        for worst_of in (turnAll, turn) if still else (turnAll,):
            if g > worst_of[0]:
                worst_of[0], worst_of[1] = g, r["t"]
    ok("the camera's move in a frame against the last (2.5 and a third)", move[0] <= 3.4 and calm > 5,
       f"{move[0]:.2f} studs at {move[1]:.2f} s in {calm} of {len(fl)} calm frames; {moveAll[0]:.2f} at {moveAll[1]:.2f} s with the shaken ones")
    ok("the camera's turn in a 60th (6 and a third)", turn[0] <= 8,
       f"{turn[0]:.1f} degrees at {turn[1]:.2f} s; {turnAll[0]:.1f} at {turnAll[1]:.2f} s with the shaken ones")
    sc.note(f"  the rider's move against the last: {jolt[0]:.1f} studs at {jolt[1]:.2f} s (the jump, the seat and the splash are kinks of the plan's own)")
    surface = meta["surfaceY"]
    went, back, worst_up = None, 0, -99.0
    for f in fl + [f for f in frames if a["ride"] + 0.5 < f["t"] <= a["ride"] + 3]:
        y = f["cam"][1] - surface
        if went is None and y < -0.2:
            went = f["t"]
        elif went is not None:
            worst_up = max(worst_up, y)
            if y > 0:
                back += 1
    ok("never back above the water", went is not None and back == 0, f"under at {went and round(went, 2)} s, highest after {worst_up:.1f}")
    out = meta.get("out")
    off = []
    if out:
        way = sc.flat(out[0], out[2])
        for f in fl:
            if f["t"] < 0.5:
                continue
            fwd = sc.flat(f["look"][0], f["look"][2])
            if fwd:
                off.append(math.degrees(math.acos(max(-1, min(1, fwd[0] * way[0] + fwd[1] * way[1])))))
    ok("the view behind, along the leap (25 degrees)", off and max(off) < 25, f"most {max(off or [0]):.1f} degrees off")
    hidden = [f["t"] for f in fl if a["hop"] < f["t"] < a["ride"] and not f["rOn"]]
    ok("the rider in the picture", len(hidden) <= 2, f"{len(hidden)} frames out of it")
    ok("the hands' fish unchanged", before.get("hands") == after.get("hands"), f"{before.get('hands')} {after.get('hands')}")
    ok("carried on, and kicked at the land", meta.get("cue") == "Kick", f"{meta.get('cue')} {said}")
    if air.get("error"):
        ok("no errors in the readings", False, air["error"])
    sc.note(f"{'PASS' if all(results) else 'FAIL'}  {label}")
    sc.save_log()
    return all(results)


def none(what):
    """the cases with no air hop: no sub, on foot"""
    if what == "nosub":
        sc.cmd("ride|1,2,GreatWhite,Normal", 2.5)
        sc.s2.server("local p = game:GetService('Players'):GetPlayers()[1] local t = game:GetService('ServerStorage').SubTest t:Invoke('equip', p.UserId, 0) return 'off'")
        sc.do("rec|nosub", 0.4)
        sc.fire("walk|12|0")
        time.sleep(8)
        said = sc.do("state", 0.4)
        _, hands = fs.hands()
        sc.note(f"[no sub] {said} {hands}")
        good = "trip=false" in hands and ("Riding" in said or "Failing" in said)
    else:
        went = fs.go(5, 6, "GreatWhite", "foot", "foot")
        sc.do("air|foot", 0.6)
        air = json.loads(sc.value("foot:air").strip().splitlines()[-1])
        sc.note(f"[on foot] trip {went}, an air hop: {bool(air.get('air'))}")
        good = went and not air.get("air")
        time.sleep(12)
    fs.home()
    sc.note(f"{'PASS' if good else 'FAIL'}  {what}")
    sc.save_log()
    return good


def still_phase(im):
    x0, y0, _, _, scale = json.loads(sc.VIEW_FILE.read_text())
    px = im.load()
    a = px[round(x0 + 20 * scale), round(y0 + 5 * scale)]
    b = px[round(x0 + 60 * scale), round(y0 + 5 * scale)]
    for phase, colour in sc.COLOURS.items():
        if sc.near(a, colour, 45):
            return phase, b[0] / 255
    return None, 0


def stills(tier, land, fish, size, tries=12):
    """one grab a trip, a little later each time (a grab takes 0.4 to 4 s); every picture of the hop is kept"""
    kept = []
    for n in range(tries):
        label = f"air-still-{n}"
        sc.cmd(f"ride|{tier},{land},{fish},{size}", 2.5)
        sc.do(f"rec|{label}", 0.4)
        sc.fire("walk|12|0")
        time.sleep(3.0)  # (off the fish, the stand, on again)
        end = time.time() + 14
        got = False
        while time.time() < end:
            full = sc.raw(label)
            im = Image.open(full).convert("RGB")
            phase, share = still_phase(im)
            if phase in ("Leap", "Hop") or (phase == "Ride" and share < 0.15):
                x0, y0, x1, y1, scale = json.loads(sc.VIEW_FILE.read_text())
                out = sc.OUT / f"still-{fish}-{size}-{tier}-{n:02d}-{phase}-{round(share * 100):03d}.jpg"
                im.crop((x0, y0 + round(23 * scale), x1, y1)).save(out, quality=90)
                kept.append(out.name)
                sc.note(f"still: {out.name}")
                got = True
            full.unlink(missing_ok=True)
            if phase == "Ride" and share > 0.15 or phase in ("Arrive", "Drop", "Tail"):
                break
            if not got:
                time.sleep(0.03 * (n % 4))
        fs.home()
    sc.note("stills kept: " + ", ".join(sorted(kept)))
    sc.save_log()
    return kept


def everything():
    got = []
    for tier, land, fish, size, side in HOPS:
        try:
            got.append((f"{fish} {size} {tier}>{land} {side}", hop(tier, land, fish, size, side)))
        except (subprocess.TimeoutExpired, json.JSONDecodeError, IndexError) as why:
            sc.note(f"! {why}")
            got.append((f"{fish} {size} {tier}>{land} {side}", False))
            fs.home()
    for what in ("nosub", "foot"):
        got.append((what, none(what)))
    for how in ("unequip", "die", "reset"):
        for at in (0.2, 0.6, 1.2):
            got.append((f"{how} at {at}", fs.giveup(how, at)))
    for what, good in got:
        sc.note(f"{'PASS' if good else 'FAIL'}  {what}")
    sc.note(f"{sum(bool(g) for _, g in got)} of {len(got)} passed")
    sc.save_log()
    return all(g for _, g in got)


if __name__ == "__main__":
    what, rest = sys.argv[1], sys.argv[2:]
    if what == "install":
        print(sc.install())
    elif what == "remove":
        print(sc.install(True))
    elif what == "mine":
        ours, said = sc.mine()
        print(("OURS: " if ours else "NOT OURS: ") + said)
        sys.exit(0 if ours else 1)
    elif what == "gate":
        sc.gate()
    elif what == "hop":
        sys.exit(0 if hop(int(rest[0]), int(rest[1]), rest[2], rest[3], int(rest[4]) if len(rest) > 4 else 0) else 1)
    elif what == "none":
        sys.exit(0 if none(rest[0]) else 1)
    elif what == "giveup":
        kw = [int(rest[2]), int(rest[3]), rest[4]] if len(rest) > 4 else []
        sys.exit(0 if fs.giveup(rest[0], float(rest[1]), *kw) else 1)
    elif what == "stills":
        stills(int(rest[0]), int(rest[1]), rest[2], rest[3], int(rest[4]) if len(rest) > 4 else 12)
    elif what == "all":
        sys.exit(0 if everything() else 1)
