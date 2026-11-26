#!/usr/bin/env python3
"""Create or reuse Ride a Fish badges and record their IDs. Dry run is offline."""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import struct
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "src/shared"
CATALOG = SHARED / "Badges.luau"
CONFIG = SHARED / "Config.luau"
ICONS = ROOT / "tools/badges/icons"
CREDENTIALS = Path.home() / ".config/ride-a-fish"
PUBLIC_HOST = "https://badges.roblox.com"
CLOUD_HOST = "https://apis.roblox.com"
CREATE_SCOPE = "legacy-universe.badge:manage-and-spend-robux"

ROW = re.compile(
    r'(?m)^\s*(?P<key>\w+)\s*=\s*\{\s*Key\s*=\s*"(?P=key)",\s*'
    r'Name\s*=\s*"(?P<name>[^"\\\n]+)",\s*Description\s*=\s*"(?P<description>[^"\\\n]+)",\s*'
    r'Id\s*=\s*(?P<id>\d+),\s*\},'
)
SWITCH = re.compile(r"(?m)^Config\.Badges\s*=\s*\{\s*On\s*=\s*([01])(?=,)")


class SetupError(Exception):
    pass


@dataclass(frozen=True)
class Badge:
    key: str
    name: str
    description: str
    id: int
    id_span: tuple[int, int]

    @property
    def icon(self):
        return ICONS / f"{self.key}.png"


def load_badges(source):
    badges = [
        Badge(row["key"], row["name"], row["description"], int(row["id"]), row.span("id"))
        for row in ROW.finditer(source)
    ]
    keys = {badge.key for badge in badges}
    names = {badge.name.casefold() for badge in badges}
    ids = [badge.id for badge in badges if badge.id]
    if len(badges) != 6 or len(keys) != 6 or len(names) != 6 or len(set(ids)) != len(ids):
        raise SetupError("Badges.luau must contain six badges with unique keys and names, and unique assigned IDs")
    for badge in badges:
        with badge.icon.open("rb") as icon:
            header = icon.read(24)
        if (
            len(header) != 24
            or header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
            or struct.unpack(">II", header[16:]) != (512, 512)
        ):
            raise SetupError(f"{badge.icon.name} must be a 512×512 PNG")
    return badges


def universe_id(required):
    try:
        value = (CREDENTIALS / "universe-id").read_text(encoding="ascii").strip()
    except FileNotFoundError:
        if required:
            raise SetupError("Put the experience's universe ID in ~/.config/ride-a-fish/universe-id") from None
        return "{universeId}"
    if not re.fullmatch(r"[1-9][0-9]{0,18}", value) or int(value) >= 2**63:
        raise SetupError("universe-id must contain the experience's numeric universe ID")
    return value


@contextmanager
def locked_key():
    try:
        fd = os.open(CREDENTIALS / "roblox-key", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        raise SetupError("Create ~/.config/ride-a-fish/roblox-key as a regular file with mode 600") from None
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600:
            raise SetupError("roblox-key must be a regular file with mode 600")
        try:
            fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SetupError("A badge setup run is already applying with this key file") from None
        key = stream.read(8193).strip()
        if not re.fullmatch(rb"[!-~]{1,8192}", key):
            raise SetupError("roblox-key must contain one API key on a single line")
        yield key.decode("ascii")


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Cloud:
    def __init__(self, key, universe):
        self.key = key
        self.path = f"/v1/universes/{universe}"
        self.http = build_opener(NoRedirects())

    def request(self, url, *, body=None, content_type=None):
        headers = {"Accept": "application/json"}
        method = "GET"
        if body is not None:
            if urlsplit(url).netloc != "apis.roblox.com":
                raise SetupError("Creation must use the Open Cloud host")
            method = "POST"
            headers.update({"x-api-key": self.key, "Content-Type": content_type})
        request = Request(url, data=body, headers=headers, method=method)
        endpoint = url.split("?", 1)[0]
        try:
            with self.http.open(request, timeout=30) as response:
                return json.load(response)
        except HTTPError as exc:
            raise SetupError(f"{method} {endpoint} returned HTTP {exc.code}") from None
        except (URLError, OSError, ValueError):
            raise SetupError(f"{method} {endpoint} failed or returned invalid JSON") from None

    def badges(self):
        cursor = None
        pages = set()
        while True:
            query = {"limit": 100}
            if cursor is not None:
                query["cursor"] = cursor
            page = self.request(f"{PUBLIC_HOST}{self.path}/badges?{urlencode(query)}")
            yield from page["data"]
            cursor = page["nextPageCursor"]
            if cursor is None:
                return
            if not isinstance(cursor, str) or not cursor or cursor in pages:
                raise SetupError("Roblox returned an invalid or repeated pagination cursor")
            pages.add(cursor)

    def free_quota(self):
        return nonnegative(self.request(f"{PUBLIC_HOST}{self.path}/free-badges-quota"), "free badge quota")

    def creation_price(self):
        metadata = self.request(f"{PUBLIC_HOST}/v1/badges/metadata")
        return nonnegative(metadata["badgeCreationPrice"], "badge creation price")

    def create(self, badge, cost, group_funds):
        fields = {
            "name": badge.name,
            "description": badge.description,
            "paymentSourceType": 2 if group_funds else 1,
            "expectedCost": cost,
            "isActive": "true",
        }
        boundary = uuid4().hex
        body = b"".join(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
            for name, value in fields.items()
        )
        body += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="files"; filename="{badge.icon.name}"\r\n'
            "Content-Type: image/png\r\n\r\n"
        ).encode() + badge.icon.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        return self.request(
            f"{CLOUD_HOST}/legacy-badges{self.path}/badges",
            body=body,
            content_type=f"multipart/form-data; boundary={boundary}",
        )


def nonnegative(value, field):
    if type(value) is not int or value < 0:
        raise SetupError(f"Roblox returned an invalid {field}")
    return value


def matching_id(remote, badge):
    value = nonnegative(remote["id"], "badge ID")
    if not 0 < value < 2**53:
        raise SetupError(f"{badge.name}: badge ID cannot be stored exactly in Luau")
    if remote.get("enabled") is not True:
        raise SetupError(f"{badge.name}: enable the matched badge in Creator Hub, then rerun")
    if badge.id and badge.id != value:
        raise SetupError(f"{badge.name}: configured ID disagrees with Roblox for this universe")
    return value


def reconcile(cloud, badges, max_robux, group_funds):
    catalog = {}
    for remote in cloud.badges():
        catalog.setdefault(remote["name"].casefold(), []).append(remote)

    ids = {}
    missing = []
    for badge in badges:
        matches = catalog.get(badge.name.casefold(), [])
        if len(matches) > 1:
            raise SetupError(f"{badge.name}: multiple badges share this name in the universe")
        if matches:
            ids[badge.key] = matching_id(matches[0], badge)
            print(f"Reuse   {badge.name} | {ids[badge.key]}", flush=True)
        elif badge.id:
            raise SetupError(f"{badge.name}: configured ID is absent under that name in this universe")
        else:
            missing.append(badge)

    free = cloud.free_quota() if missing else 0
    price = cloud.creation_price() if len(missing) > free else 0
    remaining = max_robux
    for index, badge in enumerate(missing):
        cost = 0 if index < free else price
        if cost > remaining:
            raise SetupError(
                f"{len(missing) - index} badge(s) still need creation at {cost} Robux each. "
                "Run again after the free quota resets or set --max-robux for the remaining badges"
            )
        print(f"Create  {badge.name} | {cost} Robux", flush=True)
        created = cloud.create(badge, cost, group_funds)
        if created["name"].casefold() != badge.name.casefold():
            raise SetupError("Roblox returned a different name for the created badge")
        ids[badge.key] = matching_id(created, badge)
        remaining -= cost

    if len(set(ids.values())) != len(badges):
        raise SetupError("Roblox returned duplicate IDs for different badge names")
    return ids


def save(path, previous, updated):
    if previous == updated:
        return
    if path.read_text(encoding="utf-8") != previous:
        raise SetupError(f"{path.name} changed during setup. Rerun to recover the Roblox IDs")
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".badges-", delete=False) as stream:
        temporary = Path(stream.name)
        try:
            os.fchmod(stream.fileno(), stat.S_IMODE(path.stat().st_mode))
            stream.write(updated.encode("utf-8"))
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--dry-run", action="store_true", help="print the offline plan (default)")
    modes.add_argument("--apply", action="store_true", help="create or reuse badges and record their IDs")
    parser.add_argument("--max-robux", type=int, default=0, help="maximum spend for this run (default 0)")
    parser.add_argument("--group-funds", action="store_true", help="charge group funds in place of user funds")
    parser.add_argument("--enable-awards", action="store_true", help="also set Config.Badges.On = 1 after writing IDs")
    args = parser.parse_args()
    if args.max_robux < 0:
        parser.error("--max-robux must be zero or positive")

    try:
        universe = universe_id(required=args.apply)
        source = CATALOG.read_text(encoding="utf-8")
        badges = load_badges(source)
        config = CONFIG.read_text(encoding="utf-8")
        switches = list(SWITCH.finditer(config))
        if len(switches) != 1:
            raise SetupError("Config.luau must contain one Config.Badges.On switch set to 0 or 1")
        if not args.apply:
            print(f"DRY RUN | universe {universe} | no network or file writes")
            print(f"  Apply lists all badges, reuses by name, and creates missing badges with scope {CREATE_SCOPE}.")
            for badge in badges:
                print(f"  {badge.name} | {badge.description} | {badge.icon.relative_to(ROOT)} | local ID {badge.id}")
            print(f"  Spend cap: {args.max_robux} Robux | {'group' if args.group_funds else 'user'} funds")
            print("  Successful apply records all IDs and " +
                  ("turns on awards in the checkout." if args.enable_awards else "keeps the current award switch."))
            return 0

        with locked_key() as key:
            print(f"APPLY | universe {universe} | spend cap {args.max_robux} Robux", flush=True)
            ids = reconcile(Cloud(key, universe), badges, args.max_robux, args.group_funds)
            updated = source
            for badge in reversed(badges):
                start, end = badge.id_span
                updated = updated[:start] + str(ids[badge.key]) + updated[end:]
            save(CATALOG, source, updated)
            if args.enable_awards:
                start, end = switches[0].span(1)
                save(CONFIG, config, config[:start] + "1" + config[end:])
            print(f"Recorded {len(ids)} badge IDs. Review and commit the changes before merging.")
        return 0
    except (SetupError, OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        detail = str(exc) if isinstance(exc, SetupError) else f"local file or Roblox response error ({type(exc).__name__})"
        print(f"Setup stopped: {detail}", file=sys.stderr)
        if args.apply:
            print("If a create request was attempted, confirm it in Creator Hub before rerunning.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
