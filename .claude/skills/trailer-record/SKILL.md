---
name: trailer-record
description: "Films the Ride a Fish game-page video by itself: syncs the code, plays, runs all 20 trailer shots twice, records the second run, looks at every shot and cuts the video. Use it when the user or Hugo says \"start the recording sequence\", \"record the trailer\", \"film the trailer\" or /trailer-record. Made for Hugo's Linux PC; works on the Windows one too."
---

# The recording sequence

Saying "start the recording sequence" is the go-ahead for everything below except the three things under "Ask first".
Keep Hugo told in one line per step. Background: `docs/design/trailer.md`. Load `studio-test` first (who has Studio).

## Ask first (one message, then wait)
- Studio open on the game's place, in Edit, nobody else in a Play, its window full size on the main screen with nothing over
  it (no explorer or output covering the game view; the bigger the view, the sharper the video), and
  Studio Settings, Rendering, Edit Quality Level at 21.
- Hands off the PC until you say done (two runs of all the shots).
- Installing anything that is missing (`pip install opencv-python numpy imageio-ffmpeg`; on Linux a recorder, `ffmpeg` for
  X11 or `gpu-screen-recorder` for Wayland): say what and from where, wait for yes.

## Run
1. `git pull`, then in Edit: on Hugo's PC `python tools/studio/catch_up.py runner` (the code, seahorses, creatures, subs and the
   user's hand changes; ask Hugo to save after; needs the runner plugin connected), on the Windows one
   `python tools/studio/sync_src.py <studio_id>`. Read one changed script back in Edit: `TrailerController` must hold
   `TrailerStage`'s sender, `task.spawn(ask, "Now", text)`. If not, the sync did not land: stop and say so.
2. `python tools/trailer/record.py probe`. It names the recorder that works and its frames (about 240 in 4 s is 60 a second).
   None works: use OBS (below).
3. `python tools/trailer/record.py all` in the background, its output in `work/trailer/record.log`. It plays, runs every shot
   once to load the models, runs them again recorded, stops Play, gives the mouse back, makes `work/trailer/take2.jpg` (every
   shot's start, middle and end) and cuts `work/trailer/trailer.mp4`. "STUCK" or "problems:" in the log: read what it names.
4. Look at `work/trailer/take2.jpg` once and judge every shot: the rider is the user's avatar (`Config.Trailer.Avatar`); the right fish in the
   right land; nothing in the way of the hero; no fish through the floor; nothing half loaded; no black boards, arrows or
   banners. Never yet seen right: 9 (tank), 10 and 11 (seahorse), 13 and 14 (Kelp Wyrm, Hellmaw), 16 (fuse), 17 (the
   submarine shop, not Auras), 18 to 20 (giants).
5. Fix what is off in `SHOTS` (`src/client/Controllers/TrailerController.luau`; one entry a shot), sync, and film those again:
   `record.py play`, `record.py take work/trailer/fix.mkv --shots 9,11` (twice: the first loads), `record.py stop`,
   `record.py sheet work/trailer/fix.mkv`. Then run step 3 again for one clean take. Two rounds at most; then say what is left.
6. Show Hugo `trailer.mp4`, with one line on each shot that is not right. Commit fixes to `SHOTS` and a Handoff line, and push.
   The videos stay in `work/` (too big for the repo): Hugo sends `trailer.mp4` and `take2.mkv` to the user.

## With OBS instead
Hugo sets OBS to the whole screen, 1920x1080 or more, 60 fps, no sound. `record.py play`, wait 25 s, `record.py take
work/trailer/x.mkv --no-record` (loads everything), tell Hugo to press record and wait for "recording", the same `take` again,
tell Hugo to stop, `record.py stop`. Then `record.py sheet <their file>` and `python tools/trailer/cut.py <their file>
work/trailer/trailer.mp4`. The cut finds the game view in the screen by its pink slate.

## Never
Save or publish the place, stop a Play that is not yours, or upload the video: those are the user's and Hugo's to say.
Music: only a song the user gives (`cut.py ... --music song.mp3`).
