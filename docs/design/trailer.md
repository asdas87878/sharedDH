# The trailer mode

For filming the game page's video the way [Ride a Dino's](../reference/ride-a-dino-trailer.md) is framed (the user,
2026-11-25: "save and then start full ver"). Studio only, `Config.Trailer` (On 0 turns it off); in a live game it does
nothing. Nothing it does is kept: it ends with Play, and saving in Studio is the stand-in store.

- **J** in Play runs all 20 shots. `workspace:SetAttribute("TrailerRun", "5")` (or "3,5") on the client runs some.
- The rides, the herd, the hops and the screens are the game's own. Only the camera and the steering are scripted.
- Between shots the screen is a pink slate with the shot's number in six squares; `tools/trailer/cut.py` finds it.
- A shot is one entry of `SHOTS` in `TrailerController` (camera from, to; fish, size, land, how far in; hop; screens).
- A giant is kept as much higher over the floor as its belly needs (`State.RideLift`, 0 in the game).

## Recording (OBS, on Hugo's PC)

The user, 2026-11-25: their PC loads too slowly, so it is filmed on Hugo's. **Not run since the last changes, and never on
Hugo's PC**: run it once and look before recording.

**The short way:** in a Claude chat on Hugo's PC, after a pull, say "start the recording sequence" (the skill `trailer-record`,
`tools/trailer/record.py`): it syncs, plays, films, looks and cuts. By hand:

1. Pull, then sync `src/` into the place (Edit mode); it must be newer than version 523.
2. Studio: Studio Settings, Rendering, Edit Quality Level 21. Play in the full window, nothing over it, not minimised.
3. OBS: the game view only, cropped to 16:9, 1920x1080, 60 fps, no sound.
4. Record, Play, wait for the dock, press **J** and take your hands off. When it ends on the dock press **J again, in the same
   Play**: the first run fetches every model, the second is the one kept (the cut takes a shot's last take).
5. `python tools/trailer/cut.py <recording> work/trailer/trailer.mp4` (and `--music song.mp3`), on either PC (it needs
   `pip install opencv-python numpy imageio-ffmpeg`). The recording itself is too big for the repo: send it another way.

- **The rider is the place owner's avatar** (the user's), whoever films: `Config.Trailer.Avatar`, 0 for one's own.
- A shot waits behind its slate until its land is sent and nothing is left to fetch, at most `Config.Trailer.Load` seconds.
- To look at before recording: 9 (tank), 10 and 11 (seahorse, a new camera side), 13 and 14 (right fish, right land), 16 (fuse),
  17 (the submarine shop, not the auras), 18 to 20 (giants clear of the floor). Fixes go in `SHOTS`.

The cut's lengths, speeds and blur whips are the table `CUT` at the top of the script.
