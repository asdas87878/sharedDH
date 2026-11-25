"""Everything the user's place has, put into this PC's open place (made for Hugo's own place file, 2026-11-25).

Git carries the code and the files the models are made from; the models themselves live in the place, so a pull alone
does not bring them. In order: the code (sync_src), the 12 seahorses, the 87 creatures, the 9 subs (as mesh files on this
PC, nothing uploaded), the user's hand changes to the map (hand_map.py), then a count of what the place holds.

usage: python tools/studio/catch_up.py runner      (Studio open on the place, in Edit; from the repo's root; then Ctrl+S)
       ... --check     only the count
Not for the shared live place: it would put this PC's files over the uploaded models, so it stops there."""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OWNER = 165352993  # whose account owns the live game and its uploads

COUNT = r"""
local rs = game:GetService("ReplicatedStorage")
local function n(name: string): number
	local f = rs:FindFirstChild(name)
	return if f then #f:GetChildren() else 0
end
local uploaded, localOnes = 0, 0
for _, name in { "FishModels", "TrainerModels", "SubMeshes" } do
	local f = rs:FindFirstChild(name)
	for _, d in if f then f:GetDescendants() else {} do
		if d:IsA("MeshPart") then
			if d.MeshId:find("rbxasset://", 1, true) then localOnes += 1 else uploaded += 1 end
		end
	end
end
local map = workspace:FindFirstChild("ClaudeBlockout")
return `CATCHUP owner={game.CreatorId} place={game.PlaceId} creatures={n("FishModels")} seahorses={n("TrainerModels")} subs={n("SubMeshes")} skies={n("Skies")} map={if map then #map:GetDescendants() else 0} farview={workspace:FindFirstChild("FarView") ~= nil} streaming={workspace.StreamingEnabled} meshes: local {localOnes}, uploaded {uploaded} ;END`
"""


def luau(studio, code):
    path = os.path.join(tempfile.gettempdir(), "catch_up.luau")
    open(path, "w", encoding="utf-8", newline="\n").write(code)
    out = subprocess.run(["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT, timeout=300)
    return out.stdout + out.stderr


def count(studio):
    text = luau(studio, COUNT)
    at = text.rfind("CATCHUP")
    if at < 0:
        print("Studio did not answer (is the place open, in Edit?):", text[-300:])
        return None
    return text[at + 8:text.find(";END", at)].strip()


def main():
    args = sys.argv[1:]
    studio = next((a for a in args if not a.startswith("--")), "runner")
    now = count(studio)
    print("before:", now, flush=True)
    if now is None or "--check" in args:
        return 0 if now else 1
    owner = int(re.search(r"owner=(\d+)", now).group(1))
    if owner == OWNER:
        print("this is the live game's own place: its models are the uploaded ones already. Stopped, nothing changed.")
        return 1
    py = sys.executable
    steps = [
        ("code", [py, "tools/studio/sync_src.py", studio]),
        ("seahorses", [py, "art/creatures/Seahorse/tiers/install_tiers.py", studio]),
        ("creatures", [py, "tools/creatures/install.py", studio, "--local"]),
        ("subs", [py, "tools/subs/install.py", studio]),
        ("seahorses on the plots", [py, "tools/studio/trainer_models.py", studio]),
        ("hand changes", [py, "tools/studio/hand_map.py", studio]),
        ("aura pictures (Studio's own copies; reopen Studio after)", [py, "tools/auras/volume_sheets.py", "--local"]),
    ]
    bad = []
    for name, command in steps:
        out = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT)
        lines = (out.stdout + out.stderr).strip().splitlines()
        print(f"--- {name}: {'done' if out.returncode == 0 else 'FAILED'}", *lines[-3:], sep="\n", flush=True)
        if out.returncode != 0:
            bad.append(name)
    print("after:", count(studio))
    print("the user's place: creatures=88 seahorses=12 subs=9 skies=1 or more (88: one unused leftover, 87 is whole)")
    print("FAILED: " + ", ".join(bad) if bad else "all in: SAVE THE PLACE (Ctrl+S), then look at a plot's seahorse in Play")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
