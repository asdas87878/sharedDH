"""Shared by the research readers (reddit.py, yt.py): one cache and one queue for every chat and agent on this PC.

Why: on 2026-11-16 four research agents asked YouTube for captions at once and YouTube refused the whole PC for a
while; Reddit's feeds did the same after three requests. So every outside request goes through `wait(site, gap)`,
which keeps a gap between requests to one site across all processes, and everything fetched is kept in
work/research/ (not in the repo), so nothing is asked for twice.

Nothing here sends anything about the user or the project: the client name is a plain generic one."""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Where fetched things are kept. C: was full on 2026-11-16 (92 MB free), so when the folder D:\ResearchCache exists it
# is used: everything in it can be fetched again, so it does not matter that D: is the failing disk. Without that
# folder, or with RESEARCH_CACHE set, the vault's own work/research (not in the repo).
CACHE = os.environ.get("RESEARCH_CACHE") or (r"D:\ResearchCache" if os.path.isdir(r"D:\ResearchCache") else os.path.join(ROOT, "work", "research"))
AGENT = "Mozilla/5.0 (compatible; research-reader/1.0)"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def folder(*parts):
    path = os.path.join(CACHE, *parts)
    os.makedirs(path, exist_ok=True)
    return path


def _state(site):
    return os.path.join(folder("state"), site + ".json")


def read_state(site):
    try:
        with open(_state(site), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def write_state(site, state):
    tmp = _state(site) + ".%d.tmp" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f)
    os.replace(tmp, _state(site))


def blocked(site):
    """seconds until the site may be asked again after it refused us (0: it may be asked now)"""
    return max(0.0, read_state(site).get("blocked_until", 0) - time.time())


def refuse(site, why, first=1800):
    """the site refused us: nobody asks it again for a while, twice as long each time in a row (at most 6 hours)"""
    state = read_state(site)
    hold = min(6 * 3600, max(first, state.get("hold", 0) * 2))
    state.update(blocked_until=time.time() + hold, hold=hold, why=why[:200], at=time.strftime("%Y-%m-%d %H:%M"))
    write_state(site, state)
    return hold


def accepted(site):
    state = read_state(site)
    if state.get("hold"):
        state.update(hold=0, blocked_until=0)
        write_state(site, state)


def wait(site, gap):
    """take the next turn at `site`: at least `gap` seconds after the last request by anyone on this PC"""
    lock = _state(site) + ".lock"
    while True:
        try:
            handle = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(handle)
            break
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(lock) > 120:  # left behind by a process that died
                    os.remove(lock)
                    continue
            except OSError:
                pass
            time.sleep(0.5)
    try:
        state = read_state(site)
        due = state.get("last", 0) + gap
        if due > time.time():
            time.sleep(due - time.time())
        state["last"] = time.time()
        write_state(site, state)
    finally:
        try:
            os.remove(lock)
        except OSError:
            pass


def key(text):
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:16]


def cached(kind, name, max_age=None):
    path = os.path.join(folder(kind), name)
    if os.path.exists(path) and (max_age is None or time.time() - os.path.getmtime(path) < max_age):
        with open(path, encoding="utf-8") as f:
            return f.read()
    return None


def keep(kind, name, text):
    with open(os.path.join(folder(kind), name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return text


def fetch(url, site, gap, timeout=45):
    """one polite GET. Returns (status, text, headers); status 0 is a network failure"""
    wait(site, gap)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": AGENT}), timeout=timeout) as r:
            return r.status, r.read().decode("utf-8", "replace"), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:500].decode("utf-8", "replace"), dict(e.headers)
    except Exception as e:  # noqa: BLE001 (a timeout, a reset connection: reported, not raised)
        return 0, repr(e), {}
