# The trailer mode

For filming the game page's video the way [Ride a Dino's](../reference/ride-a-dino-trailer.md) is framed (the user,
2026-11-25: "save and then start full ver"). Studio only, `Config.Trailer` (On 0 turns it off); in a live game it does
nothing. Nothing it does is kept: it ends with Play, and saving in Studio is the stand-in store.

- **J** in Play runs all 20 shots. `workspace:SetAttribute("TrailerRun", "5")` (or "3,5") on the client runs some.
- The rides, the herd, the hops and the screens are the game's own. Only the camera and the steering are scripted.
- Between shots the screen is a pink slate with the shot's number in six squares; `tools/trailer/cut.py` finds it.
- A shot is one entry of `SHOTS` in `TrailerController` (camera from, to; fish, size, land, how far in; hop; screens).
- A giant is kept as much higher over the floor as its belly needs (`State.RideLift`, 0 in the game).

## Recording (OBS)

1. Studio: File, Studio Settings, Rendering, Edit Quality Level 21. Play in a full window (F11), nothing over it.
2. OBS: the Studio window cropped to the game view, 1920x1080, 60 fps, no sound.
3. Record, Play, wait for the dock, press **J** and take your hands off. It ends on a slate, then the dock.
4. `python tools/trailer/cut.py <recording> work/trailer/trailer.mp4` (and `--music song.mp3`).

A shot filmed again later in the same recording replaces the first. The cut's lengths, speeds and blur whips are the
table `CUT` at the top of the script.
