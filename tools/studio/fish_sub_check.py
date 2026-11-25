"""From the fish onto the submarine, measured in a playtest (docs/design/submarine.md, "From the fish onto the sub").
IT PUTS THE PLAYER ON A RIDE FISH, WALKS THEM OFF THE DOCK AND SENDS THEM ON TRIPS: run it only in a playtest you started
yourself, with nobody playing in it. It stands on tools/studio/sub_camera_check.py (its helpers in the place, its walk,
its camera sums), with the fish's own readings added.
    python tools/studio/fish_sub_check.py install            (in Edit, before Play)
    node ~/Projects/studio-runner/studio-run.mjs play
    python tools/studio/fish_sub_check.py mine               (is this Play ours?)
    python tools/studio/fish_sub_check.py gate               (are the stills live? finds the game view)
    python tools/studio/fish_sub_check.py all                (the whole list below, every reading; about 8 minutes)
    python tools/studio/fish_sub_check.py trip <tier> <land> [fish] [size] [label]   (one; fish "-": none, the fling;
                                                             size "foot": the fish equipped but on foot, as before)
    python tools/studio/fish_sub_check.py giveup <unequip|die|reset> <seconds>       (given up that far into a trip)
    python tools/studio/fish_sub_check.py stills <tier> <land> <fish> <size> [tries] (hop, left, right, return, kick)
    node ~/Projects/studio-runner/studio-run.mjs stop
    python tools/studio/fish_sub_check.py remove             (in Edit, after the stop)
What `all` runs: a small, a middling and the biggest fish to lands 2, 5 and 10; no fish (the fling); on foot (the old
swim); given up by unequipping, dying and resetting at 1.5 s and 4 s. Written before any run; it has not been run yet.
Passes when, on each ridden trip:
  one fish of ours in the water from the hand-over to the seat, never none and never two, the same model all through
  (the one the kick is cued with), the fish of the hands unchanged in number;
  the land fish gone and the water one in its pose at most 3 frames apart;
  the fish where the trip has it (SubTrip.escort) within half a stud from the hop on;
  in the picture in nine tenths of the weave's frames, and seen left and right of the view's middle (on a side its plan
  has the room for);
  the camera's own limits (sub_camera_check's) from the Ride to the Drop.
Printed for a person to judge: what built map the fish's box (four fifths of it) touches, by part name (the offline check
knows only the lane's width, not the terraces), and the pictures in docs/attachments/fishsub-*.jpg.
Log: work/subcam/fishsub/check.log.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sub_camera_check as sc  # noqa: E402

sc.OUT = sc.OUT / "fishsub"
sc.OUT.mkdir(parents=True, exist_ok=True)
sc.VIEW_FILE = sc.OUT / "view.json"
sc.TOKEN_FILE = sc.OUT / "token.txt"
sc.KELP_FILE = sc.OUT / "kelp.json"

TRIPS = [
    (1, 2, "Clownfish", "Normal"),
    (4, 5, "GreatWhite", "Normal"),
    (9, 10, "Dolphin", "Normal"),
    (9, 10, "GreatWhite", "Big"),
    (9, 2, "Megalodon", "Normal"),
    (9, 5, "BlueWhale", "Colossal"),
    (9, 10, "BlueWhale", "Colossal"),
    (6, 7, "MantaRay", "Normal"),
]
MOMENTS = {
    "None": (0, 0, 0),
    "Hop": (255, 0, 0),
    "Left": (0, 255, 0),
    "Right": (0, 0, 255),
    "Return": (255, 255, 0),
    "Kick": (255, 0, 255),
}

SERVER_VERBS = r'''
		elseif verb == "ride" then -- tier, land, fish id ("-": none), size ("foot": equipped, not ridden)
			local tier, land, fish, size = string.match(arg, "(%d+),(%d+),([%w%-]+),(%w+)")
			RideService.sendHome(player)
			t:Invoke("give", player.UserId, 1e13, nil)
			for _ = 1, 9 do
				t:Invoke("buy", player.UserId)
			end
			t:Invoke("equip", player.UserId, tonumber(tier))
			t:Invoke("pick", player.UserId, tonumber(land), "")
			RideService.landOff(player)
			for _ = 1, #RideService.carried(player) do
				RideService.takeCarried(player, 1)
			end
			task.wait(0.3)
			if fish == "-" then
				return "no fish"
			end
			local real = if size == "foot" then "Normal" else size
			if not RideService.giveCarried(player, { Id = fish, Size = real, Variant = "" }) then
				return "not given"
			end
			local list = RideService.carried(player)
			local on = RideService.rideOut(player, list[#list])
			if size == "foot" then
				RideService.landOff(player)
			end
			return string.format("on=%s mounted=%s equipped=%s hands=%d", tostring(on), tostring(player:GetAttribute("LandMounted")),
				tostring(player:GetAttribute("EquippedFish")), #list)
		elseif verb == "hands" then
			local n, held = 0, 0
			local folder = workspace:FindFirstChild("Fish")
			for _, m in folder and folder:GetChildren() or {} do
				if m:GetAttribute("SubFor") == player.UserId then
					n += 1
				end
			end
			for _, m in SS:GetDescendants() do
				if m:IsA("Model") and m:GetAttribute("SubFor") == player.UserId then
					held += 1
				end
			end
			return string.format("hands=%d fish=%d parked=%d state=%s trip=%s equipped=%s", #RideService.carried(player), n, held,
				tostring(RideService.stateOf(player)), tostring(player:GetAttribute("SubTrip") ~= nil), tostring(player:GetAttribute("EquippedFish")))
		elseif verb == "giveat" then -- how ("die", "reset"), seconds into the next trip: armed before the walk
			local how, after = string.match(arg, "(%w+),([%d%.]+)")
			task.spawn(function()
				local until_ = os.clock() + 20
				while os.clock() < until_ and not player:GetAttribute("SubTrip") do
					task.wait()
				end
				local json = player:GetAttribute("SubTrip")
				if not json then return end
				local start = game:GetService("HttpService"):JSONDecode(json).S
				while workspace:GetServerTimeNow() - start < tonumber(after) do
					task.wait()
				end
				workspace:SetAttribute("SCGave", string.format("%s at %.2f s", how, workspace:GetServerTimeNow() - start))
				if how == "die" then
					player.Character.Humanoid.Health = 0
				else
					player:LoadCharacter()
				end
			end)
			return "armed"
		elseif verb == "gave" then
			local said = workspace:GetAttribute("SCGave")
			workspace:SetAttribute("SCGave", nil)
			return tostring(said)
'''

CLIENT_VERBS = r'''
		elseif verb == "unequip" then -- so many seconds into the next trip: armed before the walk
			unequipAt = tonumber(words[2]) or 0
			report:FireServer("data", "gave", "not yet")
			return "armed"
		elseif verb == "esc" then
			local e = escRec
			if not e then return "no escort record" end
			report:FireServer("data", words[2] .. ":esc", HttpService:JSONEncode(e))
			return "escort rows=" .. #e.rows
'''

CLIENT_STEP = r'''
-- the fish's own readings, every frame (fish_sub_check.py)
local MOMENTS = __MOMENTS__
local escGui = Instance.new("Frame")
escGui.BorderSizePixel = 0
escGui.Size = UDim2.fromOffset(120, 10)
escGui.Position = UDim2.fromOffset(0, 12)
escGui.BackgroundColor3 = Color3.new(0, 0, 0)
escGui.Parent = gui
escRec = nil
unequipAt = nil
local escFor = nil
local escModel = nil
local function escStep()
	local r = rec
	if not r or r.done then return end
	if escFor ~= r then
		escFor = r
		escModel = nil
		escRec = { rows = {}, touched = {}, same = true }
	end
	local e = escRec
	if #e.rows > 3000 then return end
	local mine, n = nil, 0
	local folder = workspace:FindFirstChild("Fish")
	for _, m in folder and folder:GetChildren() or {} do
		if m:IsA("Model") and m:GetAttribute("SubFor") == player.UserId then
			n += 1
			mine = m
		end
	end
	local land = workspace:FindFirstChild("LandFish")
	local landN = 0
	for _, m in land and land:GetChildren() or {} do
		if m:GetAttribute("LandRider") == player.UserId then landN += 1 end
	end
	if mine and not escModel then
		escModel = mine
		e.kind = tostring(mine:GetAttribute("FishType")) .. " " .. tostring(mine:GetAttribute("SizeTier"))
	elseif mine and escModel ~= mine then
		e.same = false
	end
	local trip = r.trip
	local t = if trip then workspace:GetServerTimeNow() - trip.Start else -1
	if unequipAt and t >= unequipAt and trip and not r.done then
		unequipAt = nil
		Net.Action:FireServer("RideUnequip")
		report:FireServer("data", "gave", string.format("unequip at %.2f s", t))
	end
	local err, ox, oy, oz, on, sx, seen = -1, 0, 0, 0, -1, 0, 1
	local moment = "None"
	local fishRoot = mine and mine.PrimaryPart
	local want, o = nil, nil
	if trip and trip.Escort then
		want, o = SubTrip.escort(trip, t)
	end
	if fishRoot and want then
		-- (against the sub as it was put this frame: by the clock read now, a millisecond is 4 studs at full speed)
		local _, placed = ourSub()
		local planned = SubTrip.sub(trip, t)
		err = if placed
			then (placed:PointToObjectSpace(fishRoot.Position) - planned:PointToObjectSpace(want.Position)).Magnitude
			else 0
		e.low, e.high, e.right, e.left = trip.Escort.Low, trip.Escort.High, trip.Escort.Right, trip.Escort.Left
		ox, oy, oz = o.X, o.Y, o.Z
		on, sx = screen(workspace.CurrentCamera, fishRoot.Position)
		seen = fishRoot.LocalTransparencyModifier
		local pickupAt, rideAt, arriveAt, dropAt = SubTrip.times(trip)
		local a, b = SubTrip.escortTimes(trip, trip.Escort.Half)
		local low, high = trip.Escort.Low, trip.Escort.High
		if t >= pickupAt and t < rideAt then moment = "Hop"
		elseif t >= a and t <= b then moment = if o.X < low + 0.15 * (high - low) then "Left"
				elseif o.X > high - 0.15 * (high - low) then "Right"
				else "None"
		elseif t > b and t < dropAt then moment = "Return"
		elseif t >= dropAt then moment = "Kick" end
		if t >= pickupAt and t <= dropAt + 0.3 then
			local op = OverlapParams.new()
			op.FilterType = Enum.RaycastFilterType.Exclude
			op.FilterDescendantsInstances = skipList(nil, mine)
			for _, p in workspace:GetPartBoundsInBox(fishRoot.CFrame, trip.Escort.Half * 1.6, op) do
				if p.Transparency < 0.98 and p.CanCollide then
					local name = p:GetFullName()
					e.touched[name] = (e.touched[name] or 0) + 1
				end
			end
		end
	end
	escGui.BackgroundColor3 = rgb(MOMENTS[moment])
	table.insert(e.rows, { math.floor(t * 1000) / 1000, n, landN, math.floor(err * 100) / 100, math.floor(ox * 10) / 10, math.floor(oy * 10) / 10,
		math.floor(oz * 10) / 10, on, math.floor(sx * 1000) / 1000, seen, tostring(State.Mode), if mine and r.fish == mine then 1 else 0 })
end
RunService:BindToRenderStep("ZZFishSub", Enum.RenderPriority.Last.Value + 1, function()
	local ok, why = pcall(escStep)
	if not ok and escRec then escRec.error = tostring(why) end
end)
'''


def patch(text, before, add, what):
    assert text.count(before) == 1, "sub_camera_check.py has changed: no single place for %s" % what
    return text.replace(before, add + before)


moments = "{ " + ", ".join("%s = { %d, %d, %d }" % (k, *v) for k, v in MOMENTS.items()) + " }"
sc.SERVER = patch(sc.SERVER, '\t\telseif verb == "home" then', SERVER_VERBS.lstrip("\n"), "the server's verbs")
sc.CLIENT = patch(sc.CLIENT, '\t\telseif verb == "state" then', CLIENT_VERBS.lstrip("\n"), "the client's verbs")
sc.CLIENT = patch(sc.CLIENT, "local function v3(v)", CLIENT_STEP.replace("__MOMENTS__", moments), "the fish's step")
# (the stand at the lip is a jump the server's pace check puts a mounted body back from: off the fish, stood, on again)
sc.CLIENT = patch(sc.CLIENT, "\t\t\tcontrols(false)\n\t\t\thumanoid:Move(Vector3.zero)\n\t\t\tcharacter:PivotTo", """			local wasOn = player:GetAttribute("LandMounted") == true
			local function ride(on)
				if (player:GetAttribute("LandMounted") == true) ~= on then
					task.wait(0.3)
					Net.Action:FireServer("RideMount")
					local till = os.clock() + 4
					while os.clock() < till and (player:GetAttribute("LandMounted") == true) ~= on do task.wait() end
				end
			end
			ride(false)
""", "off the fish before the stand")
sc.CLIENT = patch(sc.CLIENT, "\t\t\tif rec then\n\t\t\t\trec.lip = lipAt", "\t\t\tif wasOn then ride(true) task.wait(1) end\n", "on it again at the lip")
sc.CLIENT = patch(sc.CLIENT, "local rec = nil -- the trip being written down", "local escRec, unequipAt = nil, nil\n", "the fish's record")


def hands():
    said = sc.cmd("hands", 0.5)
    out = {}
    for word in said.split():
        if "=" in word:
            k, v = word.split("=", 1)
            out[k] = v
    return out, said


def go(tier, land, fish, size, label, side=0, arm=None):
    """the fish given and mounted, the record begun, the player walked off the lip (`side` studs right of its middle);
    True once the trip has begun. `arm`: run just before the walk"""
    for _ in range(2):
        said = sc.cmd(f"ride|{tier},{land},{fish or '-'},{size}", 2.5)
        if not fish or "on=true" in said:
            break
        time.sleep(2)
    sc.note(f"[{label}] tier {tier} to land {land}, {fish or 'no fish'} {size}: {said}")
    sc.do(f"rec|{label}", 0.4)
    if arm:
        sc.note("  " + arm())
    said = sc.do(f"walk|12|{side}", 2.0)  # (its answer comes as the trip begins: the stand, the walk and the leap first)
    end = time.time() + 16
    while not said.startswith("walked") and time.time() < end:
        time.sleep(0.2)
        said = sc.s2.server("return game:GetService('ReplicatedStorage'):GetAttribute('SCClient')") or ""
    sc.note("  " + said)
    return "trip=true" in said


def home():
    try:
        said = sc.cmd("home", 3)
    except subprocess.TimeoutExpired:  # (a slow runner call, once in an hour)
        time.sleep(5)
        said = sc.cmd("home", 3)
    time.sleep(1.5)
    return said


def trip(tier, land, fish, size="Normal", label=None, side=0):
    fish = "" if fish == "-" else fish
    ridden = bool(fish) and size != "foot"
    label = label or f"{tier}-{land}-{fish or 'none'}-{size}" + (f"-{side}" if side else "")
    if not go(tier, land, fish, size, label, side):
        sc.note("  ! no trip began")
        home()
        sc.save_log()
        return False
    before, _ = hands()
    end = time.time() + 45
    while time.time() < end and "done=true" not in sc.do("state", 0.2):
        time.sleep(0.4)
    after, said = hands()
    sc.note("  after: " + said)
    sc.do(f"esc|{label}", 1.2)
    esc = json.loads(sc.value(label + ":esc").strip().splitlines()[-1])
    meta, rows = sc.end_trip(label)
    cam = sc.analyse(meta, rows)
    sc.note(cam["text"])
    (sc.OUT / f"{label}-esc.json").write_text(json.dumps(esc))
    results = []

    def ok(what, good, seen=""):
        results.append(bool(good))
        sc.note(f"  {'ok  ' if good else 'FAIL'}  {what}  {seen}")

    times = meta["trip"]["times"]
    R = esc["rows"]  # t, ours in the water, ours on land, error, ox, oy, oz, on screen, sx, faded, mode, cued with it
    ok("the fish of the hands unchanged", before.get("hands") == after.get("hands"), f"{before.get('hands')} {after.get('hands')}")
    if not ridden:
        ok("no fish beside the sub on the way", all(r[1] == 0 for r in R if 0 <= r[0] < times[2] - 1.5))
        ok("cue", meta["cue"] == ("Kick" if fish else "Fling"), meta["cue"])
    else:
        under = [r for r in R if r[0] >= 0]
        found = next((i for i, r in enumerate(under) if r[1] > 0), None)
        ok("the water fish is there", found is not None)
        if found is not None:
            gap = [r for r in under[:found] if r[2] == 0]
            ok("at most 3 frames between the land fish and the water one", len(gap) <= 3, f"{len(gap)} frames with neither")
            carried = [r for r in under[found:] if r[0] < times[3]]
            ok("always one, never none, never two", all(r[1] == 1 for r in carried), str(sorted({r[1] for r in carried})))
            ok("the same model all through", esc["same"], esc.get("kind"))
            ok("the kick was cued with it", any(r[11] for r in R) and meta["cue"] == "Kick", meta["cue"])
            late = [r[3] for r in carried if r[0] > times[0] + 0.2]
            # (in the run, at thousands of studs a second, the millisecond between its placing and this reading is studs on a bend)
            slow = [r[3] for r in carried if times[0] + 0.2 < r[0] < times[1] or times[2] < r[0] < times[3]]
            ok("where the trip has it (0.5 stud; 4 in the run)", slow and max(slow) < 0.5 and max(late) < 4,
               f"most {max(slow or [0]):.2f}, in the run {max(late or [0]):.2f}")
            # (see-through where the camera is in its body: EscortThin, never all the way; a fade-in is, and is a fish not there)
            gone = [r[0] for r in carried if r[9] > 0.85]
            ok("never faded out", not gone, f"{len(gone)} frames" + (f", {gone[0]} to {gone[-1]} s" if gone else ""))
            weave = [r for r in carried if times[1] + 0.8 < r[0] < times[3] - 1.2]
            seen = sum(r[7] for r in weave) / max(len(weave), 1)
            ok("in the picture nine tenths of the weave", seen >= 0.9, f"{seen:.2f}")
            left, right = min((r[8] for r in weave), default=0.5), max((r[8] for r in weave), default=0.5)
            # (only to a side it has the room to go to: its plan says how far)
            both = (left < 0.47 or esc.get("low", 0) > -8) and (right > 0.53 or esc.get("high", 0) < 8)
            ok("left and right of the middle", both, f"{left:.2f} to {right:.2f} of the view; planned {esc.get('low', 0):.0f} to "
               f"{esc.get('high', 0):.0f} studs, beside it left {esc.get('left')} right {esc.get('right')}")
        touched = sorted(esc["touched"].items(), key=lambda kv: -kv[1])[:6] if esc["touched"] else []
        sc.note("  map in the fish's box (frames, part): " + (", ".join(f"{n} {p}" for p, n in touched) or "none"))
    if ridden:
        # (put on the fish, not thrown with it: task v1, up to 4,700 studs a second)
        tail = [f for f in sc.parse(rows) if times[4] <= f["t"] < times[4] + 0.6]
        fast = max((sum((p - q) ** 2 for p, q in zip(n["rider"], m["rider"])) ** 0.5 / max(n["t"] - m["t"], 0.004)
                    for m, n in zip(tail, tail[1:])), default=0)
        ok("not thrown off the kick's end (400 studs/s)", tail and fast < 400, f"{fast:.0f}")
    if esc.get("error"):
        ok("no errors in the readings", False, esc["error"])
    ok("the camera's limits (sub_camera_check)", cam["pass"])
    sc.save_log()
    return all(results)


def giveup(how, seconds, tier=9, land=5, fish="GreatWhite"):
    label = f"giveup-{how}-{seconds}"
    # (armed before the walk and given up by the trip's own clock: the walk's answer comes back seconds into it)
    if how == "unequip":
        arm = lambda: sc.do(f"unequip|{seconds}", 0.3)  # noqa: E731
    else:
        arm = lambda: sc.cmd(f"giveat|{how},{seconds}", 0.3)  # noqa: E731
    if not go(tier, land, fish, "Normal", label, 0, arm):
        sc.note("  ! no trip seen by the walk's end (a death or a reset that early ends it: read on)")
    time.sleep(float(seconds) + 1.2)
    mid, said = hands()
    sc.note(f"  after it: {said}")
    gave = sc.value("gave") if how == "unequip" else sc.cmd("gave", 0.3)
    sc.note(f"  given up: {gave}")
    time.sleep(10)
    last, said = hands()
    sc.note("  at the end: " + said)
    # (a death is tidied as the new body comes, 5 s later: not looked at in between)
    gone = last if how == "die" else mid
    good = " at " in str(gave) and gone.get("fish") == "0" and last.get("parked") == "0" and last.get("hands") == "1"
    good = good and last.get("trip") == "false"
    sc.note(f"  {'ok  ' if good else 'FAIL'}  the copy gone, the hands' one fish still there, the trip over")
    home()
    sc.save_log()
    return good


def moment_of(im):
    """the moment, from the second strip in a picture of the window"""
    x0, y0, _, _, scale = json.loads(sc.VIEW_FILE.read_text())
    a = im.load()[round(x0 + 60 * scale), round(y0 + 17 * scale)]
    for name, colour in MOMENTS.items():
        if name != "None" and sc.near(a, colour, 45):
            return name
    return None


def stills(tier, land, fish, size, tries=10):
    want = set(MOMENTS) - {"None"}
    kept = {}
    for attempt in range(tries):
        label = f"stills-{attempt}"
        sc.cmd(f"ride|{tier},{land},{fish},{size}", 2.5)
        sc.do(f"rec|{label}", 0.4)
        sc.fire("walk|12|0")
        time.sleep(1.0 + 0.35 * attempt)  # (a grab takes 3 s and more: each trip begins them a little later)
        end = time.time() + 16
        n = 0
        while time.time() < end and want - set(kept):
            n += 1
            full = sc.raw(f"{label}-{n}")
            im = Image.open(full).convert("RGB")
            moment = moment_of(im)
            if moment and moment not in kept:
                x0, y0, x1, y1, scale = json.loads(sc.VIEW_FILE.read_text())
                out = sc.ATTACH / f"fishsub-{fish.lower()}-{size.lower()}-{moment.lower()}.jpg"
                im.crop((x0, y0 + round(23 * scale), x1, y1)).save(out, quality=90)
                kept[moment] = out
                sc.note(f"still: {out}")
            full.unlink(missing_ok=True)
            if "done=true" in sc.do("state", 0.2):
                break
        home()
        if not want - set(kept):
            break
    sc.note("stills kept: " + ", ".join(sorted(kept)) + "; missing: " + (", ".join(sorted(want - set(kept))) or "none"))
    sc.save_log()
    return kept


def everything():
    got = []
    for tier, land, fish, size in TRIPS:
        got.append((f"{fish} {size} {tier}>{land}", trip(tier, land, fish, size)))
    for side in (-28, 28):
        got.append((f"GreatWhite 6>7 from {side} along the lip", trip(6, 7, "GreatWhite", "Normal", None, side)))
    got.append(("no fish", trip(4, 5, "-", "Normal")))
    got.append(("on foot", trip(4, 5, "GreatWhite", "foot")))
    for how in ("unequip", "die", "reset"):
        for at in (1.5, 4):
            got.append((f"{how} at {at}", giveup(how, at)))
    for what, good in got:
        sc.note(f"{'PASS' if good else 'FAIL'}  {what}")
    sc.note(f"{sum(g for _, g in got)} of {len(got)} passed")
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
    elif what == "trip":
        size = rest[3] if len(rest) > 3 else "Normal"
        fish = rest[2] if len(rest) > 2 else "-"
        sys.exit(0 if trip(int(rest[0]), int(rest[1]), fish, size, rest[4] if len(rest) > 4 else None) else 1)
    elif what == "giveup":
        sys.exit(0 if giveup(rest[0], float(rest[1])) else 1)
    elif what == "stills":
        stills(int(rest[0]), int(rest[1]), rest[2], rest[3], int(rest[4]) if len(rest) > 4 else 10)
    elif what == "all":
        sys.exit(0 if everything() else 1)
