"""Loads the map into the open Studio place: runs every file of tools/studio/greybox in number order through
run_luau.js (00_start, the parts files, 98_water, 99_check), and reads the check twice.

It waits instead of failing when Studio isn't in Edit mode: pressing Play half way through a load used to leave the
place with half a map (the files that ran while playing were refused and skipped). Now a refused file is tried again
every ten seconds until Studio is back in Edit mode.

usage: python tools/studio/load_greybox.py <studio_id>"""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "tools", "studio", "greybox")
studio = sys.argv[1]
WAIT = ("not available in Play mode", "Target is not reachable", "ENOENT", "ECONNREFUSED")


def run(path):
    """the last line a file's run prints; tried again while Studio is playing or out of reach"""
    for attempt in range(360):  # up to an hour
        out = subprocess.run(["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path], capture_output=True, text=True, cwd=ROOT)
        text = (out.stdout + out.stderr).strip()
        last = text.splitlines()[-1] if text else ""
        if not any(w in text for w in WAIT):
            return last
        if attempt == 0:
            print("  waiting for Studio's Edit mode:", os.path.basename(path), "|", last[:100], flush=True)
        time.sleep(10)
    return "gave up: " + last


def order(name):
    """the start first, the parts files in number order, then the water, then the check (a parts file can carry the
    same number as the water's or the check's file)"""
    kind = 0 if name.endswith("_start.luau") else 1 if name.endswith("_parts.luau") else 2 if name.endswith("_water.luau") else 3
    return kind, int(re.match(r"(\d+)", name).group(1))


files = sorted((f for f in os.listdir(FOLDER) if f.endswith(".luau")), key=order)
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
    elif "parts made" not in last:
        problems += 1
        print("PROBLEM", name, last, flush=True)
    if k % 20 == 19:
        print(f"  {k + 1} of {len(files)} files", flush=True)
print("ran", len(files), "files,", problems, "problems")
time.sleep(20)
print("CHECK AGAIN:", run(os.path.join(FOLDER, "99_check.luau")))
