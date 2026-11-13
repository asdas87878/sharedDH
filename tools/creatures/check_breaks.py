# Who breaks props (Config.breaks): a Tank, a Breaker, or a giant (its model's box, width x height x length from
# src/shared/Creatures/<Id>.json, at least Config.Props.GiantVolume cubic studs); a FishStats row's `Breaks = true/false`
# wins. Prints the table for docs/design/archetypes.md ("Who breaks props"). Run: python tools/creatures/check_breaks.py
import re, json, glob, os
ROOT = __file__.replace("\\", "/").rsplit("/tools/", 1)[0] + "/"
s = open(ROOT + "src/shared/Config.luau").read()
giant = float(re.search(r"GiantVolume = ([\d.]+)", s).group(1))
stats = {m[0]: (m[1], m[2]) for m in re.findall(r'^\t(\w+) = \{ Speed = \d+, Archetype = "([^"]*)"(?:, Breaks = (true|false))? \}', s, re.M)}
rows = []
for f in glob.glob(ROOT + "src/shared/Creatures/*.json"):
    d = json.load(open(f)); i = os.path.basename(f)[:-5]
    x, y, z = d["Size"]; a, forced = stats.get(i, ("", ""))
    ids = a.split(",") if a else []
    why = [w for w, ok in (("Tank", "Tank" in ids), ("Breaker", "Breaker" in ids), ("giant", x * y * z >= giant)) if ok]
    breaks = bool(why) if not forced else forced == "true"
    if forced: why = ["Breaks = " + forced]
    rows.append((x * y * z, d["Name"], d["Tier"], d["Zone"], (x, y, z), a, breaks, why))
rows.sort(reverse=True)
print(f"GiantVolume {giant:.0f}; {sum(r[6] for r in rows)} of {len(rows)} fish break props\n")
print("| Creature | Rarity | Land | Box (w x h x l, studs) | Cubic studs | Why it breaks |\n|---|---|---|---|---|---|")
for v, name, tier, zone, (x, y, z), a, breaks, why in rows:
    if breaks: print(f"| {name} | {tier} | {zone} | {x:.0f} x {y:.0f} x {z:.0f} | {v:,.0f} | {', '.join(why)} |")
print("\nThe biggest that go through:")
for v, name, tier, zone, (x, y, z), a, breaks, why in [r for r in rows if not r[6]][:8]:
    print(f"  {name} ({tier}, land {zone}): {v:,.0f}")
