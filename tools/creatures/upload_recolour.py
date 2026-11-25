"""Uploads creatures again after a recolour (2026-11-19: the creature chat recoloured 29 fish so they sit in their
lands, docs/design/fish-recolour-list.md; the user: "upload the new model colours in any which way you can").
UPLOADS ARE PERMANENT. The same upload as tools/creatures/upload.py (a Model asset from each GLB, through Studio's
connector), for the Ids given, whether or not they were uploaded before. Each new id goes into assets.json; the old one
is kept in assets_before_recolour.json; each upload is logged in recolour_log.json, so a run that stops carries on.

usage: python tools/creatures/upload_recolour.py <studio_id> Id,Id,... [--dry] [--batch add_2026-11-25]
  --batch <name>: another round, for new creatures or remodels: logged in <name>_log.json, the replaced ids kept in
  assets_before_<name>.json (without it: the recolour's own files above).
Then: python tools/creatures/install.py <studio_id> Id ..."""
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.join(ROOT, "tools", "creatures")
CLIENT = r"C:\Users\blast\RpgGame\tools\studio\studio_mcp.py"
USER_ID = "165352993"
SCOPES = ["asset:read", "asset:write"]


def load(name, default):
    path = os.path.join(HERE, name)
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else default


def save(name, data):
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")


def invoke(studio, args, timeout=180):
    args = dict(args, studio_id=studio)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(args, f)
        path = f.name
    try:
        out = subprocess.run([sys.executable, CLIENT, "call", "open_cloud_invoke", "@" + path, str(timeout)],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout + 30).stdout
    finally:
        os.unlink(path)
    line = next((l for l in out.splitlines() if l.startswith('{"content"')), None)
    if not line:
        raise RuntimeError("no reply from Studio: " + out[-400:])
    text = json.loads(line)["content"][0]["text"]
    head, _, body = text.partition("\n\n")
    code = 0
    if "->" in head:
        try:
            code = int(head.split("->")[1].split()[0])
        except ValueError:
            code = 0
    try:
        return code, json.loads(body)
    except ValueError:
        return code, text


def main():
    studio, ids = sys.argv[1], sys.argv[2].split(",")
    dry = "--dry" in sys.argv
    batch = sys.argv[sys.argv.index("--batch") + 1] if "--batch" in sys.argv else ""
    log_file = (batch + "_log.json") if batch else "recolour_log.json"
    before_file = ("assets_before_" + batch + ".json") if batch else "assets_before_recolour.json"
    what = ("voxel, " + batch) if batch else "voxel, recoloured 2026-11-19"
    assets, before, log = load("assets.json", {}), load(before_file, {}), load(log_file, {})
    todo = [i for i in ids if i not in log]
    print(len(todo), "to upload;", len(ids) - len(todo), "already done")
    failed = []
    for n, cid in enumerate(todo, 1):
        path = os.path.join(ROOT, "art", "creatures", cid, "game", cid + ".glb")
        if not os.path.exists(path):
            print("  %s: NO FILE" % cid)
            failed.append(cid)
            continue
        if dry:
            print("  would upload %s (%d KB)" % (cid, os.path.getsize(path) // 1024))
            continue
        request = {"assetType": "Model", "displayName": "RideAFish " + cid, "description": "Ride a Fish creature: " + cid + " (" + what + ")",
                   "creationContext": {"creator": {"userId": USER_ID}}}
        try:
            code, body = invoke(studio, {"method": "POST", "endpoint": "/assets/v1/assets", "body": json.dumps({"request": request}),
                                         "files": [{"name": "fileContent", "path": path}], "scopes": SCOPES})
            if code != 200 or not isinstance(body, dict) or "path" not in body:
                raise RuntimeError("upload refused (%s): %s" % (code, str(body)[:300]))
            operation = body.get("operationId") or body["path"].split("/")[-1]
            asset_id = None
            for _ in range(40):
                if body.get("done") and isinstance(body.get("response"), dict):
                    asset_id = body["response"].get("assetId")
                    break
                if body.get("done") and body.get("error"):
                    raise RuntimeError("Roblox refused it: %s" % json.dumps(body["error"])[:200])
                time.sleep(3)
                code, body = invoke(studio, {"method": "GET", "endpoint": "/assets/v1/operations/" + operation, "scopes": ["asset:read"]})
                if not isinstance(body, dict):
                    body = {}
            if not asset_id:
                raise RuntimeError("the upload's operation %s did not finish" % operation)
        except Exception as error:  # noqa: BLE001
            print("  %s: FAILED: %s" % (cid, error))
            failed.append(cid)
            continue
        if cid in assets and cid not in before:
            before[cid] = assets[cid]
            save(before_file, before)
        assets[cid] = int(asset_id)
        save("assets.json", assets)
        log[cid] = {"asset": int(asset_id), "operation": operation, "at": time.strftime("%Y-%m-%d %H:%M:%S"), "bytes": os.path.getsize(path)}
        save(log_file, log)
        print("  %d/%d %s -> %s" % (n, len(todo), cid, asset_id), flush=True)
        time.sleep(1)
    print("done;", len(failed), "failed:", ", ".join(failed))
    sys.exit(1 if failed else 0)


main()
