# Riding steadiness: frame-to-frame picture motion on long rides. Jitter = what is left after a 0.3 s moving average.
# Spectrum of the vertical shift to look for a stride-rate bob (~2.2 steps a second).
import numpy as np, sys
FPS = 30.0
def ma(x, n=9):
    k = np.ones(n) / n; xp = np.pad(x, (n // 2, n // 2), mode="edge"); return np.convolve(xp, k, mode="valid")
def analyse(name, a, t0=None, t1=None):
    if t0 is not None: a = a[(a[:, 0] >= t0) & (a[:, 0] <= t1)]
    ok = np.isfinite(a[:, 1]); a = a[ok]
    t = a[:, 0]; s = a[:, 1]; roll = a[:, 2]; tx = a[:, 7]; ty = a[:, 8]
    out = {"seg": name, "dur": round(t[-1] - t[0], 2)}
    for nm, x in [("tx", tx), ("ty", ty), ("roll", roll), ("logs", np.log(s))]:
        r = x - ma(x)
        out[nm + "_mean"] = round(float(np.mean(x)), 3); out[nm + "_jit_rms"] = round(float(np.sqrt(np.mean(r ** 2))), 3)
        # spectrum (Hann), peak between 0.7 and 6 Hz
        xx = (x - x.mean()) * np.hanning(len(x)); F = np.abs(np.fft.rfft(xx)); fr = np.fft.rfftfreq(len(x), 1 / FPS)
        band = (fr >= 0.7) & (fr <= 6); j = np.argmax(F * band)
        out[nm + "_peakHz"] = round(float(fr[j]), 2); out[nm + "_peak_rel"] = round(float(F[j] / (np.median(F[band]) + 1e-9)), 1)
    return out
segs = []
for k, t0, t1 in [("0230a", 126.4, 130.6), ("0230b", 131.8, 138.9), ("0230c", 149.2, 160.4), ("0230d", 199.2, 206.5), ("0230e", 213.2, 220.3), ("0230f", 235.6, 239.4)]:
    a = np.load(f"../data/moth_{k}.npy"); segs.append(analyse(k, a, t0, t1))
for k, rides in [("1504", [(2.0, 3.0), (12.5, 13.9), (20.4, 21.85), (24.4, 25.65), (27.2, 28.55)]), ("1639", [(2.7, 3.15), (4.47, 4.95)])]:
    a = np.load(f"../data/moth_{k}.npy")
    for t0, t1 in rides: segs.append(analyse(f"{k} {t0}-{t1}", a, t0, t1))
for s in segs: print(s)
