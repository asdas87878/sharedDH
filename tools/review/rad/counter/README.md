# The reference's distance counter, read every frame (feel review 3)

From feel review 3's helper (2026-11-19): reads Ride a Dino's distance counter (the metres under the head icon on the
zone bar) on every frame around each hop of the user's recordings, for the hook's speed against riding speed.
The recordings are private (`D:\program files for meideos\`): keep every frame, strip and sheet out of the repo.

Run from a scratch folder outside the repo, with `RAD_REVIEW` set to a folder that holds feel review 1's
`rad/data/cycle.json` (the hop times, from `../cycle.py`); the scripts write `RAD_REVIEW/hook/data/`.
1. `dump.py`: one pass per video, the label strip of every frame from 1.5 s before each jump.
2. `templates2.py`: digit templates from the strips (uses `ocr2.py`).
3. `read2.py`: every frame's reading.
4. `hops2.py`: the per-hop numbers (pull-in metres, average and peak speed, against riding speed, the gap at the
   throw). Two frames read by eye and the rope's arrival frames are written in it.
Check a sample of readings by eye against the frames before trusting a new recording.
