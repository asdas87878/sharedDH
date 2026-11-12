#!/bin/sh
# cmd.sh <phase>: tell the driver to run a phase (a counter keeps the value changing)
node ~/Projects/studio-runner/studio-run.mjs --ctx server --code "game:GetService('ReplicatedStorage').A2Cmd.Value = '$1 ' .. tostring(os.clock()) return 'sent $1'"
