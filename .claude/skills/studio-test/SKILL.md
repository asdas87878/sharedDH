---
name: studio-test
description: How to drive Roblox Studio for Ride a Fish without wasting time or tokens - taking Studio, syncing src/ into the place, playing, running a scripted check, reading the console, captures, stopping and resetting, and the traps that cost hours before. Load it before any Studio work, and the studio-tester helper preloads it.
---

# Driving Studio for Ride a Fish

## Before
- **One chat drives each PC's Studio.** Check the Studio column of the "Who has what" table at the top of
  `docs/Sessions.md` (read only its first 80 lines). Write "has it" in your row; clear it when done.
- The studio id comes from the Roblox Studio connector's `list_roblox_studios`. If the connector fails,
  `C:\Users\blast\RpgGame\tools\studio\studio_mcp.py` reaches Studio directly.

## Getting the code in
- With Rojo serving (`rojo serve`) and the plugin connected, saves sync by themselves.
- Without it: `python tools/studio/sync_src.py <studio_id>` puts all of `src/` in (Edit mode only); for a few scripts,
  `python tools/studio/push_scripts.py . work/push.luau <src path>=<Studio path> ...` then
  `node tools/studio/run_luau.js <studio_id> work/push.luau`. Long Luau files always go through `run_luau.js`.
- **Wait a few seconds after stopping Play before syncing**, or the code goes into the game that is shutting down. Read one
  changed script back in Edit before playing.

## Checking
- Prefer numbers to pictures. A scripted check (`tools/studio/<task>_check.py install | run | remove`, logs in
  `work/<task>/`) or a log script (`tools/studio/ride_log.luau`, `oxygen_check.luau`, `herd_stream_test.py`) says more
  than a capture, and costs a fraction of the tokens. Write a new check as a script in `tools/studio/` when a piece will be
  checked more than once, so the next check is one command.
- Read the console with the connector's `get_console_output`, and filter to our own scripts' lines.
- Hugo's PC runs Play through `~/Projects/studio-runner/studio-run.mjs`; this PC uses the connector's `start_stop_play`.

## Captures (expensive: each one stays in the chat for good)
- Only when a result is visual and being judged, or the user asks. One capture per message (two together cost minutes).
- Blank or dark captures, or 15 fps, mean Studio's window is covered: ask the user to bring it up. After moving the camera,
  wait about 7 seconds or terrain shows coarse.
- Save pictures under `work/` (or `docs/attachments/` when they're the record) and name the path; look at one, not all.

## After
- **After every scripted stop**, in Edit, inside a `task.delay`: `UserInputService.MouseBehavior =
  Enum.MouseBehavior.Default` and the camera's `CameraType` to `Fixed`; then read both back. Otherwise the user's cursor
  drags the view about.
- Don't save the place unless asked. Clear "has it" in Sessions.
- Other traps: the glb importer turns each mesh 180 degrees about its centre; a Model with a PrimaryPart pivots on it and
  ignores WorldPivot; terrain sits about 2 studs above the written height and past about 1,024 studs doesn't load on the
  client.
