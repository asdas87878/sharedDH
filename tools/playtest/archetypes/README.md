# The archetypes' scripted playtest

The two temporary scripts of [the playtest of 2026-11-12](../../../docs/playtests/2026-11-12-archetypes.md), kept to run again.
Studio only, through `~/Projects/studio-runner` (its README says how; never Roblox's Studio MCP).

```sh
python3 tools/playtest/archetypes/mk_install.py        # writes /tmp/a2/install.luau and /tmp/a2/remove.luau
node ~/Projects/studio-runner/studio-run.mjs /tmp/a2/install.luau    # in Edit mode: adds A2Test and A2Driver
node ~/Projects/studio-runner/studio-run.mjs play      # wait about 20 s
tools/playtest/archetypes/cmd.sh speeds                # a phase: speeds, eat, frenzy, props, combo, drain, land, hop, steer
tools/playtest/archetypes/log.sh                       # the log so far
node ~/Projects/studio-runner/studio-run.mjs stop      # wait until `status` shows server 0
node ~/Projects/studio-runner/studio-run.mjs /tmp/a2/remove.luau     # takes both scripts out again
```

`client.luau` is the driver (it rides, steers by turning the view, hops, and reports); `server.luau` measures from
the server's side and keeps the log in `ServerStorage.A2Log`. Run one phase at a time and wait for its `END` line.
