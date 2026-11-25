"""Pack the chunk library for stack.py, cost.py and draw.py: python tools/endless/pack.py <folder with today/ and chunks/> <out.pkl>"""
import os
import pickle
import sys

import chunks as ch

root, out = sys.argv[1:3]
pickle.dump((ch.purpose(os.path.join(root, "chunks")), ch.today(os.path.join(root, "today"))[0]), open(out, "wb"))
