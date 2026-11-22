"""Draws fish pictures on a test sheet in Studio (Edit mode) with tools/ui/portrait_sheet.luau, each as a caught slot
shows it. Only the chat that has Studio runs it; take the sheet away (`off`) right after the screen capture.
usage: python tools/ui/portrait_sheet.py <studio_id> <all | Name,Name,... | off> [--before] [--tile N]
                                         [--try "Label=<Luau table laid over Portrait.Settings>" ...]
  --before  first a row drawn by the last commit's Portrait (git HEAD), then the repo's
  --try     another row with the repo's Portrait and these numbers, e.g. --try "Tip 20={Poses={Bust={Tip=20}}}"
  --plain --start N --count N   just the pictures on white, for tools/ui/export_portraits.py
Each row is drawn by its own copy of the code sent in with the sheet, so Studio's synced scripts don't matter.
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = os.path.join(ROOT, "tools", "ui", "portrait_sheet.luau")
PORTRAIT = os.path.join(ROOT, "src", "client", "UI", "Portrait.luau")


def quote(text):
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def main():
    args = sys.argv[1:]
    studio, which = args[0], args[1]
    rows, tile, i = [], 0, 2
    plain, start, count = False, 1, 0
    now = open(PORTRAIT, encoding="utf-8").read()
    before = "--before" in args
    tries = []
    while i < len(args):
        if args[i] == "--tile":
            tile = int(args[i + 1])
            i += 1
        elif args[i] == "--plain":
            plain = True
        elif args[i] == "--start":
            start = int(args[i + 1])
            i += 1
        elif args[i] == "--count":
            count = int(args[i + 1])
            i += 1
        elif args[i] == "--try":
            label, table = args[i + 1].split("=", 1)
            tries.append((label, table))
            i += 1
        i += 1
    if before:
        old = subprocess.run(["git", "show", "HEAD:src/client/UI/Portrait.luau"], cwd=ROOT, capture_output=True,
                             text=True, encoding="utf-8", check=True).stdout
        rows.append('{ "Before", %s, nil }' % quote(old))
    rows.append('{ "%s", %s, nil }' % ("Now" if (before or tries) else "", quote(now)))
    for label, table in tries:
        rows.append('{ "%s", %s, %s }' % (label, quote(now), table))
    code = open(SHEET, encoding="utf-8").read()
    code = code.replace('local WHICH = "all"', 'local WHICH = "%s"' % ("" if which == "off" else which), 1)
    code = code.replace("local TILE = 0", "local TILE = %d" % tile, 1)
    code = code.replace("local PLAIN = false", "local PLAIN = %s" % ("true" if plain else "false"), 1)
    code = code.replace("local START = 1", "local START = %d" % start, 1)
    code = code.replace("local COUNT = 0", "local COUNT = %d" % count, 1)
    code = code.replace("local ROWS: { { any } } = {}", "local ROWS: { { any } } = {\n%s,\n}" % ",\n".join(rows), 1)
    fd, path = tempfile.mkstemp(suffix=".luau")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(code)
    try:
        subprocess.run(["node", os.path.join(ROOT, "tools", "studio", "run_luau.js"), studio, path], cwd=ROOT,
                       check=True)
    finally:
        os.remove(path)


if __name__ == "__main__":
    main()
