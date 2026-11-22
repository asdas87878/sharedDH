# Per-frame jump-button state from the dumped crops.
#   U = up arrow (riding), D = down arrow (in the air), pD / pU = the button's pressed look (dark arrow on a light
#   disc: shown for ~4-6 frames on each press), g = greyed-out down arrow (contrast about half: no dive possible),
#   ? = no button / unreadable.
# Templates: built from the video itself (bootstrapped from the 35 s ride's templates, then re-averaged on this video's
# confident frames).
import numpy as np, sys, json, cv2
sys.path.insert(0, __file__.rsplit("\\", 1)[0] if "\\" in __file__ else ".")
from btn_feat import feats, unit, AX0, AX1, AY0, AY1

def amp(crops, sigma=5.0):
    out = np.empty(len(crops), np.float32)
    for i, c in enumerate(crops):
        g = cv2.cvtColor(c, cv2.COLOR_BGR2GRAY).astype(np.float32)
        hp = g - cv2.GaussianBlur(g, (0, 0), sigma)
        f = hp[AY0:AY1, AX0:AX1]; out[i] = np.sqrt(((f - f.mean()) ** 2).mean())
    return out

def classify(k, data="../data", boot=True):
    a = np.load(f"{data}/btn_{k}.npy"); F = feats(a); A = amp(a)
    TU, TD = np.load(f"{data}/tmpl_1504.npy")
    for it in range(2 if boot else 0):
        su = (F * TU).sum((1, 2)); sd = (F * TD).sum((1, 2))
        mu = (su > 0.85) & (su > sd + 0.3); md = (sd > 0.85) & (sd > su + 0.3)
        # pressed frames are the negatives: fold them in with a sign flip
        pu = (su < -0.85) & (su < sd - 0.3); pd = (sd < -0.85) & (sd < su - 0.3)
        TU = unit(np.concatenate([F[mu], -F[pu]]).mean(0)); TD = unit(np.concatenate([F[md], -F[pd]]).mean(0))
    np.save(f"{data}/tmpl_{k}.npy", np.stack([TU, TD]))
    su = (F * TU).sum((1, 2)); sd = (F * TD).sum((1, 2))
    lab = np.full(len(F), "?", dtype="<U2")
    lab[(su > 0.6) & (su > sd + 0.3)] = "U"
    lab[(sd > 0.6) & (sd > su + 0.3)] = "D"
    lab[(su < -0.6) & (su < sd - 0.3)] = "pU"
    lab[(sd < -0.6) & (sd < su - 0.3)] = "pD"
    return lab, su, sd, A

if __name__ == "__main__":
    for k in sys.argv[1:]:
        lab, su, sd, A = classify(k)
        np.save(f"../data/lab_{k}.npy", np.stack([su, sd, A]))
        json.dump([[round(i / 30, 4), str(l), round(float(u), 3), round(float(d), 3), round(float(x), 2)] for i, (l, u, d, x) in enumerate(zip(lab, su, sd, A))], open(f"../data/lab_{k}.json", "w"))
        runs = []
        for i, l in enumerate(lab):
            if runs and runs[-1][0] == l and runs[-1][2] == i - 1: runs[-1][2] = i
            else: runs.append([l, i, i])
        print(k, {s: int((lab == s).sum()) for s in ["U", "D", "pD", "pU", "?"]})
        print(" ".join(f"{l}{a/30:.2f}-{b/30:.2f}" for l, a, b in runs))
        print()
