# Props playtest driver (b1, 2026-11-13)

Temporary scripted test of the props: who breaks, who goes through, the approach fade, the flying boxes and the
rebuild. It drives the real controllers and the server's mounts; it replaces no game module. Only the chat that has
Studio runs it (docs/Sessions.md). Use the HTTP runner, never Studio MCP.

```sh
python3 tools/studio/props_b1/install.py
node ~/Projects/studio-runner/studio-run.mjs /tmp/ride-fish-props/install.luau
node ~/Projects/studio-runner/studio-run.mjs play
```

Wait for `driver up` in `game.ServerStorage.B1Log.Value` (read with `--ctx server`), then set a command, with
something that changes each time so the same command can be sent twice:

```luau
game.ReplicatedStorage.B1Cmd.Value = "suite " .. os.clock()
```

- `run <FishId> [hop 0|1] [hold 0|1]`: onto that fish, straight through the nearest tall prop ahead and on. One
  `RESULT` line (the speed kept, what the server said, boxes out, copies flying, how see-through the prop got) and
  one `BACK` line (when the prop was whole and shown again, how far away we were). `hop 1` hops off a second before
  the prop; `hold 1` keeps `Props.RegenRadius` huge for 8 s to see that a prop stays broken with a player near.
- `run <FishId> 0 0 <studs>`: the same fish passing BESIDE the prop, its body about that many studs clear of the
  prop's box. Every run also writes a `SEE` line (p1, 2026-11-13): how see-through the prop was before the body
  touched it, the body's gap when it first turned, touches and shakes, the most see-through while in it, how often
  the see-through turned round (2 is one clean fade and back), and how see-through the flying boxes got near us.
- `cluster <FishId>`: four pillars of the driver's own in a row dead ahead (on the test's machine only), to see
  the shakes stay `Props.ShakeGap` apart.
- `suite`: a Clownfish and a Reef Shark (go through), the Humphead Wrasse (Breaker), Steller's Sea Cow (Tank, with
  the hold), the Molten Megalodon (giant), the hop off a Clownfish and off the Sea Cow, and the Sea Cow again with
  `Props.FadeForBreakers` 1; then a Clownfish beside a prop at 2, 6, 10, 16, 24 and 40 studs, a Reef Shark at 6, and
  the cluster on both. Ends with `SUITE DONE`; a failed check is a `CHECK FAIL` line.
- `suite3` (p3, 2026-11-13: the see-through rework's five points in one go, about 5 minutes): the fish that go
  through head on, the three that break with the game's own `Props.Hang`, the hop off a Clownfish and off the Sea
  Cow, the passes beside, `view`, both clusters, then the three that break with `Hang` 3 so the loose boxes are
  seen at every distance (`DEBRIS` lines: see-through by distance). Ends with `SUITE3 DONE`.
- `view <FishId>`: a box of the driver's own kept on the line from the camera to the fish, then 20 studs off it,
  then on it again: only `Props.ViewNear` can turn it see-through (`SideNear` is pulled in for the test if the
  camera sits that close, and put back).
- Each run's `TOUCH` line: the mode at the touch, the engine's speed at the touch and the least inside the prop,
  the worst frame before and inside, shakes at other props on the way (a run's shakes and touches count only
  those with the body at its own prop), and for a hop its speed across the water against `Config.hopSpeed`.
  `SHAKE`: a touch that gave no shake because `Props.ShakeGap` held it back. `MISS`: the steering never got the
  fish to the prop; the run is done again at another.
- `server_watch.luau`: run once in the playtest's server before a suite
  (`studio-run.mjs --ctx server tools/studio/props_b1/server_watch.luau`); it counts twice a second, into
  `ServerStorage.B1Watch`, anything of the see-through that the server would hold (there must be none).
- `set <Group> <Key> <value>`: a Config number on both machines.

Afterwards: `studio-run.mjs stop`, wait until `status` shows `connected.server` 0, then run
`/tmp/ride-fish-props/remove.luau`.
