"""The endless study's costs, counted from the boxes: python tools/endless/cost.py <chunks.pkl>"""
import pickle
import sys

import numpy as np

import chunks as ch
import stack as st

made, today = pickle.load(open(sys.argv[1], "rb"))
n = np.array([len(c["K"]) for c in made])
t = np.array([c["X"].sum() for c in made])
print("a chunk: boxes", n.min(), round(n.mean()), n.max(), "surface pictures", t.min(), round(t.mean()), t.max())
far = np.array([(c["K"] == ch.KINDS.index("barrier")).sum() for c in made])
prop = np.array([(c["K"] == ch.PROP).sum() for c in made])
print("of which props", round(prop.mean()), "barrier", round(far.mean()))
small = []
for c in made:  # props whose biggest box is small: the dressing a fast rider never reads
    g = c["G"][c["K"] == ch.PROP]
    size = c["S"][c["K"] == ch.PROP].max(1)
    big = {}
    for a, b in zip(g, size):
        big[a] = max(big.get(a, 0), b)
    small.append(sum(1 for a in g if big[a] < 7))
print("boxes in props with no box over 7 studs (could be dropped):", round(np.mean(small)))
for back, ahead in ((400, 1300), (600, 2000)):
    win = []
    for seed in range(1, 21):
        run = st.stack(made, seed, 60)
        for s in np.arange(2400, 60 * 1200 - 4000, 300.0):
            i0, i1 = int((s - back) // 1200), int((s + ahead) // 1200)
            win.append((sum(len(made[run[i]["shape"]]["K"]) for i in range(i0, i1 + 1)), i1 - i0 + 1, sum(made[run[i]["shape"]]["X"].sum() for i in range(i0, i1 + 1))))
    w = np.array(win)
    print(f"window {back} behind, {ahead} ahead: boxes mean {w[:, 0].mean():.0f} max {w[:, 0].max()} chunks {w[:, 1].mean():.2f} pictures {w[:, 2].mean():.0f}; 8 riders apart {8 * w[:, 0].mean():.0f}; made a second at {st.PACE:g}: {n.mean() * st.PACE / 1200:.0f}")
# what server numbers a chunk needs: way points every 24 studs (x, y, z, half left, half right), 2 bytes each, with the big props
print("numbers a chunk: way", 51 * 5, "values")
lib = n.sum()
print("library of 18:", lib, "boxes; at about 23 bytes a box as packed text:", round(lib * 23 / 1e6, 2), "MB")
