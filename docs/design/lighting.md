# Lighting

The look of the light, from the tutorial video the user sent on 2026-11-11 (a 50-second TikTok by kh_studios). The user
likes its vibrant look. Built the same day by the game-code chat ([Sessions](../Sessions.md)). **Not seen by anyone
yet:** Studio's window wasn't being drawn when it went in, so it was checked by its numbers in play, not by eye.

## What the tutorial does
Read from its frames and its voice.

| Step | Where | From | To |
|---|---|---|---|
| 1 | Lighting, Ambient | 70, 70, 70 | 124, 155, 184 |
| 2 | Lighting, Brightness | 3 | 4 |
| 3 | Lighting, LightingStyle | Soft | Realistic |
| 4 | Lighting, OutdoorAmbient | 70, 70, 70 | 157, 178, 255 |
| 5 | Lighting, ShadowSoftness | 0.2 | 1 |
| 6 | Bloom, Size | 24 | 56 |
| 7 | A new ColorCorrection: Contrast and Saturation | 0 | 0.5 each |
| 8 | ColorCorrection, TintColor | 255, 255, 255 | 245, 234, 255 |
| 9 | A sky from the Toolbox ("choose one that you like") | | the video picks "Anime Sky" by Aschorking |
| 10 | A LocalScript in StarterPlayerScripts | | left out, on the user's word |

Our place's lighting was Roblox's plain start, the same as the tutorial's "before", so the steps apply as they are.

## Toned down
The user, the same day, through the map chat: "a bit too blinded by light so textures are harder to see, maybe tune
that area of the system down artistically". At the tutorial's values the sand floor clipped to white and the studs and
squares vanished on floor and walls (the map chat, from one capture of the hub in Edit mode). The values it tried there,
which keep the vivid sky and bring the textures back, are `Config.Look` now:

| Number | The tutorial | Now |
|---|---|---|
| Brightness | 4 | 2.4 |
| Exposure | 0 | -0.25 |
| Ambient | 124, 155, 184 | 104, 128, 152 |
| OutdoorAmbient | 157, 178, 255 | 128, 146, 200 |
| Bloom: intensity, size, threshold | 1, 56, 2 | 0.5, 40, 2.4 |
| Contrast | 0.5 | 0.2 |
| Saturation | 0.5 | 0.35 |

The tint, the soft shadows, the Realistic style and the sky are unchanged. Judged from one capture of the hub only;
under water it has not been seen.

## Part of the way back
The user, later the same day, through the map chat: the toned-down light is a bit washed out; bring it part of the way
back toward the bright one (its blues and pushed light, without the blinding). `Config.Look` now, a reasoned halfway
point that **nobody has judged by eye** (Studio's window wasn't being drawn for either chat):

| Number | The tutorial | Toned down | Now |
|---|---|---|---|
| Brightness | 4 | 2.4 | 3 |
| Exposure | 0 | -0.25 | -0.2 |
| Ambient | 124, 155, 184 | 104, 128, 152 | 112, 140, 170 |
| OutdoorAmbient | 157, 178, 255 | 128, 146, 200 | 140, 162, 240 |
| Bloom: intensity, size, threshold | 1, 56, 2 | 0.5, 40, 2.4 | 0.7, 48, 2.2 |
| Contrast | 0.5 | 0.2 | 0.35 |
| Saturation | 0.5 | 0.35 | 0.5 |

## A touch down
The user, the same day, to the map chat (which holds these numbers now): "ever so slightly less bright and drowning,
ever so slightly, just a touch". Three numbers moved; the rest are as in the table above.

| Number | Part of the way back | Now |
|---|---|---|
| Brightness | 3 | 2.8 |
| Exposure | -0.2 | -0.25 |
| Bloom intensity | 0.7 | 0.6 |

Pushed to the place and installed in Edit mode. Still not judged by eye by either chat: the user's eye is the test.

## The blue taken out (2026-11-12)
The user, playing: washed out too much; "feel the green more", "see the tone changes more". Measured with swatches in
Studio: a pure green part (83, 214, 100) showed on screen as mint (7, 255, 161). The shade light (OutdoorAmbient)
was nearly as blue as the sky, and the sky tinted every surface at full strength (EnvDiffuse 1), with saturation
on top. Changed, by the map chat (which holds these numbers):

| Number | Before | Now |
|---|---|---|
| Ambient | 112, 140, 170 | 118, 128, 138 |
| OutdoorAmbient | 140, 162, 240 | 150, 158, 170 |
| EnvDiffuse | 1 | 0.35 |
| Contrast | 0.35 | 0.25 |
| Saturation | 0.5 | 0.3 |

Brightness 2.8, exposure -0.25, the bloom, the tint and the sky are as they were. After it the same green shows as
(38, 236, 125), and the hub's part colours were then set so they land on the reference's on-screen colours
([the map's structure](map-structure.md), "The hub's colours"). **What this gives up:** the walls no longer read
blue, and the picture as a whole is a little less vivid. The sky itself is unchanged.

## The script we left out
It runs when your character appears and puts a Roblox `Highlight` on it: a black outline round the whole character, and
a black wash over the body at 20% (FillTransparency 0.8), hidden where something stands in front (DepthMode Occluded).
It is not a pixel effect. A Highlight's outline is about a pixel or two wide and has no smoothing of its own, so it
looks jagged on a low graphics setting, which is likely what read as pixelated. It only ever marks your own character.

## How it is built here
- **The numbers are `Config.Look`** in `src/shared/Config.luau`: every value in the table above, plus the hour, the
  exposure and how much the sky tints things. Colours are three numbers each.
- **While playing, `LookController`** (`src/client/Controllers/LookController.luau`) keeps Lighting, a bloom and a
  colour effect of our own (`LookBloom`, `LookColour`) and the sky at those numbers. It checks four times a second, so
  a change shows at once. The place's own Bloom is switched off while ours is on.
- **In Studio's Edit mode,** `tools/studio/look_install.luau` puts the same numbers on the place, and sets
  LightingStyle to Realistic, which a game script isn't allowed to set. Run it again after changing a number for good:
  `node tools/studio/run_luau.js <studio_id> tools/studio/look_install.luau`. Another place (Hugo's) needs it run once.
- **Skies** are in `ReplicatedStorage.Skies` (Studio-owned), picked by `Look.Sky` in name order: `1 Place` is the sky
  the place had, `2 Anime Sky` is the tutorial's (Creator Store asset 72835926026092: only its Sky was kept; it had
  no scripts). To try another, put a Sky in that folder with a name that sorts where you want it.

## Tweaking it
In Play, press N and find the **Look** rows. Each changes the light at once.

| Row | What it does |
|---|---|
| `On` | 0 shows Roblox's plain lighting and the plain sky, to compare; 1 is the look |
| `Sky` | which sky of the folder: 1 the place's first, 2 the Anime Sky |
| `Brightness`, `Exposure` | the sun's strength; the whole picture lighter or darker |
| `Contrast`, `Saturation`, `ColourBrightness` | the vibrant part: both start at 0.5, which is strong |
| `BloomIntensity`, `BloomSize`, `BloomThreshold` | the glow round bright things |
| `ShadowSoftness`, `ClockTime`, `Latitude` | the shadows' edge, and where the sun stands |
| `EnvDiffuse`, `EnvSpecular` | how much the sky colours everything |
| `AmbientR/G/B`, `OutdoorR/G/B`, `TintR/G/B` | the three colours |

"Copy changes" on the panel lists what you changed; tell a chat the numbers and they go into `Config.Look`.

## Open
- **Nobody has looked at it.** To judge: the hub, the wall faces (the map chat found them blue with a hard shadow at
  the foot under the old light), and under water in the Shallows and a deep land.
- **Under water** the same light is used at every depth for now. The plan for darker, foggier water by land
  ([workout 1](../style/01-going-down.md)) would sit on top of this; Contrast and Saturation at 0.5 may be too much
  down there.
- **Creatures glow:** Neon parts and anything very bright bloom wider now (size 56).
- The map chat and this chat agreed earlier that the game code never sets Lighting. This replaces that: the numbers
  are the game's, and the place is set from them.
