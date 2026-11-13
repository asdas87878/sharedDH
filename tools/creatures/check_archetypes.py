# Checks Config.FishStats: every archetype id is a known one, and the counts meet the targets of 2026-11-13
# (docs/design/archetypes.md, "Fewer abilities"). Run: python tools/creatures/check_archetypes.py
import re, sys, collections
ROOT = __file__.replace("\\", "/").rsplit("/tools/", 1)[0] + "/"
s = open(ROOT + "src/shared/Config.luau").read()
rows = re.findall(r'^\t(\w+) = \{ Speed = (\d+), Archetype = "([^"]*)" \}, -- (\w+):', s, re.M)
blk = s[s.index("Config.Archetype = {"):]
known = set(re.findall(r'^\t(\w+) = \{', blk[:blk.index("\n}")], re.M))
print("known ids:", sorted(known), "| fish:", len(rows))
c = collections.Counter(); n = collections.Counter(); by = collections.defaultdict(collections.Counter); bad = []
for name, sp, a, rar in rows:
    ids = [x for x in a.split(",") if x]
    bad += [(name, i) for i in ids if i not in known]
    if "Frenzy" in ids and "Predator" not in ids: bad.append((name, "Frenzy without Predator"))
    n[len(ids)] += 1; by[rar][len(ids)] += 1
    for i in ids: c[i] += 1
    if ids: print(f"  {name:18} {rar:10} {sp:>4}  {a}")
print("by id:", dict(c)); print("by count:", dict(n))
for r in ["Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"]: print(" ", r, dict(by[r]))
ok = (len(rows)==82 and not bad and n[0]>=45 and c["Predator"]<=10 and c["Breaker"]<=8 and n[2]<=6 and n[3]<=2 and n[4]==0
      and by["Common"][0]==7 and by["Uncommon"][0]==10)
print("bad:", bad); print("TARGETS MET" if ok else "TARGETS NOT MET"); sys.exit(0 if ok else 1)
