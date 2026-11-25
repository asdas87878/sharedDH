"""The endless Underworld's pictures: python tools/endless/draw_under.py <under.pkl> <out folder>"""
import pickle
import sys

import numpy as np

import chunks as ch
import draw as D
import stack as st

made, _ = pickle.load(open(sys.argv[1], "rb"))
O = sys.argv[2].rstrip("/") + "/"


def run_of(seed, n):
    return [dict(p, look=9, boss=False) for p in st.stack(made, seed, n, "spiral", st.START, st.H0)]


for seed in (1, 2, 3):
    r = run_of(seed, 34)
    D.plan(made, r, 0.11).save(O + f"u-top-{seed}.png")
    D.elevation(made, r, 0.11).save(O + f"u-side-{seed}.png")
r = run_of(1, 12)
for k in (2, 4, 5, 7):
    D.rider_view(made, r, k, repaint=False, look=9).save(O + f"u-eye-{k}.png")
    D.rider_view(made, r, k, back=700, repaint=False, look=9).save(O + f"u-far-{k}.png")
