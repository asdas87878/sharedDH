"""Loads the map into the open Studio place: runs every file of tools/studio/greybox in number order through
run_luau.js (00_start, the parts files, 98_water, 99_check), and reads the check twice. Then the seahorse trainer
(tools/studio/trainer_models.py): Hugo's 12 levels are checked and put into the place if they or their mesh files
are missing, and level 1 is shown on every plot in Edit (the map's kit draws no trainer).

It waits instead of failing when Studio isn't in Edit mode: pressing Play half way through a load used to leave the
place with half a map (the files that ran while playing were refused and skipped). Now a refused file is tried again
every ten seconds until Studio is back in Edit mode.

usage: python tools/studio/load_greybox.py <studio_id> [greybox_bench] [hub]
  hub: only the hub's models (the *_hub.luau files: seconds, and what was moved or deleted by hand stays), then the
       trainer and the hub's contract (tools/studio/hub_contract.luau). For a change to tools/map/hub_kit.py."""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
studio = sys.argv[1]
HUB_ONLY = "hub" in sys.argv[2:]
NAMED = [a for a in sys.argv[2:] if a != "hub"]
FOLDER = os.path.join(ROOT, "tools", "studio", NAMED[0] if NAMED else "greybox")  # greybox_bench: the bench
WAIT = ("not available in Play mode", "Target is not reachable", "ENOENT", "ECONNREFUSED")


def run(path, whole=False):
    """the last line a file's run prints (`whole`: all of it); tried again while Studio is playing or out of reach"""
    for attempt in range(360):  # up to an hour
        out = subprocess.run(["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path], capture_output=True, text=True, cwd=ROOT)
        text = (out.stdout + out.stderr).strip()
        last = text.splitlines()[-1] if text else ""
        if not any(w in text for w in WAIT):
            return text if whole else last
        if attempt == 0:
            print("  waiting for Studio's Edit mode:", os.path.basename(path), "|", last[:100], flush=True)
        time.sleep(10)
    return "gave up: " + last


def trainer():
    """the seahorse trainer, after the plots are built: Hugo's 12 levels in the place and on this PC, level 1 shown in
    Edit. It says loudly what it could not do; the map itself is loaded either way"""
    done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio", "trainer_models.py"), studio], cwd=ROOT)
    if done.returncode != 0:
        print("TRAINER: NOT WHOLE (see above): python tools/studio/trainer_models.py", studio, flush=True)


def order(name):
    """the start first, the parts files in number order, then the water, then the check (a parts file can carry the
    same number as the water's or the check's file)"""
    kind = 0 if name.endswith("_start.luau") else 1 if name.endswith("_parts.luau") else 3 if name.endswith("_check.luau") else 2
    return kind, int(re.match(r"(\d+)", name).group(1))


files = sorted((f for f in os.listdir(FOLDER) if f.endswith(".luau")), key=order)
if HUB_ONLY:
    files = [f for f in files if f.endswith("_hub.luau")]
    for name in files:
        print("HUB:", run(os.path.join(FOLDER, name)), flush=True)
    trainer()
    print("CONTRACT:", run(os.path.join(ROOT, "tools", "studio", "hub_contract.luau"), whole=True), flush=True)
    raise SystemExit(0)
problems = 0
for k, name in enumerate(files):
    last = run(os.path.join(FOLDER, name))
    if name.endswith("_start.luau"):
        print("START:", last, flush=True)
        if "started" not in last:
            raise SystemExit("the start file did not run: nothing loaded")
    elif name.endswith("_water.luau"):
        print("WATER:", last, flush=True)
    elif name.endswith("_check.luau"):
        print("CHECK:", last, flush=True)
    elif name.endswith("_hub.luau"):
        print("HUB:", last, flush=True)
    elif "parts made" not in last:
        problems += 1
        print("PROBLEM", name, last, flush=True)
    if k % 20 == 19:
        print(f"  {k + 1} of {len(files)} files", flush=True)
print("ran", len(files), "files,", problems, "problems")
time.sleep(20)
print("CHECK AGAIN:", run(os.path.join(FOLDER, "99_check.luau")), flush=True)
if any(f.endswith("_hub.luau") for f in files):
    trainer()  # (after the check: the level-1 seahorses it shows are parts too, about 60 a plot)
    if FOLDER.endswith("greybox"):  # what the user moved by hand, which the load has just wiped
        print("HAND:", subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio", "hand_map.py"), studio], capture_output=True, text=True, cwd=ROOT).stdout.strip(), flush=True)
