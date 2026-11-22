"""Makes (or makes again) the folder the user drags into ChatGPT for the fish icons: research/fish_icons_chatgpt/
(private: its style sheet is the reference game's art, and git never commits research/). See its PROMPTS.md.
  1_test/            ten fish of every shape, NN_<Id>.png at 1024 px, for the first round
  2_batches/batch_NN every other fish, ten to a batch, in rarity order
  plan.json          which fish is which number (tools/ui/icon_sheets.py align reads it)
The style sheet (0_style_reference/), PROMPTS.md and anything saved in 3_results/ are kept as they are.
usage: python tools/ui/chatgpt_pack.py      (after tools/ui/export_portraits.py has made the renders)
"""
import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACK = os.path.join(ROOT, "research", "fish_icons_chatgpt")
RENDERS = os.path.join(ROOT, "art", "ui", "fish_icons", "renders")
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
# the first round: one of every shape (a fish here that is gone from the renders is left out)
TEST = ["Megalodon", "Clownfish", "Angelfish", "MantaRay", "Octopus", "MorayEel", "Pufferfish", "Elasmosaurus",
        "SeaTurtle", "Hellmaw"]


def put(folder, names):
    if os.path.exists(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    for k, name in enumerate(names):
        im = Image.open(os.path.join(RENDERS, name + ".png")).convert("RGB").resize((1024, 1024), Image.LANCZOS)
        im.save(os.path.join(folder, "%02d_%s.png" % (k + 1, name)))


def main():
    have = sorted(n[:-4] for n in os.listdir(RENDERS) if n.endswith(".png"))
    tiers = {}
    folder = os.path.join(ROOT, "src", "shared", "Creatures")
    for f in os.listdir(folder):
        if f.endswith(".json"):
            with open(os.path.join(folder, f), encoding="utf-8") as h:
                tiers[f[:-5]] = json.load(h).get("Tier", "Secret")
    test = [n for n in TEST if n in have]
    rest = sorted((n for n in have if n not in test),
                  key=lambda n: (ORDER.index(tiers.get(n, "Secret")) if tiers.get(n, "Secret") in ORDER else 9, n))
    batches = [rest[i:i + 10] for i in range(0, len(rest), 10)]
    os.makedirs(PACK, exist_ok=True)
    put(os.path.join(PACK, "1_test"), test)
    if os.path.exists(os.path.join(PACK, "2_batches")):
        shutil.rmtree(os.path.join(PACK, "2_batches"))
    for b, names in enumerate(batches):
        put(os.path.join(PACK, "2_batches", "batch_%02d" % (b + 1)), names)
    os.makedirs(os.path.join(PACK, "3_results"), exist_ok=True)
    with open(os.path.join(PACK, "plan.json"), "w", encoding="utf-8") as h:
        json.dump({"test": test, "batches": batches}, h, indent=1)
    print("%d test, %d in %d batches (last %d)" % (len(test), len(rest), len(batches), len(batches[-1]) if batches else 0))


if __name__ == "__main__":
    main()
