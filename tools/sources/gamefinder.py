"""Find Roblox games of 1,000 players and up that look likely to last, for asking their owners if they would sell to a
buyer (the user finds games for someone else and is paid a commission; 2026-11-23).

It only reads public figures and writes a shortlist. It sends nothing to anybody, joins nothing and signs in nowhere:
the person opens the links and writes to the owners themselves.

Where the figures come from (both without an account, one request at a time through common.py, all cached):
  - Roblox's public charts and game pages: the candidates, the creator, age, visits, likes. No daily limit met so far.
    So only games on some Roblox chart are seen (870 of them on 2026-11-23), not every game.
  - RoTerminal (roterminal.co/docs): its screen reaches only the 600 most played games (about 3,300 players and up on
    2026-11-23), so it is off unless asked for (--pages 8). Its page on one game gives the 7-day average, the trend, the
    peak since 27 Sep 2026, minutes a visit, the owner and the Top Earning place. 50 calls a day without a key, so
    only the best of a first cut are looked at closely. Its terms: do not pass its data on in bulk; link its pages.

usage (from the project folder):
  python tools/sources/gamefinder.py find [--low 1000] [--high 20000] [--look 40] [--top 30] [--min-age 120]
        writes work/gamefinder/shortlist-<date>.md (not in the repo) and prints the same table
  python tools/sources/gamefinder.py check <universe id> [...]
        the lasting score of any game, with its parts

What it cannot know: earnings (only the place on Roblox's Top Earning chart, when there is one), retention, and
whether the owner would sell. Those come from the owner."""
import argparse
import json
import math
import os
import re
import time

import common

KIND = "gamefinder"
EXPLORE = "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId=1"
GAMES = "https://games.roblox.com/v1/games"
GROUPS = "https://groups.roblox.com/v1/groups/"
ROTERMINAL = "https://roterminal.co/api/v1/games/"
ROBLOX_GAP, ROTERMINAL_GAP = 2.0, 2.5  # seconds between requests, PC-wide (RoTerminal allows 30 a minute)
HOUR = 3600
MISSED = []  # sites that did not answer in this run: the shortlist says so, rather than passing off gaps as facts
KEEP_BACK = 2  # RoTerminal calls left unspent each day
OUT = os.path.join(common.ROOT, "work", "gamefinder")

# Publishers and buyers of games: they own many and are the competition, not sellers. Not a full list.
STUDIOS = re.compile(
    r"voldex|gamefam|do ?big|splitting point|twin atlas|super ?social|toya|dubit|super league|wonder works|uplift|"
    r"sawhorse|fullflower|karta|infinite canvas|red manta|rolve|nosniy|adopt me|roblox", re.I)
# Somebody else's property in the name or text: a sale passes on the trouble. Word matches only, so check by eye.
IP = re.compile(
    r"\b(naruto|one piece|dragon ?ball|goku|jujutsu|demon slayer|bleach|blue lock|anime|haikyu+|hunter x hunter|"
    r"one punch|attack on titan|aot|my hero|pok[eé]mon|sonic|mario|minecraft|fnaf|five nights|poppy playtime|"
    r"squid game|cuphead|undertale|deltarune|star wars|marvel|spider-?man|batman|disney|harry potter|gta|"
    r"call of duty|fortnite|lego|barbie|peppa|bluey|mrbeast|nba|nfl|fifa|brainrot|skibidi|stranger things|jojo|"
    r"godzilla|transformers|ben 10|spongebob|chainsaw man|solo leveling|warrior cats|warriors|tokyo ghoul|scp|hajime no ippo|blade runner|garten of banban)\b", re.I)


# Accounts kept only to own a group: a message to one is likely never read.
HOLDING = re.compile(r"hold|management|official|studio|iswinning|group|company", re.I)


def read(url, site, gap, max_age):
    """the JSON at `url`, kept for `max_age` seconds; None when it does not answer"""
    name = common.key(url) + ".json"
    text = common.cached(KIND, name, max_age)
    if text is None:
        if common.blocked(site):
            MISSED.append(site)
            return None
        status, text, headers = common.fetch(url, site, gap)
        told = {k.lower(): v for k, v in headers.items()}
        if site == "roterminal" and "x-ratelimit-remaining" in told:
            left, reset = int(told["x-ratelimit-remaining"]), int(told.get("x-ratelimit-reset") or 0)
            common.write_state(site, dict(common.read_state(site), left=left, reset=reset))
        if status == 429:
            common.refuse(site, text, first=180 if site == "roblox" else 1800)
        if status != 200:
            MISSED.append(site)
            print("  ! %s answered %s: %s" % (site, status, text[:120].replace("\n", " ")))
            return None
        common.accepted(site)
        common.keep(KIND, name, text)
    try:
        return json.loads(text)
    except ValueError:
        return None


def calls_left():
    """RoTerminal calls left as it last told us (50 once its day, midnight New York, has passed)"""
    state = common.read_state("roterminal")
    return state.get("left", 50) if time.time() < state.get("reset", 0) else 50


DETAIL_AGE = 4 * 24 * HOUR


# A game looked at is kept four days, so each day's run goes on down the list to games not seen yet.
def roterminal(path, max_age=DETAIL_AGE):
    if calls_left() <= KEEP_BACK and common.cached(KIND, common.key(ROTERMINAL + path) + ".json", max_age) is None:
        return None
    body = read(ROTERMINAL + path, "roterminal", ROTERMINAL_GAP, max_age)
    return body.get("data") if body else None


def charts():
    """{universe id: {"players", "charts"}} from every list on Roblox's Charts page"""
    found, token = {}, ""
    for _ in range(10):
        body = read(EXPLORE + ("&sortsPageToken=" + token if token else ""), "roblox", ROBLOX_GAP, HOUR)
        if not body:
            break
        for sort in body.get("sorts", []):
            for place, game in enumerate(sort.get("games") or [], 1):
                row = found.setdefault(game["universeId"], {"players": game.get("playerCount", 0), "charts": {}})
                row["charts"][sort.get("sortDisplayName") or sort.get("sortId")] = place
        token = body.get("nextSortsPageToken")
        if not token:
            break
    return found


def screen(low, high, pages):
    """{universe id: players} from RoTerminal's screen: 25 a page, walked down by the players of the last one"""
    found, top = {}, high
    for _ in range(pages):
        body = roterminal("screen?min_playing=%d&max_playing=%d&limit=25&sort=playing" % (low, top), 3 * HOUR)
        games = (body or {}).get("games") or []
        for game in games:
            found[game["id"]] = game["playing_now"]
        if len(games) < 25:
            break
        top = games[-1]["playing_now"] - 1
    return found


def roblox_pages(ids):
    """{universe id: Roblox's own page on it, with the like share}"""
    pages = {}
    for start in range(0, len(ids), 40):
        batch = ",".join(str(i) for i in ids[start : start + 40])
        for game in (read(GAMES + "?universeIds=" + batch, "roblox", ROBLOX_GAP, HOUR) or {}).get("data", []):
            pages[game["id"]] = game
        for vote in (read(GAMES + "/votes?universeIds=" + batch, "roblox", ROBLOX_GAP, HOUR) or {}).get("data", []):
            total = vote["upVotes"] + vote["downVotes"]
            if vote["id"] in pages and total:
                pages[vote["id"]]["likes"] = 100.0 * vote["upVotes"] / total
    return pages


def days_since(stamp):
    return max(0.0, (time.time() - time.mktime(time.strptime(stamp[:10], "%Y-%m-%d"))) / 86400)


def part(value, low, high):
    """0 at `low`, 1 at `high`, straight between"""
    return max(0.0, min(1.0, (value - low) / float(high - low)))


# Each part of the lasting score: weight and what it reads. Players now are left out on purpose: a game of 5,000 is
# not likelier to last than one of 1,500.
# Visits count for little: every new game scores full on them.
WEIGHTS = {"age": 25, "week": 25, "peak": 15, "visits": 5, "minutes": 15, "likes": 15}


def lasting(detail):
    """(score out of 100, its parts 0 to 1) from RoTerminal's page on a game. A figure it leaves out
    is left out of the sum, and the rest are scaled up to 100"""
    trend = detail.get("momentum") or {}
    average, against = trend.get("average_last_7_days"), trend.get("against_the_7_days_before")
    peak = (detail.get("high_since_tracking_began") or {}).get("players")
    age, visits, daily = detail.get("days_old") or 0, detail.get("visits") or 0, detail.get("visits_a_day") or 0
    parts = {}
    parts["age"] = part(age, 60, 730)
    if against is not None:
        # falling 30% a week is 0, level is 1; a jump is worth less again, as it is an update or an advert
        parts["week"] = part(against, -30, 0) if against <= 25 else max(0.3, 1 - (against - 25) / 100.0)
    if average and peak:
        parts["peak"] = part(average / float(peak), 0.08, 0.45)  # one-moment peak: a steady game sits at 0.4 to 0.6
    if age and visits:
        parts["visits"] = part(daily / (visits / float(age)), 0.05, 0.6)  # visits a day now against its whole life's
    if detail.get("average_visit_minutes"):
        parts["minutes"] = part(detail["average_visit_minutes"], 4, 20)
    if detail.get("likes"):
        parts["likes"] = part(detail["likes"], 65, 92)
    return 100.0 * sum(WEIGHTS[k] * v for k, v in parts.items()) / sum(WEIGHTS[k] for k in parts), parts


def first_cut(page, chart):
    """a rough order from Roblox's figures alone, to choose which games RoTerminal is asked about"""
    age = days_since(page["created"])
    daily = page["visits"] / max(age, 1.0)
    # visits a day its players now would make, at about 60 visits a day for each player at once (15 to 25 minutes)
    holding = part(page["playing"] * 60.0 / max(daily, 1.0), 0.05, 0.8)
    score = 30 * part(age, 60, 730) + 20 * holding + 15 * part(page.get("likes", 0), 65, 92)
    for name, worth in (("Top Revisited", 20), ("Top Earning", 20), ("Fun with Friends", 8), ("Top Rated", 5)):
        score += worth if name in chart else 0
    score -= 25 if IP.search(page["name"]) else 0  # still listed, but after games that own their idea
    return score + 5 * part(math.log10(max(page["favoritedCount"], 1)), 4, 6)


def remarks(page, detail, owner):
    """(good signs, warnings) about asking this owner"""
    good, bad = [], []
    studio = detail.get("studio") or {}
    quiet = days_since(page["updated"])
    if quiet >= 30:
        good.append("no update for %d days" % quiet)
    if page["creator"]["type"] == "User":
        good.append("owned by one person")
    elif studio.get("games") is not None and studio["games"] <= 2:
        good.append("small group (%d game%s)" % (studio["games"], "" if studio["games"] == 1 else "s"))
    if not owner:
        bad.append("owner not shown")
    elif HOLDING.search(owner):
        bad.append("a company or holding account: reach the team instead")
    words = sorted({m.lower() for m in IP.findall(page["name"] + " " + (page.get("description") or ""))})
    if words:
        bad.append("may use others' IP: " + ", ".join(words[:4]))
    if (detail.get("momentum") or {}).get("against_the_7_days_before", 0) > 60:
        bad.append("jumped this week")
    return good, bad


def earning(detail, chart):
    """what is known of its earnings: places and prices, never a guessed amount"""
    for row in detail.get("roblox_charts_now") or []:
        if row.get("chart") == "Top Earning":
            return "#%s (best #%s)" % (row.get("place"), row.get("best_place", "?"))
    return "#%d" % chart["Top Earning"] if "Top Earning" in chart else "unknown"


def plain(text):
    """a game's or group's own words, safe inside a table"""
    return re.sub(r"\s+", " ", re.sub(r"[|\[\]<>`*_\\]", " ", text)).strip()[:48]


def spoken(name):
    """a game's name without its update tags and pictures, as a person would write it"""
    bare = re.sub(r"\[[^\]]*\]|\([^)]*\)|[^\w\s:'&!+.-]|UP(D|DATE)!?", " ", name)
    return re.sub(r"\s+", " ", bare).strip(" -:!") or name


def owner_of(page, detail):
    """(who to ask: the Roblox name, link to the page they own)"""
    creator = page["creator"]
    if creator["type"] == "User":
        return creator["name"], "https://www.roblox.com/users/%d/profile" % creator["id"]
    link = "https://www.roblox.com/communities/%d" % creator["id"]
    if (detail.get("studio") or {}).get("owner"):
        return detail["studio"]["owner"], link
    group = read(GROUPS + str(creator["id"]), "roblox", ROBLOX_GAP, 24 * HOUR) or {}
    return (group.get("owner") or {}).get("username"), link


MESSAGE = """Hi, are you the owner of {name}, or could you point me to whoever is? {why}I find Roblox games for a buyer
who wants to buy one outright, and I'd get a commission if a sale goes through. Would you consider selling?
If you would: a rough price and what it earns in a month is enough to start, and I'd put you in touch with the buyer.
Any sale would be by written agreement, with payment through an escrow service and Roblox's own ownership transfer.
I'll never ask for your password or account. If you're under 18, a parent or guardian would have to agree and sign.
If not, no problem, and I won't ask again."""

NOTES = """
## Before you write to anyone
- **Have the buyer's terms in writing first:** your commission, when it is paid and by whom, that it is still owed if
  he deals with an owner you brought him directly, his budget, the kinds of game he wants, and that he can pay.
- **Know who the buyer is.** It is your name on the message. Never handle the money yourself, for either side.
- **Write to one owner at a time, by hand, and change the words.** Copied messages sent to many people are spam under
  Discord's rules. Use the game's ticket or contact channel where it has one, and never post offers in its chat.
- **Look at the game yourself first.** The scores read figures only; the IP warning only matches words.
- **What the buyer will want to see,** by screen share or from the Creator Dashboard: 90 days of Robux earned, D1 and
  D7 retention, where players come from, advert spending, who made the code and art (with written rights), and any
  warnings from Roblox.
- **Read Roblox's current Terms on selling a game first.** They changed on 1 November 2026.
- **This file names the owners.** Give the buyer single games once terms are agreed, not this list: RoTerminal's terms
  also bar passing its data on in bulk.

## How the score is made
Out of 100, from RoTerminal's figures: age 25 (full at two years), this week against last 25 (30% down is none),
7-day average against the peak since 27 Sep 15, visits a day now against its whole life 5, minutes a visit 15, likes 15.
Players now are left out on purpose. Earnings are the place on Roblox's Top Earning chart, or unknown: no amount is
guessed. The weights are a judgement, not measured against games that lasted.
"""


def find(args):
    chart = charts()
    inside = {i: row["players"] for i, row in chart.items()}
    screened = screen(args.low, int(args.high * 1.2), args.pages)
    inside.update({i: p for i, p in screened.items() if i not in inside})
    # a wide band on players now, since they swing through the day; the true band is cut on the 7-day average below
    wide = [i for i, p in inside.items() if args.low * 0.7 <= p <= args.high * 1.2]
    pages = roblox_pages(sorted(wide))
    counts = [("games seen on the charts and the screen", len(inside)), ("near the player band now", len(wide))]

    rows = [p for p in pages.values() if days_since(p["created"]) >= args.min_age]
    counts.append(("at least %d days old" % args.min_age, len(rows)))
    rows = [p for p in rows if p.get("likes", 0) >= 65]
    counts.append(("liked by 65% or more", len(rows)))
    rows = [p for p in rows if not STUDIOS.search(p["creator"]["name"])]
    counts.append(("not a known publisher's", len(rows)))
    rows.sort(key=lambda p: -first_cut(p, chart.get(p["id"], {}).get("charts", {})))

    looked, kept, lost = 0, [], {"outside the band on a 7-day average": 0, "too new (RoTerminal's date)": 0, "falling over 35% a week": 0, "a big studio's": 0}
    fresh = 0
    for page in rows:
        if common.cached(KIND, common.key(ROTERMINAL + str(page["id"])) + ".json", DETAIL_AGE) is None:
            if fresh >= args.look:
                continue
            fresh += 1
        detail = roterminal(str(page["id"]))
        if not detail:
            continue
        looked += 1
        trend, studio = detail.get("momentum") or {}, detail.get("studio") or {}
        average = trend.get("average_last_7_days") or 0
        others = (studio.get("players_in_all_their_games_now") or 0) - (detail.get("playing_now") or 0)
        if not args.low <= average <= args.high:
            lost["outside the band on a 7-day average"] += 1
        elif (detail.get("days_old") or 0) < args.min_age:
            lost["too new (RoTerminal's date)"] += 1
        elif trend.get("against_the_7_days_before", 0) < -35:
            lost["falling over 35% a week"] += 1
        elif others > 15000:
            lost["a big studio's"] += 1
        else:
            score, parts = lasting(detail)
            kept.append((score, parts, page, detail, chart.get(page["id"], {}).get("charts", {})))
    kept.sort(key=lambda row: -row[0])
    counts.append(("looked at closely so far (RoTerminal's daily limit; the rest on later days)", looked))
    counts += [("- dropped: " + why, n) for why, n in lost.items() if n]
    counts.append(("left, best %d shown" % args.top, len(kept)))

    out = ["# Games to ask about, " + time.strftime("%Y-%m-%d %H:%M"), "", "Made by `tools/sources/gamefinder.py find`. Private: figures from [RoTerminal](https://roterminal.co) (linked on each row) and Roblox.", ""]
    out += ["| # | Game | Lasts | 7-day avg | Week | Age | Min/visit | Likes | Top Earning | Passes | Good signs | Warnings |", "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    people = []
    for n, (score, parts, page, detail, where) in enumerate(kept[: args.top], 1):
        trend, store = detail.get("momentum") or {}, detail.get("store") or {}
        owner, link = owner_of(page, detail)
        good, bad = remarks(page, detail, owner)
        game_link = "https://www.roblox.com/games/%d" % page["rootPlaceId"]
        passes = "%d at %s" % (store["passes"], store.get("typical_robux", "?")) if store.get("passes") else "none seen"
        out.append("| %d | [%s](%s) | %d | %s | %+.0f%% | %dd | %s | %.0f%% | %s | %s | %s | %s |" % (
            n, plain(page["name"]), detail.get("link"), round(score), format(trend.get("average_last_7_days") or 0, ","),
            trend.get("against_the_7_days_before") or 0, detail.get("days_old") or 0, detail.get("average_visit_minutes", "?"),
            detail.get("likes") or 0, earning(detail, where), passes, "; ".join(good) or "-", "; ".join(bad) or "-"))
        why = "It still has a real crowd after %d years. " % (detail["days_old"] // 365) if (detail.get("days_old") or 0) >= 730 else ""
        strong = ", ".join(sorted((k for k in parts if parts[k] >= 0.7), key=lambda k: -WEIGHTS[k])) or "none"
        people += ["", "### %d. %s" % (n, plain(page["name"])),
                   "- [Game page](%s) (its Discord link, if any, shows there when you are signed in), [creator](%s): %s, owner on Roblox: `%s`" % (game_link, link, plain(page["creator"]["name"]), re.sub(r"[^\w .-]", "", owner or "not shown")),
                   "- Strong on: %s. On Roblox's lists now: %s." % (strong, ", ".join("%s #%d" % kv for kv in where.items()) or "none"),
                   "", "> " + MESSAGE.format(name=spoken(page["name"]), why=why).replace("\n", "\n> ")]
    out += ["", "**What this is not:** every game in the band. Only games on one of Roblox's charts are seen, and only %d of the %d left by the first cuts were looked at closely. A dash under Warnings means no word matched, not that it is clean." % (looked, len(rows))]
    if MISSED:
        out += ["", "**Some pages did not answer (%s), so games or owners may be missing. Run it again in ten minutes.**" % ", ".join(sorted(set(MISSED)))]
    out += ["", "## What was cut", ""] + ["- %s: %d" % row for row in counts]
    text = "\n".join(out)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "shortlist-%s.md" % time.strftime("%Y-%m-%d"))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text + "\n" + NOTES + "\n## The owners, and a first message for each\n" + "\n".join(people) + "\n")
    print(text)
    print("\nwritten: %s   (RoTerminal calls left today: %d)" % (os.path.relpath(path, common.ROOT), calls_left()))


def check(args):
    for game in args.games:
        detail = roterminal(str(game))
        if not detail:
            print("%s: no answer (calls left today: %d)" % (game, calls_left()))
            continue
        score, parts = lasting(detail)
        trend = detail.get("momentum") or {}
        print("%3d  %-34s %s" % (round(score), plain(detail["name"])[:34], "  ".join("%s %.2f" % kv for kv in parts.items())))
        print("     7-day average %s, week %s%%, %s days old, %s" % (trend.get("average_last_7_days"), trend.get("against_the_7_days_before"), detail.get("days_old"), detail.get("link")))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    f = sub.add_parser("find")
    f.add_argument("--low", type=int, default=1000)
    f.add_argument("--high", type=int, default=20000)
    f.add_argument("--look", type=int, default=40, help="games not seen in the last four days to look at closely, one RoTerminal call each")
    f.add_argument("--pages", type=int, default=0, help="pages of RoTerminal's screen added to Roblox's charts, one call each (mostly games under two months old)")
    f.add_argument("--top", type=int, default=30)
    f.add_argument("--min-age", type=int, default=120)
    f.set_defaults(run=find)
    c = sub.add_parser("check")
    c.add_argument("games", nargs="+")
    c.set_defaults(run=check)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
