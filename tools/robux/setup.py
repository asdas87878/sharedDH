#!/usr/bin/env python3
"""Set up Ride a Fish's Robux catalog from Products.luau. See README.md."""

import argparse
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
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = ROOT / "src/shared/Products.luau"
ICONS = ROOT / "tools/robux/icons"
CONFIG = Path.home() / ".config/ride-a-fish"
HOST = "https://apis.roblox.com"
# Route prefix, collection name, ID field and icon field from Creator Hub's Open Cloud schema.
API = {
    "Product": ("developer-products/v2", "developerProducts", "productId", "iconImageAssetId"),
    "Pass": ("game-passes/v1", "gamePasses", "gamePassId", "iconAssetId"),
}
TOKEN = re.compile(
    r'--\[(?P<equals>=*)\[.*?\](?P=equals)\]|--[^\n]*|"(?:\\.|[^"\\])*"'
    r"|'(?:\\.|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*|[0-9][0-9_]*|[^\s]",
    re.DOTALL,
)


class SetupError(Exception):
    pass


@dataclass(frozen=True)
class Offer:
    key: str
    name: str
    kind: str
    price: int
    description: str
    id: int
    id_span: tuple[int, int]

    @property
    def icon(self):
        return ICONS / f"{self.key}.png"

    def fields(self):
        return {
            "name": self.name,
            "description": self.description,
            "price": str(self.price),
            "isForSale": "true",
            "isManagedPricingEnabled": "false",
        }


def literal(field, fields):
    token = fields.get(field)
    if token is None:
        raise SetupError(f"Missing or non-literal {field} in an offer in Products.luau")
    value = token.group()
    if value.startswith('"'):
        return json.loads(value)
    if re.fullmatch(r"[0-9][0-9_]*", value):
        return int(value.replace("_", ""))
    if value in {"true", "false"}:
        return value == "true"
    raise SetupError(f"{field} must be a double-quoted string, an integer, or a boolean")


def offer_tables(source):
    """Find literal offer records, ignoring strings, comments, and each record's nested fields."""
    tokens = [token for token in TOKEN.finditer(source) if not token.group().startswith("--")]
    stack = []
    for i, token in enumerate(tokens):
        value = token.group()
        if value == "{":
            stack.append({})
        elif value == "}":
            if not stack:
                raise SetupError("Unmatched closing table in Products.luau")
            fields = stack.pop()
            if "Key" in fields:
                yield fields
        elif stack and i + 3 < len(tokens) and tokens[i - 1].group() in {"{", ",", ";"}:
            if tokens[i + 1].group() == "=":
                if value in stack[-1]:
                    raise SetupError(f"Repeated {value} in a table in Products.luau")
                is_literal = tokens[i + 3].group() in {",", ";", "}"}
                stack[-1][value] = tokens[i + 2] if is_literal else None
    if stack:
        raise SetupError("Unclosed table in Products.luau")


def description(fields, name):
    if "Line" in fields:
        line = literal("Line", fields)
        if not isinstance(line, str) or not line.strip():
            raise SetupError("An offer's Line must be a nonempty string")
        return line
    if "Amount" in fields and "Gives" in fields:
        amount = literal("Amount", fields)
        gives = literal("Gives", fields)
        if gives == "Oxygen":
            return f"Adds {amount:,} to your maximum Oxygen."
        if gives == "Coins":
            return f"Adds ${amount:,} to your Cash."
        if gives == "Offline":
            return f"Claim {amount} times your Welcome Back reward."
    return name


def load_offers(source):
    offers, hidden, keys, identities = [], [], set(), set()
    for fields in offer_tables(source):
        key = literal("Key", fields)
        if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key) or key in keys:
            raise SetupError("Invalid or duplicate offer Key in Products.luau")
        keys.add(key)
        if "Hidden" in fields:
            hidden_flag = literal("Hidden", fields)
            if type(hidden_flag) is not bool:
                raise SetupError(f"{key}: Hidden must be a boolean")
            if hidden_flag:
                hidden.append(key)
                continue
        name, kind, price, offer_id = (literal(field, fields) for field in ("Name", "Kind", "Price", "Id"))
        if kind not in API or not isinstance(name, str) or not name.strip():
            raise SetupError(f"{key}: expected a Product or Pass with a name")
        if type(price) is not int or not 1 <= price <= 1_000_000_000:
            raise SetupError(f"{key}: expected a positive Robux price")
        if type(offer_id) is not int or not 0 <= offer_id < 2**53:
            raise SetupError(f"{key}: expected a valid ID or 0")
        if "Gives" not in fields or not isinstance(literal("Gives", fields), str):
            raise SetupError(f"{key}: visible offer needs a grant")
        identity = (kind, name.casefold())
        if identity in identities:
            raise SetupError(f"{key}: duplicate offer name for {kind}")
        identities.add(identity)
        offer = Offer(key, name, kind, price, description(fields, name), offer_id, fields["Id"].span())
        icon_path = offer.icon.relative_to(ROOT)
        try:
            with offer.icon.open("rb") as png:
                header = png.read(24)
                size = os.fstat(png.fileno()).st_size
        except OSError:
            raise SetupError(f"Could not read {icon_path}") from None
        if (
            len(header) != 24
            or header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
            or struct.unpack(">II", header[16:]) != (512, 512)
            or size > 5_000_000
        ):
            raise SetupError(f"{icon_path} must be a 512x512 PNG within 5 MB")
        offers.append(offer)
    if not offers:
        raise SetupError("No visible offers in Products.luau")
    return offers, hidden


def key_file(path, *, read):
    try:
        info = path.lstat()
    except FileNotFoundError:
        if read:
            raise SetupError("Create ~/.config/ride-a-fish/roblox-key with mode 600 before --apply") from None
        return None
    if not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600:
        raise SetupError("roblox-key must be a regular file with mode 600")
    if not read:
        return None
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, "rb") as stream:
            opened = os.fstat(stream.fileno())
            if not stat.S_ISREG(opened.st_mode) or stat.S_IMODE(opened.st_mode) != 0o600:
                raise SetupError("roblox-key must be a regular file with mode 600")
            key = stream.read(8193).strip()
    except OSError:
        raise SetupError("Could not read roblox-key") from None
    if not re.fullmatch(rb"[!-~]{1,8192}", key):
        raise SetupError("roblox-key must contain one API key on a single line")
    return key.decode("ascii")


def universe_id(path, *, required):
    try:
        value = path.read_text(encoding="ascii").strip()
    except FileNotFoundError:
        if required:
            raise SetupError("Put the published experience's universe ID in ~/.config/ride-a-fish/universe-id") from None
        return "{universeId}"
    if not re.fullmatch(r"[1-9][0-9]{0,18}", value) or int(value) >= 2**63:
        raise SetupError("universe-id must contain the experience's numeric universe ID")
    return value


def endpoint(kind, universe):
    prefix = API[kind][0]
    return f"/{prefix}/universes/{universe}/{prefix.split('/')[0]}"


def multipart(fields, icon):
    boundary = uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    if icon is not None:
        parts.extend([
            (f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; filename="{icon.name}"\r\n'
             'Content-Type: application/octet-stream\r\n\r\n').encode(),
            icon.read_bytes(),
            b"\r\n",
        ])
    parts.append(f"--{boundary}--\r\n".encode())
    return f"multipart/form-data; boundary={boundary}", b"".join(parts)


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # do not forward the API key to a redirect target


class Cloud:
    def __init__(self, key, universe):
        self.key = key
        self.universe = universe
        self.http = build_opener(NoRedirects())
        self.next_write = 0

    def request(self, method, path, fields=None, icon=None):
        headers = {"x-api-key": self.key, "Accept": "application/json"}
        data = None
        if fields is not None:
            headers["Content-Type"], data = multipart(fields, icon)
            time.sleep(max(0, self.next_write - time.monotonic()))
            self.next_write = time.monotonic() + 0.4
        request = Request(HOST + path, data=data, headers=headers, method=method)
        try:
            with self.http.open(request, timeout=30) as response:
                raw = response.read()
            return json.loads(raw) if raw else {}
        except HTTPError as exc:
            # Avoid logging response bodies or exceptions that could contain credentials.
            raise SetupError(f"{method} {path.split('?')[0]} returned HTTP {exc.code}") from None
        except (URLError, OSError, ValueError):
            raise SetupError(f"{method} {path.split('?')[0]} failed or returned invalid JSON") from None

    def catalog(self, kind):
        route = endpoint(kind, self.universe)
        collection = API[kind][1]
        items, seen_tokens = [], set()
        query = {"pageSize": 50}
        while True:
            page = self.request("GET", f"{route}/creator?{urlencode(query)}")
            if not isinstance(page, dict) or not isinstance(page.get(collection), list):
                raise SetupError(f"Unexpected {kind} catalog response")
            id_field = API[kind][2]
            for item in page[collection]:
                if not isinstance(item, dict) or not isinstance(item.get("name"), str):
                    raise SetupError(f"Unexpected {kind} catalog entry")
                positive_id(item.get(id_field))
            items.extend(page[collection])
            token = page.get("nextPageToken")
            if token is None or token == "":
                return items
            if not isinstance(token, str) or token in seen_tokens:
                raise SetupError(f"Invalid or repeated {kind} catalog page token")
            seen_tokens.add(token)
            query["pageToken"] = token


def positive_id(value):
    if type(value) in (int, str) and re.fullmatch(r"[1-9][0-9]{0,15}", str(value)):
        number = int(value)
        if number < 2**53:
            return number
    raise SetupError("Roblox returned an invalid or unsupported offer ID")


def reconcile(offers, cloud):
    """Resolve every offer before the first write, so ambiguous names or IDs cannot partially apply."""
    catalogs = {kind: cloud.catalog(kind) for kind in dict.fromkeys(offer.kind for offer in offers)}
    claimed, plan = set(), []
    for offer in offers:
        id_field = API[offer.kind][2]
        matches = [
            item for item in catalogs[offer.kind]
            if item["name"].casefold() == offer.name.casefold()
        ]
        if offer.id:
            matches = [item for item in matches if positive_id(item.get(id_field)) == offer.id]
            if not matches:
                raise SetupError(f"{offer.key}: configured ID {offer.id} does not match its name in this universe")
        if len(matches) > 1:
            raise SetupError(f"{offer.key}: multiple matches in Roblox. Set the intended Id in Products.luau")
        remote = matches[0] if matches else None
        if remote is not None:
            identity = (offer.kind, positive_id(remote.get(id_field)))
            if identity in claimed:
                raise SetupError(f"{offer.key}: Roblox ID is already assigned to another offer")
            claimed.add(identity)
        plan.append((offer, remote))
    return plan


def apply(cloud, plan, replace_icons):
    ids = {}
    for offer, remote in plan:
        route = endpoint(offer.kind, cloud.universe)
        _, _, id_field, icon_field = API[offer.kind]
        fields = offer.fields()
        if remote is None:
            created = cloud.request("POST", route, fields, offer.icon)
            offer_id = positive_id(created.get(id_field))
            action = "CREATED"
        else:
            offer_id = positive_id(remote.get(id_field))
            upload_icon = replace_icons or remote.get(icon_field) in (None, 0, "0")
            prices = remote.get("priceInformation") or {}
            current = {
                "name": remote.get("name"),
                "description": remote.get("description"),
                "price": str(prices.get("defaultPriceInRobux")),
                "isForSale": str(remote.get("isForSale")).lower(),
                "isManagedPricingEnabled": str(remote.get("isManagedPricingEnabled")).lower(),
            }
            changes = {field: value for field, value in fields.items() if current[field] != value}
            if changes or upload_icon:
                cloud.request("PATCH", f"{route}/{offer_id}", changes, offer.icon if upload_icon else None)
            action = "REUSED + UPDATED" if changes or upload_icon else "REUSED"
        ids[offer.key] = offer_id
        print(f"{action} {offer.key} → {offer_id} ({offer.price} Robux)", flush=True)
    return ids


def write_ids(source, offers, ids):
    updated = source
    for offer in sorted(offers, key=lambda offer: offer.id_span[0], reverse=True):
        if ids[offer.key] != offer.id:
            start, end = offer.id_span
            updated = updated[:start] + str(ids[offer.key]) + updated[end:]
    if updated == source:
        return
    if PRODUCTS.read_bytes().decode("utf-8") != source:
        raise SetupError("Products.luau changed during setup. Rerun to recover IDs from Roblox")
    with tempfile.NamedTemporaryFile(dir=PRODUCTS.parent, prefix=".products-", delete=False) as stream:
        temporary = Path(stream.name)
        try:
            os.fchmod(stream.fileno(), stat.S_IMODE(PRODUCTS.stat().st_mode))
            stream.write(updated.encode("utf-8"))
            stream.close()
            temporary.replace(PRODUCTS)
        finally:
            temporary.unlink(missing_ok=True)


def dry_run(offers, hidden, universe, replace_icons):
    print(f"DRY RUN | universe {universe} | no network or file writes")
    for kind in dict.fromkeys(offer.kind for offer in offers):
        print(f"  Apply lists: GET {HOST}{endpoint(kind, universe)}/creator (all pages)")
    print("  Reused icons: " + ("replace with local PNG" if replace_icons else "keep existing icon; upload if missing"))
    for offer in offers:
        route = endpoint(offer.kind, universe)
        action = f"REUSE ID {offer.id} (validate name)" if offer.id else "CREATE if no match; otherwise REUSE by name"
        print(f"{offer.key} [{offer.kind}] {action}")
        print(f"  {offer.price} Robux | {offer.icon.relative_to(ROOT)} | {offer.fields()}")
        if not offer.id:
            print(f"  POST {route} (new)")
        print(f"  PATCH {route}/{offer.id or '{offerId}'} (if changes needed)")
    print(f"Offers: {len(offers)} | Hidden: {', '.join(hidden) or 'none'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="show the offline plan (default)")
    mode.add_argument("--apply", action="store_true", help="make live changes and record IDs in Products.luau")
    parser.add_argument("--replace-icons", action="store_true", help="also replace icons on reused Roblox offers")
    args = parser.parse_args()
    try:
        key = key_file(CONFIG / "roblox-key", read=args.apply)
        universe = universe_id(CONFIG / "universe-id", required=args.apply)
        if not args.apply:
            offers, hidden = load_offers(PRODUCTS.read_bytes().decode("utf-8"))
            dry_run(offers, hidden, universe, args.replace_icons)
            return 0
        with Path(__file__).open("rb") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise SetupError("Another setup run is already applying from this checkout") from None
            print(f"APPLY | universe {universe}", flush=True)
            source = PRODUCTS.read_bytes().decode("utf-8")
            offers, _ = load_offers(source)
            cloud = Cloud(key, universe)
            ids = apply(cloud, reconcile(offers, cloud), args.replace_icons)
            write_ids(source, offers, ids)
            print(f"Resolved {len(ids)} offers. IDs recorded in src/shared/Products.luau.")
        return 0
    except (SetupError, OSError, ValueError, KeyError, TypeError, AttributeError, IndexError) as exc:
        detail = str(exc) if isinstance(exc, SetupError) else f"could not process local files or Roblox response ({type(exc).__name__})"
        print(f"Setup stopped: {detail}", file=sys.stderr)
        if args.apply:
            print("If a write was attempted, check Creator Hub before rerunning. Matching offers are reused.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
