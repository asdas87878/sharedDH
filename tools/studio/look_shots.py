"""Runs a list of steps in the open Studio place (Edit mode) through one connection, saving each screen capture as a
file: for before-and-after pictures of a look from fixed spots, without a chat turn per picture.
usage: python tools/studio/look_shots.py <studio_id> <plan.json> [out folder, default work/look]
The plan is a list of steps, each one of:
  {"luau": "<code>"}                      run it in Edit mode (its result is printed)
  {"file": "<path.luau>"}                 the same, from a file
  {"wait": seconds}
  {"shot": "<name>", "cam": [x, y, z], "at": [x, y, z]}    save <out>/<name>.jpg
Only the chat that has Studio (docs/Sessions.md). One capture at a time: two at once time out.
"""
import base64
import json
import os
import queue
import subprocess
import sys
import threading
import time

EXE = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\mcp.bat")
VERSION = os.environ.get("MCP_VERSION", "2026-07-28")

studio, plan_path = sys.argv[1], sys.argv[2]
out_dir = sys.argv[3] if len(sys.argv) > 3 else "work/look"
os.makedirs(out_dir, exist_ok=True)
plan = json.load(open(plan_path, encoding="utf-8"))

proc = subprocess.Popen(["cmd.exe", "/c", EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        text=True, encoding="utf-8", bufsize=1)
lines = queue.Queue()
threading.Thread(target=lambda: [lines.put(ln) for ln in proc.stdout], daemon=True).start()
threading.Thread(target=lambda: [None for _ in proc.stderr], daemon=True).start()
serial = [0]


def request(method, params, timeout=120):
    serial[0] += 1
    i = serial[0]
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": i, "method": method, "params": params}) + "\n")
    proc.stdin.flush()
    end = time.time() + timeout
    while time.time() < end:
        try:
            line = lines.get(timeout=max(0.1, end - time.time()))
        except queue.Empty:
            break
        try:
            m = json.loads(line)
        except ValueError:
            continue
        if m.get("id") == i:
            return m
    raise TimeoutError(method)


def call(tool, args, timeout=120):
    for _ in range(8):
        r = request("tools/call", {"name": tool, "arguments": args}, timeout)
        if "No Roblox Studio instances" not in json.dumps(r)[:400]:
            return r.get("result", r)
        time.sleep(2)
    return r.get("result", r)


def text_of(res):
    return " ".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")[:600]


try:
    request("initialize", {"protocolVersion": VERSION, "capabilities": {}, "clientInfo": {"name": "look-shots", "version": "1"}}, 30)
    proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
    proc.stdin.flush()
    time.sleep(4)
    for n, step in enumerate(plan):
        if "wait" in step:
            time.sleep(step["wait"])
        elif "luau" in step or "file" in step:
            code = step.get("luau") or open(step["file"], encoding="utf-8").read()
            res = call("execute_luau", {"studio_id": studio, "datamodel_type": step.get("model", "Edit"), "code": code}, step.get("timeout", 120))
            print("luau:", text_of(res), flush=True)
            if res.get("isError"):
                sys.exit("stopped at step %d: a Luau step failed" % n)
        elif "shot" in step:
            res = call("screen_capture", {"studio_id": studio, "capture_id": step["shot"], "camera_position": step["cam"],
                                          "look_at_position": step["at"]}, 180)
            saved = False
            for c in res.get("content", []):
                if c.get("type") == "image":
                    ext = c.get("mimeType", "image/jpeg").split("/")[-1].replace("jpeg", "jpg")
                    path = os.path.join(out_dir, step["shot"] + "." + ext)
                    open(path, "wb").write(base64.b64decode(c["data"]))
                    print("shot:", path, flush=True)
                    saved = True
            if not saved:
                sys.exit("stopped at step %d: no picture came back: %s" % (n, text_of(res)))
finally:
    proc.terminate()
