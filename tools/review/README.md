# Feel review tools

For repeating a feel review (the first: [feel review 1](../../docs/reviews/feel-review-1.md)) with the same
measurements, so each pass can be set against the last.

## Ours, in Studio (through the Studio MCP, in Play)
1. Start Play; on the Server, turn the sandbox's safety switches on (`workspace:SetAttribute("SandboxNoFail", true)`,
   `workspace:SetAttribute("SandboxEndlessAir", true)`: they start off since Hugo's change of 2026-11-18), unless the
   run is meant to be under the real rules. Put the player in the water (`p.Character:PivotTo(CFrame.lookAt(
   Vector3.new(3000, 3, 4), Vector3.new(3000, 3, 100)))`) and wait for `State` = "Riding" (the dive's first fish).
2. Server: run `server_sampler.luau` (the state, oxygen, the fish in reach and the place down the lane every 0.1 s).
   Client: run `client_collector.luau` (every hop's line with its time, and the frame rate).
3. Client: press Space every 3.0 s with the MCP's keyboard input, in **legs of 25 presses, each starting with R** (the
   sandbox's reset: back to the lane's start, about s 600, seated on a fish; needs the sandbox on, as it is in Studio).
   A leg covers about s 600 to 8,600, lands 1 to 4. Don't run 100 presses in a row: with the safety switches on, the
   rider rides the whole 30,000-stud lane and off its end, and from land 7 on there are no fish (2026-11-19: the second
   half of such a run bounced on one fish 45 times). Space every 3.0 s comes about half a second after each landing, as
   the recordings' players hop. Hands off in the air. (VirtualInputManager from a script does not reach the game: use
   the MCP's keyboard tool.)
4. Client: `hop_summary.luau` (landed or not, back onto the same fish, runs of it in a row, the hook and touch times,
   the pull-in, the gaps, lock switches, the frame rate; its last line is every hop's time). Server:
   `review_summary.luau` with that last line pasted into its `HOPS` (the hops and the fish in reach by zone, each leg's
   stretch, where the misses were). Studio's server and client share `os.clock`, which is how the two are matched.
5. Studio must be on screen and drawing; at 7 to 14 frames a second every time is coarse.
6. For a lever, edit the place's `Config` source in Edit before Play (a sync puts it back); `Spawn` dials also apply
   live from the N panel (the sea is restocked).
7. How many hops: one 25-hop run's "back onto the same fish" swings from 9 to 48% with the stretch of sea; use 100 a
   setting (four legs).

## The reference, from the user's own recordings (`rad/`)
The recordings are private (`D:\program files for me\videos\`): keep every frame, sound and sheet out of the repo.
- `rad/button.py <video> <t0> <t1> <out.json>`: the jump button every frame (an up arrow riding, a down arrow in the
  air), so each jump and landing to the frame.
- `rad/zoom.py <video> <rows.json>`: the picture's growth frame to frame before each landing (the pull-in's fast part)
  and the snap wide at the touch.
- `rad/sheet.py`, `rad/grab.py`: contact sheets and crops to look by eye.
- `rad/counter/`: the distance counter read on every frame around each hop (feel review 3), for the pull-in's metres
  and its speed against riding speed: [its README](rad/counter/README.md).
- From feel review 1's helper (they read and write `../data/` beside them, so run them from a scratch copy of `rad/`
  with a `data/` folder next to it, never inside the repo): `btn_feat.py` and `classify.py` (the button read with
  templates built from each video, its pressed look included), `events.py` (jumps, throws, landings, misses),
  `cycle.py` and `cycle_stats.py` (the cycle tables), `target_window.py` (when the button greys out: nothing to throw
  at), `motion_h.py`, `cam_hops.py`, `cam_summary.py` (the camera through the cycle), `ride_shake.py`, `rider_size.py`,
  `dupes.py` and the rest (checks).
Run them without `python -I` (OpenCV is in the user's site-packages).
