# Phone check: first numbers (2026-11-25)

Read in Studio on the user's PC (game code chat), one player, nothing changed. **Not a phone, and no frame rate or draw
calls:** Studio's 3D view was not redrawing (the scene's counts stood still), and its total memory (about 3.4 GB) is the
editor's own, so neither says anything about a phone.

| What | Number |
| --- | --- |
| Parts in the place | 108,812 (lane 104,286), 82,102 casting a shadow, 74,700 solid |
| Pictures on parts (Decals, Textures) | 54,060 |
| Parts on the client: hub, land 1, 2, 4, 7 (teleported, one after another) | 14,460, 19,355, 25,946, 27,912, 28,522 |
| BaseParts memory over that | 392 to 435 MB (Studio's tag, may count the editor's copy too) |
| Streaming | radius 64 to 2400, out `Opportunistic`, integrity `PauseOutsideLoadedArea` |
| Fish models (ReplicatedStorage, never streamed) | 88 kinds, 1,445 meshes, 1,440 different |
| The game's own script memory | client 14 MB, server 12 MB |
| 2D draw calls at the hub, no window open | 181 (215 to 243 in the lands) |
| The HUD | 255 pieces shown, 32 of them ViewportFrames holding fish pictures; Submarine shop 9 more kept built |
| Sandbox panel (Studio) | 8,784 of 13,479 gui pieces, hidden |
| Screen turn | `Sensor`: the game can turn upright on a phone |
| Lighting | Realistic style, quality put first, shadows, two Blooms, SunRays, DepthOfField, Atmosphere in the place |
