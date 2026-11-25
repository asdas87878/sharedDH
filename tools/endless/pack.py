"""Pack the chunk library for stack.py, cost.py and draw.py: python tools/endless/pack.py <folder with today/ and chunks/> <out.pkl>

  python tools/endless/pack.py <folder with under/> <out.pkl> under     the Underworld's own (build_lane.py under)"""
import os
import pickle
import sys

import chunks as ch

root, out = sys.argv[1:3]
if sys.argv[3:] == ["under"]:
    lib = ch.purpose(os.path.join(root, "under"))
    for c in lib:
        c["land"] = 9  # whichever land's place it was built in, it wears the Underworld's kit
    pickle.dump((lib, []), open(out, "wb"))
    sys.exit()
pickle.dump((ch.purpose(os.path.join(root, "chunks")), ch.today(os.path.join(root, "today"))[0]), open(out, "wb"))
