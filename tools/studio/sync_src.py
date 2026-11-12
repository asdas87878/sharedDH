"""Puts every .luau file of src/ into the open Studio place (Edit mode), for when the Rojo plugin isn't connected.
The same mapping as default.project.json: src/shared -> ReplicatedStorage.Shared, src/server ->
ServerScriptService.Server, src/client -> StarterPlayer.StarterPlayerScripts.Client. A folder's init.luau is the folder's
own module. Scripts that aren't in the place yet are made (their parent folder must exist, or be an earlier item).
The .json files (the creature data in src/shared/Creatures) go too, each as the module Rojo would make of it. A module
in the place that has no file any more is NOT removed.
usage: python tools/studio/sync_src.py <studio_id>      (run from the repo's root; only the chat that has Studio)
"""
import os
import subprocess
import sys
import tempfile

ROOTS = [
    ("src/shared", "ReplicatedStorage.Shared"),
    ("src/server", "ServerScriptService.Server"),
    ("src/client", "StarterPlayer.StarterPlayerScripts.Client"),
]

studio = sys.argv[1]
pairs = []
for folder, where in ROOTS:
    for base, _dirs, files in os.walk(folder):
        rel = os.path.relpath(base, folder).replace("\\", "/")
        parts = [] if rel == "." else rel.split("/")
        for name in sorted(files):
            if not (name.endswith(".luau") or name.endswith(".json")):
                continue
            stem = name.rsplit(".", 1)[0]
            for suffix in (".server", ".client"):
                if stem.endswith(suffix):
                    stem = stem[: -len(suffix)]
            path = parts if stem == "init" else parts + [stem]
            pairs.append("%s/%s=%s" % (base.replace("\\", "/"), name, ".".join([where] + path)))

here = os.path.dirname(os.path.abspath(__file__))
# in batches: one call with everything is too long for Studio's connector
batches, size = [[]], 0
for pair in pairs:
    weight = os.path.getsize(pair.split("=")[0])
    if batches[-1] and size + weight > 250_000:
        batches.append([])
        size = 0
    batches[-1].append(pair)
    size += weight
code = 0
for n, batch in enumerate(batches, 1):
    out = os.path.join(tempfile.gettempdir(), "ride_a_fish_sync_src_%d.luau" % n)
    subprocess.run([sys.executable, os.path.join(here, "push_scripts.py"), ".", out] + batch, check=True, stdout=subprocess.DEVNULL)
    result = subprocess.run(["node", os.path.join(here, "run_luau.js"), studio, out], capture_output=True, text=True)
    lines = [line for line in (result.stdout + result.stderr).splitlines() if line.strip()]
    last = lines[-1] if lines else "no output"
    ok = result.returncode == 0 and last.startswith(("ReplicatedStorage.", "ServerScriptService.", "StarterPlayer."))
    print("batch %d of %d: %d scripts: %s" % (n, len(batches), len(batch), "in" if ok else "FAILED: " + last[:300]))
    if not ok:
        code = 1
print(len(pairs), "scripts sent")
sys.exit(code)
