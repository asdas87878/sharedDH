"""Uploads creature models to Roblox as Model assets through Studio's connector (Open Cloud), one GLB each.
UPLOADS ARE PERMANENT: run this only on the user's word (given 2026-11-12 for all 82: docs/Decisions.md).

usage: python tools/creatures/upload.py <studio_id> [--only Id,Id] [--dry]
  It reads tools/creatures/import_plan.json (python tools/creatures/plan_import.py writes it): every Id in uploadNew and
  uploadAgain is uploaded from its file in `files`. Each finished upload is written at once to
  tools/creatures/assets.json (an Id uploaded again has its old asset id moved to assets_dark.json), and logged in
  tools/creatures/upload_log.json, so a run that stops can be started again and carries on where it was: an Id already
  in the log is skipped.
  Studio must be open with the Assistant's MCP permissions granting asset:read and asset:write and the folder
  art/creatures approved. Only the chat that has Studio runs this (docs/Sessions.md).
Then: python tools/creatures/collect.py, and python tools/creatures/install.py <studio_id>.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.join(ROOT, "tools", "creatures")
CLIENT = r"C:\Users\blast\RpgGame\tools\studio\studio_mcp.py"
USER_ID = "165352993"  # the creator the assets are made under (the user's Roblox account)
SCOPES = ["asset:read", "asset:write"]


def load(name, default):
    path = os.path.join(HERE, name)
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(name, data):
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")


def invoke(studio, args, timeout=180):
    """One open_cloud_invoke call: returns (status code, body as parsed JSON or text)."""
    args = dict(args, studio_id=studio)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(args, f)
        path = f.name
    try:
        out = subprocess.run(
            [sys.executable, CLIENT, "call", "open_cloud_invoke", "@" + path, str(timeout)],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout + 30,
        ).stdout
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
    args = sys.argv[1:]
    studio = args[0]
    only = None
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(","))
    dry = "--dry" in args

    plan = load("import_plan.json", None)
    if not plan:
        sys.exit("no import_plan.json: run python tools/creatures/plan_import.py")
    assets = load("assets.json", {})
    dark = load("assets_dark.json", {})
    log = load("upload_log.json", {})
    def ids(rows):
        return [row["id"] if isinstance(row, dict) else row for row in rows]

    todo = [(i, False) for i in ids(plan["uploadNew"])] + [(i, True) for i in ids(plan["uploadAgain"])]
    if only:
        todo = [t for t in todo if t[0] in only]
    todo = [t for t in todo if t[0] not in log]
    print(len(todo), "to upload;", len(log), "already in the log")
    failed = []
    for n, (cid, again) in enumerate(todo, 1):
        rel = plan["files"][cid]
        path = os.path.join(ROOT, rel.replace("/", os.sep))
        if not os.path.exists(path):
            print("  %s: NO FILE %s" % (cid, rel))
            failed.append(cid)
            continue
        size = os.path.getsize(path)
        if dry:
            print("  would upload %s (%d KB)%s" % (cid, size // 1024, ", again" if again else ""))
            continue
        request = {
            "assetType": "Model",
            "displayName": "RideAFish " + cid,
            "description": "Ride a Fish creature: " + cid + " (voxel)",
            "creationContext": {"creator": {"userId": USER_ID}},
        }
        try:
            code, body = invoke(studio, {
                "method": "POST",
                "endpoint": "/assets/v1/assets",
                "body": json.dumps({"request": request}),
                "files": [{"name": "fileContent", "path": path}],
                "scopes": SCOPES,
            })
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
                code, body = invoke(studio, {
                    "method": "GET",
                    "endpoint": "/assets/v1/operations/" + operation,
                    "scopes": ["asset:read"],
                })
                if not isinstance(body, dict):
                    body = {}
            if not asset_id:
                raise RuntimeError("the upload's operation %s did not finish" % operation)
        except Exception as error:  # noqa: BLE001 (one creature failing must not stop the rest)
            print("  %s: FAILED: %s" % (cid, error))
            failed.append(cid)
            continue
        if again and cid in assets:
            dark[cid] = assets[cid]
            save("assets_dark.json", dark)
        assets[cid] = int(asset_id)
        save("assets.json", assets)
        log[cid] = {"asset": int(asset_id), "operation": operation, "at": time.strftime("%Y-%m-%d %H:%M:%S"), "bytes": size}
        save("upload_log.json", log)
        print("  %d/%d %s -> %s" % (n, len(todo), cid, asset_id), flush=True)
        time.sleep(1)
    print("done;", len(failed), "failed:", ", ".join(failed))
    sys.exit(1 if failed else 0)


main()
