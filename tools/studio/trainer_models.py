"""The seahorse trainer in a place: checks that Hugo's 12 levels are there, puts in what is missing, and shows level 1
on every plot in Edit (docs/design/trainer.md).

Why: the 12 seahorses are not in the repo's map. They are ReplicatedStorage.TrainerModels.T1..T12 in the place, and
their meshes are local files in Studio's content folder (rbxasset://ridefish/Trainer<n>/), one set per PC and per
Studio version. A place without them showed the kit's old toy at every level and said nothing (2026-11-23). So this
runs at the end of every map load (tools/studio/load_greybox.py) and by itself:

usage: python tools/studio/trainer_models.py [runner|<studio_id>] [--check] [--no-preview]
  no flag       check; install what is missing (art/creatures/Seahorse/tiers/install_tiers.py: the 12 models when
                the place lacks any, only the mesh files when only files are missing); show level 1 in Edit
  --check       only say what is missing (exit code 1 when something is); installs and shows nothing
  --no-preview  don't touch the plots
Studio must be open on the place, in Edit (it waits while a playtest runs). `runner` is Hugo's PC (studio-runner);
a studio id is the Studio connector's. After an install, save the place (Ctrl+S): the models are in the place file.

The content folder is the running Studio's own (Windows, macOS, Linux under Vinegar), else the newest installed
version's. If it guesses wrong, name it: STUDIO_CONTENT=<...\\Versions\\version-xxxx\\content>. It prints the one it uses.
After Studio updates itself the files are gone from the new version's folder: run this again.
Nothing is uploaded to Roblox: a published game needs real asset ids (Hugo's word first)."""
import glob
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
TIERS = os.path.join(ROOT, "art", "creatures", "Seahorse", "tiers")
WAIT = ("not available in Play mode", "Target is not reachable", "ENOENT", "ECONNREFUSED")
MARK = "TRAINERCHECK "
LEVELS = 12  # Config.Train.Levels

PLACE = r"""
local folder = game:GetService("ReplicatedStorage"):FindFirstChild("TrainerModels")
local have, ids = {}, {}
for n = 1, __LEVELS__ do
	local m = folder and folder:FindFirstChild("T" .. n)
	if m and m:IsA("Model") and m:FindFirstChild("Toy") and m:FindFirstChild("Stand") then
		table.insert(have, n)
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") then
				table.insert(ids, d.MeshId)
			end
		end
	end
end
-- (no quotes or brackets in it: it is read back the same however the connector wraps what a script returns)
return "__MARK__have=" .. table.concat(have, ",") .. ";ids=" .. table.concat(ids, "|") .. ";END"
"""


def studio_exe(system=sys.platform):
    """the running Studio's program file, or None"""
    try:
        if system == "win32":
            ask = "(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -First 1).Path"
            out = subprocess.run(["powershell", "-NoProfile", "-Command", ask], capture_output=True, text=True, timeout=30).stdout
            for line in out.splitlines():
                if line.strip().lower().endswith("robloxstudiobeta.exe"):
                    return line.strip()
            return None
        out = subprocess.run(["ps", "-axo", "args"] if system == "darwin" else ["ps", "-eo", "args"], capture_output=True, text=True, timeout=30).stdout
        for line in out.splitlines():
            if system == "darwin":
                at = line.find("RobloxStudio.app/Contents/MacOS/")
                if at >= 0:
                    return line[: at + len("RobloxStudio.app")]
            else:
                first = line.split(" ")[0]
                if first.endswith("/RobloxStudioBeta.exe"):
                    return first
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def content_of(exe, system=sys.platform):
    """a Studio program's content folder (on macOS `exe` is the .app)"""
    folder = os.path.join(exe, "Contents", "Resources", "content") if system == "darwin" else os.path.join(os.path.dirname(exe), "content")
    return folder if os.path.isdir(folder) else None


def installed(system=sys.platform):
    """every installed Studio's content folder, the newest first"""
    home = os.path.expanduser("~")
    if system == "win32":
        roots = [os.path.join(os.environ.get("LOCALAPPDATA", os.path.join(home, "AppData", "Local")), "Roblox", "Versions"),
                 os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "Roblox", "Versions")]
        found = [os.path.dirname(exe) for r in roots for exe in glob.glob(os.path.join(r, "*", "RobloxStudioBeta.exe"))]
    elif system == "darwin":
        found = [os.path.join(a, "Contents", "Resources") for a in ("/Applications/RobloxStudio.app", os.path.join(home, "Applications", "RobloxStudio.app"))]
    else:
        found = [os.path.dirname(c) for pattern in ("~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/*/content", "~/.local/share/vinegar/versions/*/content")
                 for c in glob.glob(os.path.expanduser(pattern))]
    folders = [os.path.join(f, "content") for f in found if os.path.isdir(os.path.join(f, "content"))]
    return sorted(folders, key=os.path.getmtime, reverse=True)


def studio_content():
    """(the content folder, how it was found) or (None, why not)"""
    named = os.environ.get("STUDIO_CONTENT")
    if named:
        return (named, "STUDIO_CONTENT") if os.path.isdir(named) else (None, f"STUDIO_CONTENT names a folder that is not there: {named}")
    exe = studio_exe()
    folder = content_of(exe) if exe else None
    if folder:
        return folder, "the running Studio's"
    folders = installed()
    if not folders:
        return None, "no Roblox Studio found on this machine"
    how = "the only installed Studio's" if len(folders) == 1 else f"the newest of {len(folders)} installed Studios' (a guess: Studio is not running)"
    return folders[0], how


def run(studio, path, tries=360):
    """a Luau file's output in the open place (Edit); tried again every ten seconds while Studio plays or is out of reach"""
    text = ""
    for attempt in range(tries):
        out = subprocess.run(["node", os.path.join(HERE, "run_luau.js"), studio, path], capture_output=True, text=True, cwd=ROOT)
        text = (out.stdout + out.stderr).strip()
        if not any(w in text for w in WAIT):
            return text
        if attempt == 0:
            print("  waiting for Studio's Edit mode:", (text.splitlines() or [""])[-1][:100], flush=True)
        time.sleep(10)
    return "gave up: " + text


def place(studio, tries=360):
    """what the open place has: {have: [levels], ids: [mesh ids]}, or None when Studio could not be asked"""
    path = os.path.join(tempfile.gettempdir(), "trainer_models_check.luau")
    open(path, "w", encoding="utf-8").write(PLACE.replace("__LEVELS__", str(LEVELS)).replace("__MARK__", MARK))
    text = run(studio, path, tries)
    at = text.rfind(MARK)
    if at < 0:
        print("  Studio did not answer the check:", text[-300:], flush=True)
        return None
    raw = text[at + len(MARK):]
    end = raw.find(";END")
    if not raw.startswith("have=") or ";ids=" not in raw or end < 0:
        print("  the check's answer could not be read:", raw[:200], flush=True)
        return None
    have, ids = raw[len("have="):end].split(";ids=", 1)
    return {"have": [int(v) for v in have.split(",") if v.strip().isdigit()], "ids": [v for v in ids.split("|") if v]}


def lost_files(ids, content):
    """the place's local mesh ids (rbxasset://...) whose file is not in the content folder"""
    lost = []
    for mesh in sorted(set(ids)):
        if mesh.startswith("rbxasset://") and not os.path.isfile(os.path.join(content, *mesh[len("rbxasset://"):].split("/"))):
            lost.append(mesh)
    return lost


def state(studio, content, tries=360):
    """(levels the place lacks, mesh files this PC lacks) or None when Studio could not be asked"""
    got = place(studio, tries)
    if got is None:
        return None
    have = set(got.get("have") or [])
    return [n for n in range(1, LEVELS + 1) if n not in have], (lost_files(got.get("ids") or [], content) if content else [])


def loud(lines):
    bar = "!" * 100
    print("\n".join([bar, "!!! THE SEAHORSE TRAINER IS NOT WHOLE IN THIS PLACE"] + ["!!! " + line for line in lines] + [bar]), flush=True)


def main():
    args = sys.argv[1:]
    studio = args[0] if args and not args[0].startswith("--") else "runner"
    check_only, preview = "--check" in args, "--no-preview" not in args
    tries = 1 if check_only else 360
    content, how = studio_content()
    print("Studio's content folder:", f"{content} ({how})" if content else f"NOT FOUND ({how})", flush=True)
    fix = f"python tools/studio/trainer_models.py {studio}"
    named = 'set STUDIO_CONTENT to the "content" folder next to the running RobloxStudioBeta.exe, then: ' + fix
    now = state(studio, content, tries)
    if now is None:
        loud(["Studio could not be asked (is the place open, in Edit?). Then: " + fix])
        return 1
    levels, files = now
    if not content:
        # (never "all there" on a look that could not be made: the files are what goes missing on another PC)
        loud([f"Studio's content folder was not found ({how}), so the mesh files could not be checked"
              + (f"; the place also lacks {len(levels)} of the {LEVELS} level models." if levels else "; the place has all the level models."), named])
        return 1
    installed_now = False
    if levels or files:
        print(f"missing: {len(levels)} of the {LEVELS} level models" + (f" (T{', T'.join(map(str, levels))})" if levels else "")
              + f", {len(files)} mesh files" + (f" (the first: {files[0]})" if files else ""), flush=True)
        if check_only:
            loud(["Put them in with: " + fix])
            return 1
        if not os.path.isfile(os.path.join(TIERS, "game", "tiers.json")):
            loud([f"The levels' exports are not in this clone ({os.path.join(TIERS, 'game')}): pull the repo, then: " + fix])
            return 1
        command = [sys.executable, os.path.join(TIERS, "install_tiers.py"), studio] + ([] if levels else ["--files-only"])
        print("installing:", "the 12 models and their mesh files" if levels else "the mesh files only (the place has the models)", flush=True)
        done = subprocess.run(command, cwd=ROOT, env=dict(os.environ, STUDIO_CONTENT=content))
        installed_now = True
        now = state(studio, content)
        levels, files = now if now else (list(range(1, LEVELS + 1)), [])
        if done.returncode != 0 or levels or files:
            loud([f"The install did not finish: {len(levels)} level models and {len(files)} mesh files are still missing.",
                  "If the mesh files went to the wrong Studio version: " + named])
            return 1
    print(f"trainer models: all {LEVELS} levels are in the place and their mesh files are on this PC"
          + (" (just installed: SAVE THE PLACE, Ctrl+S)" if installed_now else ""), flush=True)
    if preview and not check_only:
        text = run(studio, os.path.join(HERE, "trainer_edit.luau"))
        line = next((v for v in reversed(text.splitlines()) if "trainer preview" in v), text[-300:])
        print(line[line.find("trainer preview"):] if "trainer preview" in line else line, flush=True)
        if "NONE" in line or "NOT on" in line or "trainer preview" not in line:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
