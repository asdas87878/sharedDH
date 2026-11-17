# The submarine, scripted playtests (2026-11-17)

Of [the submarine](../design/submarine.md), built the same evening. **Run by script in Hugo's Studio, not played by
hand.** The driver puts the player in the water off the start strip with a land picked; nothing is pressed, so the
fling's hop lands by the hands-off pull-in (`Jump.AutoGrab` 2). Files: `submarine/drive.luau` (the driver, run with
`node ~/Projects/studio-runner/studio-run.mjs --ctx server docs/playtests/submarine/drive.luau LAND=5 'FISH=""'`),
`submarine/clip.sh` and `submarine/gif.py` (the clips), and one log per run (`submarine/land*.log`: state, phase,
place and speed every 0.25 s).

| Land | Drop-off | Code | The run (s) | Top speed (studs/s) | Water to riding (s) | Landed on |
|---|---|---|---|---|---|---|
| 2 Coral Reef | Fling | first build | 3.9 | 513 | 11.2 | a Tiny Boxfish |
| 5 Open Blue | Fling | first build | 18.3 | 559 | **missed**: left floating, the nearest fish 200 studs off | nothing |
| 5 Open Blue | Fling | + the drop point stocked, the run capped at 10 s | 10.0 | about 1,100 | (not logged) | a Huge Electric Ray |
| 7 Midnight | Fling | the same | 10.0 | 1,668 | 17.3 | a Tiny Hammerhead Shark |
| 10 The Underworld | Fish (a Big Gold Reef Shark) | the same | 9.8 | 2,530 | 14.9 (0.8 after the drop) | its own Reef Shark |
| 3 Kelp Forest | Fish (a Big Rainbow Sergeant Major) | final (+ the path round big props) | 8.4 | 581 | 13.4 (0.8 after the drop) | its own Sergeant Major; still riding 6 s later, counted as tamed already (no second catch) |
| 5 Open Blue | Fling | final | 10.0 | 1,063 | 17.3 (3.2 after the drop: the hop's glide, then the hands-off pull-in) | a Hammerhead Shark |

(The table's logs are in `submarine/`; the first two land-5 runs were overwritten, their numbers are from the run's
output.)

- Every phase came in order on every run: Approach 1.8 s, Pickup 1.3 s, the run, Arrive 0.8 s, the drop.
- **Found and fixed while testing:** the fling missed in land 5 (the drop point had too few fish: now `Sub.Stock` 6
  are put just ahead of it 2.5 s before); the run to land 5 took 18 s (now at most `Sub.MaxRide` 10 s, faster for far
  lands); the run's camera fell 150 studs behind (it eased its place in the world; now its offset from the sub); the
  rider broke the surface at the pick-up (`Sub.Under` 17); the sub went straight through a big prop (the path now
  bends round big things as the herd does); the camera started inside the hub's floor (it now cuts to its first
  framing under the splash).
- **Still seen:** at the pick-up the gate's posts stand close, and the camera is pulled in against one for a moment
  (the fish clip, sixth frame). The tumble's top breaks the surface for a moment.
- **Studio trap found:** every new script file arrived in Studio **twice** (also `BestService` and `HookController`,
  others' files): two Rojo sessions each adding new files, it seems. Two `SubService`s each kept their own players, so
  the sub never came. The identical copies were removed in Edit; one copy each now, and syncing still reaches it.
  Hugo's place had two `HookController`s before this, i.e. two hooks.

Pictures: [the fling](../attachments/submarine-fling.gif) ([frames](../attachments/submarine-fling-sheet.jpg)),
[the fish drop-off](../attachments/submarine-fish-dropoff.gif) ([frames](../attachments/submarine-fish-sheet.jpg)).
