# Lighting a stylised Roblox game: what the sources say

Up: [Home](../../Home.md).

**Second pass, 2026-11-16: 20 videos read, 17 stretches of frames seen, 28 Reddit threads read.**
**What changed most:** YouTube carries one "simulator lighting" recipe, repeated almost number for number by five
videos since 2023, and it is not the grey one of the DevForum: a pale lilac shade light, a warm yellow on sunlit
faces (ColorShift_Top), a sky tint of 0.3, only a little saturation, no bloom, a lilac fog. So "nobody tints the shade"
and "our tutorial is the outlier" were both wrong, and the warm sun colour we have never tried is the most backed dial.

Read 2026-11-16 by a research agent, on the user's word: how the good-looking games of the simulator and
collect-and-earn kind light their worlds, as rules with numbers we can test. **First pass:** Roblox's creator docs (the
pages carry the date 2026-11-14), six Roblox staff announcements on the DevForum (two of them from this month), a
guest article Roblox asked for, and about fifteen DevForum threads. No video and no Reddit thread could be read that
morning. **Second pass, the same day,** through [the two readers](research-tools.md): the videos' sound turned into
text on this PC (YouTube still refused captions all afternoon), short stretches of frames to read the settings panels,
and Reddit through its public archive. All fifteen videos the first pass listed were read, and five more that the
search turned up. Sixteen were heard whole; four have no voice and were read from their frames. What was heard can
get a number wrong, so a number is marked "seen on a panel" only where the panel was read off a frame; the rest is
marked "heard".

What it is set against: [the lighting we have](../design/lighting.md), [the water](../design/water.md),
[the dark lands](../design/map-feel.md), [the building brief](../style/building-brief.md), and `Config.Look`.

**How sure a rule is** is marked on each: **docs** (Roblox's own pages or a Roblox staff post), **several sources
agree**, **one source**, **seen on a panel in** a video at a time, **heard** (said in a video, panel not read),
**our measurement** (from our own notes), **our guess**.

## 1. The sources

"Recommended?" answers the user's question: do working developers point others at this source, and where was that
seen.

### Roblox's own
| Tag | What | Why it was worth reading |
|---|---|---|
| D-LIGHT | [Lighting, class reference](https://create.roblox.com/docs/reference/engine/classes/Lighting) and [Global lighting](https://create.roblox.com/docs/environment/lighting) | What each property really does, defaults, what is deprecated |
| D-POST | [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects), [ColorGradingEffect](https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect), [TonemapperPreset](https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset) | The effects, and the tone-mapping switch we had not known of |
| D-ATMO | [Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere) | Density, Offset, Haze, Glare, Decay and their traps |
| D-PERF | [Improve performance](https://create.roblox.com/docs/performance-optimization/improve), rendering part | Shadows, lights, see-through layers: what costs and what to switch off |
| D-TUT | [Customize global lighting](https://create.roblox.com/docs/tutorials/curriculums/core/building/customize-global-lighting) and [Enhance outdoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments) | Roblox's own worked numbers for two scenes |
| D-QL | [QualityLevel](https://create.roblox.com/docs/reference/engine/enums/QualityLevel), [Light sources](https://create.roblox.com/docs/effects/light-sources) | What quality levels may switch off; local lights |
| S-UNI | [Unified Lighting is fully live](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512), Roblox Rendering Team, beta 2025-01, live 2025-07-23 | The lighting technology as it is today |
| S-QL | [Increasing the minimum draw distance to 500 studs](https://devforum.roblox.com/t/increasing-the-minimum-draw-distance-to-500-studs-and-other-auto-quality-level-improvements/4977292), staff, 2026-11-05, with the staff replies | Eleven days old. What low quality levels draw now |
| S-SIM | [The Performance Simulator](https://devforum.roblox.com/t/test-graphics-and-memory-on-lower-end-devices-with-the-performance-simulator/4979313), staff, 2026-11-06 | A new Studio tool to see the game as a weak phone draws it |
| S-R120 | [Extended light ranges: 120](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367), staff, 2025-09-23 | What a light's range costs |
| S-RETRO | [Compatibility lighting becomes Retro tone mapping](https://devforum.roblox.com/t/compatibility-lighting-becomes-retro-tone-mapping-sunset-migration/3128560), staff, 2024-08-21 | Where the tone-mapping switch came from |
| S-AND | [Future lighting on Android](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808), staff, 2024-10-29 | What the costly lighting does on phones |
| MCR | [Real world building and scripting optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146), Peter McNeill (MrChickenRocket), a guest article Roblox asked for, 2024-08-20 | A simulator built to run on phones, with budgets. **Recommended: yes.** 1,378 likes, and a later DevForum tutorial quotes it |
| V-OPT | [How to optimize performance on Roblox](https://www.youtube.com/watch?v=VDO_amtWfDw), Roblox Creators, 2025 (transcript from [the earlier study](roblox-videos.md)) | One clear line on lighting and phones |

### Developers, in writing
| Tag | What | By whom, recommended? | Why it was worth reading |
|---|---|---|---|
| BR | [Lighting settings for brainrot games](https://devforum.roblox.com/t/lighting-settings-for-brainrot-games/4326900), 2026-02-03 | VectazePlayz. Not recommended by others; one thankful reply; 2,339 views | A written recipe for our exact genre, with every number |
| SIM | [Cartoon lighting settings?](https://devforum.roblox.com/t/cartoon-lighting-settings/333686), 2019 | Simulation_Studio, a builder. Yes: the most liked reply, and later threads link back to it | A full cartoon recipe, and the warning against too much |
| AM | [Which lighting style is best for cartoon maps?](https://devforum.roblox.com/t/which-lighting-style-is-best-for-cartoon-style-maps/643528), 2020 | Relays a tweet by Bethink, co-creator of Adopt Me. Second hand | Numbers from someone who shipped a hit |
| CL | [Cartoon lighting help](https://devforum.roblox.com/t/cartoon-lighting-help/3602579) (2025), [Lighting settings for cartoony style](https://devforum.roblox.com/t/lighting-settings-for-cartoony-style/2167959) (2023), [a reply on a brainrot game's look](https://devforum.roblox.com/t/how-can-i-get-my-game-in-the-algorithm/4196825) (2026-01) | Assorted developers | What people name first when asked for the simulator look |
| SOLID | [Solid coloring cookbook](https://devforum.roblox.com/t/solid-coloring-cookbook-making-a-solid-colored-game-whilst-keeping-your-sanity/2031219) (2022) and [Make a part's drawn colour match its colour](https://devforum.roblox.com/t/make-rendered-parts-color-match-its-color-property/3844665) (2025) | Two developers | How to make a part show exactly its own colour: the far end of "flat" |
| SMARTY | [The complete guide to lighting](https://devforum.roblox.com/t/the-complete-guide-to-lighting-in-roblox-studio/1876371), 2022, the text of his video | SmartyRBX, a builder of simulator maps. His own post; 39,000 views, thanks still coming in 2026 | A builder's opinion on each effect. His numbers are on the video's panels: V-SM below |
| ZONE | [LightKit+](https://devforum.roblox.com/t/plugin-lightkit-presets-a-daynight-timeline-and-lighting-zones-with-a-runtime-that-ships-in-your-game/4918885) (2026-10), [How did Emergency Hamburg make their lighting](https://devforum.roblox.com/t/how-did-eh-made-their-lightning-system/4602264) (2026-04), [Tweens on Atmosphere are not smooth](https://devforum.roblox.com/t/tweens-on-atmospheredensity-are-not-smooth/3216997) (2024) | A plugin maker; developers reading a shipped game | How lighting by area is built, and what steps when blended |
| TONE | [Colour accuracy for LightInfluence 0](https://devforum.roblox.com/t/color-accuracy-for-lightinfluence-0/4817335) (2026-08), [SmoothPlastic highlights](https://devforum.roblox.com/t/smoothplastic-specular-inconsistent-when-using-humanoids-or-decals-textures/4493911) (2026-03) | Developers reporting problems | What the tone mapper does to flat colours |
| NEON | [Improve neon for low graphics users](https://devforum.roblox.com/t/improve-neon-for-low-graphics-users/30229) (2016, with replies by a Roblox engineer), [Bloom switched off at graphics level 2](https://devforum.roblox.com/t/new-roblox-update-disabled-bloom-on-graphic-level-2-but-it-was-enabled-before/4983523) (2026-11-09, staff reply) | | Neon and bloom on low settings |
| OPT26 | [The definitive tutorial to game optimization](https://devforum.roblox.com/t/the-definitive-tutorial-to-game-optimization-everything-you-need-to-know/4629258), 2026-05 | A developer; 71 likes | A recent sum of the usual advice; some claims are unchecked |
| V-CF | [Your Roblox game lags](https://www.youtube.com/watch?v=YWyJHwynM1M), Crusherfire, 2025 (saved transcript) | No recommendation seen | Shadows and phones, from someone who measures |
| KH | The 50-second TikTok by kh_studios our look came from ([our note](../design/lighting.md)) | Not checked | The starting point; set against the rest below |

### The videos (second pass)
"Heard" is the sound turned into text here. "Frames" is a stretch fetched and looked at; the times are in section 6.

| Tag | Video | Who, when, how big | How it was read | Recommended? |
|---|---|---|---|---|
| V-GM8 | [How to make cartoon lighting](https://www.youtube.com/watch?v=YIyir52FiYo) | Gamer M8 (209,000 subscribers), 2023-02, 289,000 views: the most watched cartoon-lighting tutorial found | Heard whole. Frames refused once | Not by name. But three later videos repeat its numbers and a fourth is a close cousin: the recipe is what spread |
| V-NS | [How to make cartoon lighting](https://www.youtube.com/watch?v=3HcB8wtiERQ) | Noob Scripts (9,300), 2024-08, 23,000 views | No voice. Frames | None seen. A copy of V-GM8, with the panels large and clear |
| V-RB | [Give me 2 minutes and I'll fix your lighting](https://www.youtube.com/watch?v=06KmD8aNJ5o) | Rileybytes (11,900), 2025-04, 61,000 views | Heard whole. Frames | None seen. V-GM8's recipe with a few numbers changed |
| V-WAD | [How to make simulator lighting](https://www.youtube.com/watch?v=vq9wY2eNUh4) | wadskkajdnaskd (207), 2026-06, 750 views. Names Pet Simulator and Grow a Garden as the look | Heard whole. Frames (panel too small to read) | None. V-GM8's recipe again |
| V-VH | [How to make cartoony lighting](https://www.youtube.com/watch?v=PrVFNZOYpfo) | VHAero (3,000), 2024-11, 2,000 views | Heard whole. Frames | None. Says himself he is no expert |
| V-LEN | [Stylized lighting tutorial](https://www.youtube.com/watch?v=lpjsjFOs9oY) | Lenny (600), 2026-01, 10,000 views | Frames only (80 seconds, no talk about values) | None |
| V-SM | [The complete guide to lighting](https://www.youtube.com/watch?v=99C5K1cdql8) | SmartyRBX (158,000), 2022, 199,000 views. Builds simulator maps | Heard whole. Frames | On Reddit he is named for scripting tutorials, and once warned against. Not for lighting |
| V-ICE | [Master Roblox lighting](https://www.youtube.com/watch?v=j2ZhZv_L38M) | Ice Guy (9,700), 2026-08, 34 minutes, 24,000 views | Heard whole. Frames of the base settings and of the cartoon chapter | None seen |
| V-DEV | [Make your game look 10x better with lighting](https://www.youtube.com/watch?v=vkEXLmRAQgs) | Develuper (24,400), 2026-04, 258,000 views | Heard whole. Frames | None seen. Thin, as guessed: four minutes, few numbers said |
| V-ELE1 | [The ultimate lighting tutorial](https://www.youtube.com/watch?v=aq0Fi0R2FAY) | DatBoiEle (93,000), 2024, 20 minutes | Heard whole. Frames refused once | **Yes.** DevForum twice by name (a 2021 feedback thread; a [2024 thread](https://devforum.roblox.com/t/hyper-realistic-lighting-and-shadows/3078902)), and once on r/ROBLOXStudio (2026-08: "search up" his tutorials for a painterly style). The only creator named in both places |
| V-ELE2 | [The ultimate stylized tutorial](https://www.youtube.com/watch?v=YG-IZoKAaQI) | DatBoiEle, 2025-12, 83,000 views | Heard whole | as above |
| V-BON1 | [Advanced lighting](https://www.youtube.com/watch?v=zAoY8pxJM9c) | BONES (21,500), 2024 | Heard whole. Frames | None seen |
| V-BON2 | [Unified lighting explained](https://www.youtube.com/watch?v=6zSe8cuBB_I) | BONES, 2025 | Heard whole (second try; the first took a dubbed track). Frames: his verdicts are written on screen | None seen |
| V-RING | [How I do lighting and atmosphere](https://www.youtube.com/watch?v=UlvSrWHESwA) | RingWorld Studio (2,800), 2026-02, 58,000 views | Heard whole. Frames | **Once:** linked as "a really good tutorial for lighting" on r/robloxgamedev, 2026-07, and the asker used it |
| V-EMA | [Atmosphere, with custom lighting zones](https://www.youtube.com/watch?v=UYnn9JF8qCc) | Emancyphur (5,900), 2022 | Heard whole. Frames | None; he writes DevForum tutorials himself |
| V-ROB | [Change lighting depending where you are](https://www.youtube.com/watch?v=41ODscGm28E) (2021) and [Lighting presets](https://www.youtube.com/watch?v=6I0kOivyxBo) (2023) | RoBuilder (391,000) | Both heard whole (second try; the first took dubbed tracks). The second is a tour of a bought pack of presets: no numbers | Linked once in a DevForum reply, for another technique |
| V-DH | [How to build pro Roblox maps](https://www.youtube.com/watch?v=I-AB6pJ-y5g) | DeHapy (159,000), 2024. Builds simulator maps | Heard whole. Frames | None seen. He blurs his settings on screen and sells them: see 2.3 |
| V-UW1 | [How to make a realistic underwater build](https://www.youtube.com/watch?v=kvEf3pzKOqQ) | DatBoiEle, 2021, 68,000 views | No voice (music and on-screen steps). Frames | as V-ELE1 |
| V-UW2 | [Underwater effect](https://www.youtube.com/watch?v=fn1Rf6SPFYE) | bluenone, 21,000 views | No voice. Frames, with the script on screen | None seen |

### Reddit
Read through the archive: 28 threads with "lighting" in the title, from the last twelve months of r/robloxgamedev and
the last eight of r/ROBLOXStudio (four months of each did not answer), and the comments since July 2026 that name
a creator or say "lighting tutorial". For r/roblox the archive did not answer (tried once, late in the day). The
archive's search of comments times out over longer spans, so older recommendations were not seen.

- **The threads are short and name settings, not teachers.** "Switch LightingStyle to Realistic", "add a
  ColorCorrection", "turn the bloom down", "get a livelier sky": one-line replies. Nobody posts a recipe.
- **Named creators, in all of it:** DatBoiEle once, RingWorld Studio once (above). "A good YouTube lighting tutorial
  may help" is said without a name.
- **Nothing on simulator lighting, low graphics or Atmosphere numbers.** For our genre the videos are the source,
  not Reddit.

## 2. The rules

### 2.1 Which lighting technology

- **The old `Technology` setting is gone.** Since 2025-07-23 Lighting has two settings in its place. Neither can be
  set by a script. **(docs: S-UNI, D-LIGHT; a Reddit thread of 2026-04 where a script fails to set it; a Reddit reply
  of 2026-02 gives the same table as below)**

| Old name | LightingStyle | PrioritizeLightingQuality | What it is |
|---|---|---|---|
| Future | Realistic | on | Exact light and shadow from every lamp. The costly one |
| (new) | Realistic | off | The same, drawn to a shorter distance |
| ShadowMap | Soft | on | Sun shadows from shadow maps; lamps from the coarse grid |
| Voxel | Soft | off | Everything from a coarse grid of 4-stud cells. The cheapest |
| Compatibility | removed 2024-11 | | Now a tone-mapping switch: see 2.4 |

- **LightingStyle states an intent; the engine picks what a device gets.** Soft is the flat one: gentler shadows,
  less difference between lit and shaded, the old Roblox look. Studio starts every new place on Soft. **(docs: S-UNI,
  D-TUT)**
- **PrioritizeLightingQuality decides what goes first when a device struggles.** On: shadows and shading are kept
  near the camera and view distance is given up first. Off: the reverse. Roblox's advice is to turn it on when
  lighting and shadows carry the game's look. **(docs: D-LIGHT)**
- **On a phone, Realistic is the one that falls away.** Roblox: it costs a lot, not every device runs it at a
  playable rate, and the engine lowers lighting quality for those players (S-AND). As the quality level drops, a
  player's machine ends up on the simple grid lighting (V-OPT). **(docs)** No source gives a cost in
  milliseconds for Realistic against Soft on a phone.
- **What stylised games use: Soft. The videos keep it too, with one camp against.** The whole simulator recipe is on
  ShadowMap (heard in V-GM8; **seen on a panel** in V-NS, V-RB, V-VH and V-SM), and the one cartoon video made since the
  change shows `LightingStyle Soft` (**seen on a panel in V-LEN at 0:16**). So do SIM, AM, CL and MCR's phone-first
  simulator. V-GM8 says why in passing: change it and all the rest of the lighting changes with it. SmartyRBX, who
  builds simulator maps, gives the fullest reason: ShadowMap is the balanced one and runs well; Future adds little you
  will notice and a lot of lag once a map has many lamps and parts; Voxel has the softest shadows and so the most
  cartoony look, but dulls every colour, so the colours must be set again. **(several sources agree)**
- **The other camp: general lighting teachers say "switch to Realistic first".** V-DEV calls it the first thing to
  do; V-ICE and V-RING work in it, V-ICE even for his cartoon scene (**seen on a panel in V-ICE at 32:45**, with
  PrioritizeLightingQuality on); Reddit replies give it as a stock answer. They are teaching realism, horror and
  showcases, and none speaks of phones. KH is of this camp. **(several sources agree, on their own ground)** Even
  there the trade is named: V-ICE always recommends Realistic, "but if you want to optimize performance", Soft.
- **One creator sets the two side by side.** Soft: makes no use of surface detail maps, shadows less real, "better for
  stylized". Realistic: uses those maps well, better shadows, "less optimized", "glitchy shadows". **(one source: his
  notes seen on screen in V-BON2 at 1:04 and 1:44)** In his words: use Soft for a scene that is outdoors, low-poly or
  stylised, or that needs to run well; phones and weak devices "heavily benefit" from it; under Realistic every lamp
  draws each shadow it casts, which is why it costs. **(heard in V-BON2)**
- **A lamp reaches 120 studs at most** (60 until 2025-09). Its cost rises steeply with range. One wide lamp is
  cheaper than several small ones covering the same ground. **(docs: S-R120)**

### 2.2 What survives on low graphics

A player's menu has levels 1 to 10. The engine has 21 inside. On automatic, the engine picks one by frame rate and a
script cannot read which. The second pass added almost nothing here: no video speaks of how a look holds at low
levels. Reddit gives two scraps: "low quality gives you bad lighting, set Studio to level 21 to compare" (2026-03),
and a fog trick with a far-too-bright fog colour that its author says comes out fully black on phones unless the
colour is cut tenfold (2026-07; one source): a hint that fog is not drawn alike everywhere.

| What | At low levels | Source |
|---|---|---|
| Draw distance | Level 1: 500 studs. Level 2: 800. Level 3: 1,200. Level 4 (menu 2): 1,600. Since 2026-11-05; it was 200 to 450. Roblox may change these and says not to design round exact numbers | docs (S-QL). The same four numbers [we measured](../design/water.md) on 2026-11-13 |
| Sun and lamp shadows | Gone under level 4 (the page doesn't say on which scale). Before that they degrade | docs (D-PERF); MCR agrees |
| Bloom | Off at menu levels 1 and 2 since 2026-11-05 (it had been on at 2). Staff: it was moved up a level to pay for the longer draw distance | docs (NEON, staff reply) |
| Neon's glow | It is part of the bloom pass, so no glow where bloom is off: Neon shows as a flat bright colour, and developers say that colour doesn't match the glowing one | one source, old (a Roblox engineer, 2016); the mismatch: several users |
| SunRays, DepthOfField | SunRays may not be drawn at all on weak devices; DepthOfField may be drawn differently | docs (D-POST) |
| ColorCorrection | **Not stated anywhere.** The page says only that it can look different by quality level | unknown: test 1 |
| Atmosphere | Not drawn at the lowest level | our measurement ([water](../design/water.md)); no outside source |
| Small things | Skipped when they cover too little of the screen; the cut-off is harsher at low levels since 2026-11-05 | docs (S-QL, staff reply) |
| Particles | Fewer: `Rate` scales with quality. Beams no longer lose segments | docs (S-QL) |
| Glass | No refraction on phones at any level | docs (materials page) |
| Lamps that follow the player | A horror player reports they lag behind and update late on low levels | one source (a player's reply in S-QL) |

- **Do not steer effects by reading the player's quality setting.** Staff: games that read
  `UserGameSettings.SavedQualityLevel` to change visuals get in the way of automatic scaling, and they plan to
  deprecate it. They are considering telling scripts the current draw distance instead. **(docs: S-QL)**
- **Studio can now show the low end.** Test > Device Simulator > Performance: pick a phone and Studio draws at the
  level that phone usually runs, in Edit and in Play, and can limit memory too. It does not imitate a slow processor.
  The older way still works: Studio Settings > Rendering > Editor Quality Level (two creators show it: **seen in V-SM
  at 9:22 and V-BON2 at 3:28**). **(docs: S-SIM, S-QL)**
- **A look should stand on what level 1 keeps:** part colours, Ambient and OutdoorAmbient, Brightness, exposure,
  ColorShift_Top, Lighting's own fog, and probably ColorCorrection. Shadows, bloom, glow, sun rays and blur are extras
  for stronger machines. **(our guess, from the table above)** The simulator recipe below happens to be built of
  exactly the first list: it deletes bloom, sun rays, blur and the Atmosphere.

### 2.3 The numbers behind a vivid cartoon look

**The recipe that spread.** Gamer M8's 2023 video gives a set of numbers; Noob Scripts (2024), Rileybytes (2025) and a
2026 video titled "simulator lighting" give the same ones, and VHAero's is a louder cousin with the same sun and
shade colours. It is the nearest thing to a standard that was found. In one line: **a pale lilac light in the shade,
a warm yellow on faces toward the sun, a third of the sky's tint, soft-ish shadows on Soft, a touch of brightness,
contrast and saturation, no bloom, and a lilac fog in place of the Atmosphere.**

Lighting itself. A blank means the source didn't say or it wasn't seen.

| Source | Style | Brightness | Ambient | OutdoorAmbient | ColorShift_Top | Sky tint, shine | Shadow softness | Exposure | Sun: clock, latitude | How sure |
|---|---|---|---|---|---|---|---|---|---|---|
| A new place in Studio | Soft (ShadowMap) | 3 | 70, 70, 70 | 70, 70, 70 | 0, 0, 0 | 1, 1 | 0.2 | 0 | 14.5, 0 | seen on a panel in V-DH at 0:45 |
| **V-GM8**, 2023, and **V-NS**, 2024 | ShadowMap | 2 | 200, 160, 225 | 125, 100, 150 | 215, 190, 135 | 0.3, 0.25 | 0.2 | 0 | 14, 40 | heard in V-GM8; seen on a panel in V-NS at 0:34 and 0:49 |
| **V-RB**, 2025 | ShadowMap | 2.5 | 200, 160, 225 | 125, 100, 150 | 215, 190, 135 | 0.4, 0.5 | 0.2 | 0 | 14.5, 0 | seen on a panel in V-RB at 0:45 |
| V-WAD, 2026 | | 3 | 200, 160, 225 | 125, 100, 150 | 215, 190, 135 | 0.3, 0.25 | | | 14, 40 | heard |
| V-VH, 2024 | ShadowMap | 3.54 | 227, 171, 255 | 125, 100, 150 | 215, 190, 135 | 0.302, 0.25 | 0.37 | | 14.5, 0 | seen on a panel in V-VH at 7:43 |
| V-LEN, 2026 | Soft | 3.33 | 185, 203, 239 | | 210, 210, 210 | 0.244, 0 | 0.2 | | 14.5, 0 | seen on a panel in V-LEN at 0:16 and 0:22 |
| **V-SM**, a simulator-map builder, 2022 | ShadowMap | 3.3 | 101, 99, 127 | 70, 70, 70 | 232, 222, 160 | 0.663, 0.663 | 0.12 | 0.31 | about 15, about 73 | seen on a panel in V-SM at 10:13 and 14:28 |
| V-ICE, cartoon chapter, 2026 | Realistic | 4.05 | 0, 78, 194 | 0, 78, 194 | 235, 190, 76 | 0.619, 0.881 | 0.07 | 0.25 | 14.5, 0 | seen on a panel in V-ICE at 32:45 (small: the two ambients are the least sure) |
| V-ICE, his realistic base | Realistic | 3, then "pretty high" | 84, 85, 121 | 101, 102, 145 | "a little yellowish" | 0.2 to 0.3, 0.9 (heard) | 0.08 | 0, then "slightly up" | 14.5, 0 | seen on a panel in V-ICE at 0:50 and 3:10; the quoted parts heard |
| **BR**, brainrot games, 2026 | as Studio starts | 1.8 | | 209, 192, 191 | | 0.283, 0.39 | | 0.05 | | one source, written |
| **SIM**, cartoon builds, 2019 | ShadowMap or Voxel | 2.67 | 163, 163, 163 | 128, 128, 128 | | | 0.27 | | | one source, written |
| AM, Adopt Me's maker, 2020 | Voxel | | | | | | | | | one source, second hand |
| CL, a reply, 2023 | ShadowMap | 2.5 | | | | | 0.05 | 0.1 | | one source, written |
| A shipped game, read by a developer (ZONE) | | about 2 | about 170 indoors | about 128 | | | | | | one source |
| Roblox's island tutorial (D-TUT) | Realistic | | 16, 16, 16 | 134, 158, 190 | 196, 222, 255 | 1, 1 | 0 | | 9, 78 | docs |
| **KH**, our tutorial | Realistic | 4 | 124, 155, 184 | 157, 178, 255 | | | 1 | 0 | | our note |
| **Ours now** (`Config.Look`) | Realistic | 2.8 | 118, 128, 138 | 150, 158, 170 | not set | 0.35, 1 | 1 | -0.25 | 14.5, 0 | |

The effects and the air.

| Source | ColorCorrection brightness | Contrast | Saturation | Tint | Bloom | The air | How sure |
|---|---|---|---|---|---|---|---|
| **V-GM8**, V-NS | 0.05 | 0.1 | 0.15 | | none added | Lighting's fog: colour 200, 170, 250, start 0, end 2,500 | heard in V-GM8; fog seen on a panel in V-NS at 0:49 |
| **V-RB** | 0.05 | 0.1 | 0.15 | 255, 255, 255 | deleted, with DepthOfField and SunRays | Atmosphere deleted. Fog 200, 170, 250, 0 to 2,500 | seen on a panel in V-RB at 1:24; fog heard, colour seen at 0:54 |
| V-WAD | 0.05 | 0.1 | 0.25 | | deleted, with the rest | Atmosphere deleted. The same fog to 10,000 | heard |
| V-VH | 0.12 | 0.5 | 0.5 | 221, 210, 255 | deleted | Atmosphere: Density 0.294, Offset 0, Color 201, 162, 255, Decay 119, 97, 141, Glare 1.88, Haze 2.81 | seen on a panel in V-VH at 6:31 and 6:43 |
| V-LEN | 0.1 | 0.4 | 0.6 | 255, 255, 255 | | Atmosphere Color 156, 190, 216, Glare 0, Haze 0. SunRays Intensity 0.083, Spread 1 | seen on a panel in V-LEN at 0:40 to 1:04 |
| **V-SM** | 0 on the panel; "0.2 or 0.3 if it helps" | 0.04 | 0.2 | 255, 255, 255 | deleted: "I really don't need it" | Atmosphere: Density 0.337, Offset 1, Color 199, 170, 107, Decay 92, 60, 13, Glare 0, Haze 0, then some haze and glare with an orange Decay. SunRays: spread high, intensity low. Clouds: cover high, density low | Saturation and Atmosphere seen on a panel in V-SM at 11:38 and 18:09, mid-explanation; the rest heard |
| V-ICE, cartoon | 0.05 | 0.2 | 0.2 | 226, 240, 255 | kept: threshold low, size high, intensity low (heard) | Atmosphere: Density 0.325, Offset 0, Color 199, 199, 199, Decay 106, 112, 125, Glare 0, Haze 0. SunRays: spread and intensity very low (heard) | seen on a panel in V-ICE at 33:20 and 33:45 |
| V-DEV | 0 | 0.3 | 0.5 | 226, 230, 255 | "raised" | Atmosphere Density 0.3 to 0.4, Offset 0; a little pale glare and darker haze, or none | CC seen on a panel in V-DEV at 2:38; the air heard |
| V-ELE1 | 0.05, then to taste | 0.05, then 0.1 | 0.05 | | threshold very low, size very high, intensity low | Density raised a little to soften | heard |
| BR | | 0.13 | 1.1 | 230, 230, 230 | not touched | | one source, written |
| SIM | | 0.1 | 0.3 | 241, 241, 231 | none, on purpose | sun rays, no values | one source, written |
| AM | 0.2 | 0.1 | 0.12 | 255, 243, 235 | | | one source, second hand |
| SIM, another reply | | 0.2 | 0.6 | | 1, 25, 2; blur 4 | | one source, written |
| **KH** | | 0.5 | 0.5 | 245, 234, 255 | 1, 56, 2 | | our note |
| **Ours now** | 0 | 0.25 | 0.3 | 245, 234, 255 | 0.6, 48, 2.2 | no Atmosphere in the hub | |

("Sky tint, shine" is EnvironmentDiffuseScale, EnvironmentSpecularScale. Bloom is intensity, size, threshold. The
island tutorial also sets an Atmosphere of Density 0.375, Offset 0.17. V-SM's clock reads -8.9 on the panel, which is
the same sun as about 15. **Not seen:** DeHapy's own numbers. The Lighting panel in view in his video shows a new
place's start values; the effects under it are blurred on purpose, and the full settings are behind a link.)

**Where they agree**
- **The light in the shade is high, and coloured lilac or violet.** 200, 160, 225 (V-GM8 and its copies), 227, 171,
  255 (V-VH), a paler 101, 99, 127 (V-SM), a pale blue 185, 203, 239 (V-LEN), a strong blue in V-ICE, whose first
  on-screen rule for cartoon lighting is "increase ambient and make it colorful". SmartyRBX, of his slight purple:
  "a lot of builders do this". **(several sources agree; seen on panels)** The first pass said the opposite, from the
  written recipes alone (BR, SIM: grey or warm). Both camps exist. The videos are more, newer, and aimed at our genre
  by name.
- **In that recipe Ambient is the whole shade light.** OutdoorAmbient can't be darker than Ambient: any channel where
  Ambient is higher wins everywhere (docs). 200, 160, 225 is above 125, 100, 150 in every channel, so shade under the
  open sky and shade under a roof get the same lilac and the OutdoorAmbient number does nothing. The same holds for
  V-SM's pair and for SIM's. **(docs, applied to the panels)**
- **Faces toward the sun are tinted warm yellow with ColorShift_Top.** 215, 190, 135 (V-GM8, V-NS, V-RB, V-WAD, V-VH),
  232, 222, 160 (V-SM), 235, 190, 76 (V-ICE: "make color shift top yellow" is his second rule). **(several sources
  agree; seen on panels)** The first pass found no numbers for it and called it untried by any stylised source. It is
  the most repeated number in the videos.
- **Warm light, cool shade is the stated reason.** DatBoiEle: decide the scene, then give the lit parts a warm colour
  and the shadows a cool one, strongly for a sunset, faintly for an afternoon; Ambient is the shadows' colour and
  ColorShift_Top the light's. Ice Guy says the same of his cartoon scene: a very blue, high Ambient so shadows aren't
  dark, a very yellow ColorShift_Top "for a nice contrast to the blue shadows". **(several sources agree: heard in
  V-ELE1 and V-ICE; the recipes above do exactly this)**
- **The sky tints things only a little: about 0.3.** 0.3 (V-GM8, V-NS, V-WAD), 0.302 (V-VH), 0.244 (V-LEN), 0.4
  (V-RB), 0.283 (BR). We arrived at 0.35 on our own. Ice Guy keeps 0.2 to 0.3 for most scenes (heard). DatBoiEle
  gives the reason: lowering it deepens the difference between light and shade. SmartyRBX says most builders of
  low-poly maps go without the sky's tint and shine altogether; he likes some, and turns both down from 1 to about
  0.66. Ice Guy raises the tint to 0.62 for his cartoon scene so the shadows aren't dark. **(several sources agree;
  seen on panels)**
- **Shine is turned well down: 0.25 to 0.5.** 0.25 (V-GM8, V-NS, V-WAD, V-VH), 0.5 (V-RB), 0.39 (BR), 0 (V-LEN). Ours
  is 1. **(several sources agree; seen on panels)**
- **Saturation is small: 0.15 to 0.25.** V-GM8 and V-RB 0.15, V-ICE and V-SM 0.2, V-WAD 0.25, AM 0.12. The louder
  ones stop at 0.5 or 0.6 (V-VH, V-DEV, V-LEN, KH). BR's 1.1 stands alone. **(several sources agree)** The first pass
  said the vivid part is saturation. On the panels it is not: the colour comes from the lilac shade light, the warm
  sun, the parts' own colours and a bright sky, and saturation only tops it up. **(our guess, from the numbers)**
- **Contrast stays low: 0.2 or under.** 0.1 in the recipe, 0.04 in V-SM (heard), 0.2 in V-ICE, 0.1 to 0.13 in the
  written ones. 0.3 to 0.5 exists (V-DEV, V-LEN, V-VH, KH). **(several sources agree)**
- **ColorCorrection's own Brightness gets a small lift: 0.05.** V-GM8, V-RB, V-WAD, V-ICE; DatBoiEle starts all three
  dials at 0.05; 0.1 to 0.2 in V-LEN, V-VH, AM. Ours is 0. **(several sources agree)**
- **The sun is moderate: Brightness 2 to 3.5.** 2, 2.5, 3, 3.3, 3.33, 3.54 on the panels, 1.8 to 2.7 in writing.
  V-ICE shows 4.05 and then writes "dont make it too bright" on screen. SmartyRBX's rule: as high as it goes before
  things start to shine, and under about 4. **(several sources agree)**
- **Shadows keep an edge: softness 0.07 to 0.37,** most often Studio's 0.2. KH's 1 stands alone. **(several sources
  agree)** The two who explain it pull apart: SmartyRBX says softer is more cartoony, with 0.12 the crispest before
  edges turn jagged; Ice Guy knows people soften for cartoon scenes and prefers sharp.
- **No bloom in the simulator recipe, and no sun rays or blur.** They are deleted in the first step (V-RB, V-WAD,
  V-VH), and SIM leaves bloom out on purpose. SmartyRBX: leave bloom alone unless things blow out. A Reddit reply to a
  boss arena (2026-11): the bright glowing centre pulls the eye so hard the arena's shapes disappear; turn bloom and
  brightness back until the play space reads first. **(several sources agree)**
- **The air: either a pale fog or a thin Atmosphere.** The recipe deletes the Atmosphere and uses Lighting's own fog
  in the lilac of the shade (200, 170, 250) from 0 to 2,500 studs, further for a bigger map. SmartyRBX's fog numbers
  are close (an end near 1,000, up to 2,000 or 3,000, in the sky's colour), but he prefers an Atmosphere because it
  follows the sky through a day and night, and keeps fog for when the Atmosphere costs too much. The others keep an
  Atmosphere at Density about 0.3 to 0.4 with Offset 0 (V-DEV, V-ICE 0.325, V-VH 0.294; V-SM 0.337; Roblox's island
  0.375), its colour matched to the look. Ice Guy's everyday number is lower, about 0.2, with Offset low, and he
  leaves Haze and Glare alone for most builds (heard). **(several sources agree)**
- **The sky is swapped first, for a bright cartoon or anime one from the Toolbox.** Every video does it; DatBoiEle
  and V-ICE make it a rule and pick the sky before touching a number, because the sky colours the rest. Ice Guy on his
  cartoon scene: the sky is what carries it; delete it and everything looks dull.
  A Reddit reply to a "flat and boring" kart game says the same: the default sky is bland. One caution: V-VH tries the
  "Anime Sky" and drops it as too bright. That is the sky we use. **(several sources agree)**
- **The sun is tilted, not left where Studio puts it.** Latitude 40 at 14:00 (V-GM8, V-NS, V-WAD), about 73 at about
  15:00 (V-SM), 78 at 9:00 (Roblox's island). DatBoiEle moves the sun before anything else, until light and shadow
  fall at an angle worth looking at, with a sun-position plugin. V-RB and V-VH leave Studio's 14.5 and 0. **(several
  sources agree)**
- **The tint is a matter of taste.** White in the recipe and V-SM; a pale blue in V-ICE (226, 240, 255) and V-DEV
  (226, 230, 255); a lilac in V-VH (221, 210, 255) and KH; warm in SIM and AM. **(sources differ)** The first pass
  said nobody else tints cool. Wrong: three do.
- **Build first, light last.** DatBoiEle: build under Studio's plain light so the build carries itself, then light it.
  A Reddit reply says the same. **(one source, plus a reply)**
- **Do not pile it on.** SIM's builder: most people overdo saturation and bloom, and it stops looking like a
  cartoon. V-ICE's third rule: don't make it too bright. **(several sources agree)**
- **Part colours matter more than the light.** Colours neither garish nor dull (pastels are the example given);
  simple materials; simple shapes. **(several sources agree: SIM, CL)** And the two are chosen together: RoBuilder
  loads a "simulator" preset onto his old pet simulator, finds his bright green washed out under it, and changes the
  grass to a deeper green rather than the light. **(one source: heard in V-ROB)** We did the same when the hub's part
  colours were set to land on the reference's on-screen colours.

**What the docs add, that no recipe mentions**
- When EnvironmentDiffuseScale goes up, Ambient and OutdoorAmbient should come down: all three are shade light.
  **(docs)**
- ColorShift_Top tints faces that look at the sun, and grows with Brightness. ColorShift_Bottom can hardly be seen
  while shadows are on. **(docs)** Every video leaves ColorShift_Bottom black.
- ExposureCompensation works in stops, from -5 to 5, before tone mapping: 1 is twice the light. **(docs)**
- Bloom's Threshold: at 1 nothing but pure white blooms, at 0 everything. Size is in screen pixels. **(docs)** So a size
  of 48 is a wider share of a small phone screen than of a monitor. **(our guess)** The creators' bloom is the other
  use of it: a low threshold with a large size and a low intensity lays a faint soft glow over the whole picture.
  **(several sources agree: heard in V-ELE1 and V-ICE)** Ours is the reverse: a threshold of 2.2, so only the very
  brightest things glow.
- ShadowSoftness: one page says it works only with Realistic, the class reference says with shadow maps too.
  **(docs, and they differ)** The videos set it on ShadowMap, and one calls it mostly a performance setting.
- Atmosphere: Density hides things with distance. Offset low blends far things into the sky, and too low lets the
  sky show through them; Offset high cuts a silhouette. Glare does nothing without Haze. Decay does nothing without
  both. A sky's lower half should be darker than its upper half and near the ground's colour. **(docs: D-ATMO,
  D-TUT)** An Atmosphere does nothing without a Sky in Lighting, and Glare also needs Brightness above 0. **(one
  source: heard in V-EMA)** Clouds soften shadows as well, which he found by accident. **(one source: heard in
  V-ELE1)**

**Still no numbers** for a cartoon look's Clouds. SunRays: one value, 0.083 (V-LEN); Ice Guy calls them overused and
keeps intensity and spread very low; the recipe deletes them. DepthOfField: SmartyRBX says it only suits a big map,
kept weak; Ice Guy uses the far blur alone, slightly (near intensity 0, focus distance 0, in-focus radius 50; heard).
Blur: he never uses it in a game's base look.

### 2.4 How flat-coloured parts take light

- **What pulls a flat colour away from itself:** the sun's shading, the sky's tint, haze, shine, and the tone
  mapper. The recipe for a part that shows exactly its own colour removes them all: Brightness 0, GlobalShadows off,
  Ambient white, both Environment scales 0, no Atmosphere, SmoothPlastic. **(several sources agree: SOLID, both
  threads; a Reddit reply of 2026-07 reads a flat-looking game the same way: shadows off, both scales 0, all from
  Ambient, on Soft)** Nobody ships a simulator that way, but it names the five dials.
- **The tone mapper is a dial we haven't touched.** A `ColorGradingEffect` in Lighting has one property,
  `TonemapperPreset`: Default (since 2019; the docs call it the vivid, contrasty one) or Retro (the look before 2019;
  duller and flatter, say the docs). It works with any LightingStyle. **(docs: D-POST, S-RETRO)** Developers report that
  under Default a white sign drawn with no lighting still comes out grey, and that Retro gives the colours they set;
  one adds a little contrast afterwards. **(one source: TONE)** The docs and that thread pull in different
  directions: test 6. No video mentions the tone mapper.
- **Plastic against SmoothPlastic: no source compares how they take light.** SmoothPlastic is what the flat-colour
  recipe uses (SOLID). One tutorial calls it the cheapest material to draw (OPT26; unchecked). **(one source each)**
  One creator gets his studded floor from plain Plastic with a "Studs" MaterialVariant, not a picture on the part
  (**seen on a panel in V-DEV at 2:42**).
- **SmoothPlastic with a picture on it can show a blown-out highlight,** worse under Retro. Reported as a bug in
  2026-03, not answered. **(one source: TONE)** Our studs are pictures on SmoothPlastic, so the shine setting
  matters: the genre uses 0.25 to 0.5 (2.3).
- **Materials decide batching, colours don't.** Parts and meshes of one shape and one material draw together
  whatever their colour, size or turn; each extra material or picture splits them. Keep materials few. **(several
  sources agree: D-PERF, MCR, OPT26)**
- **Neon glows by bloom.** A brighter colour glows more; a dark Neon hardly glows. To calm it without losing it:
  Bloom Intensity down, Threshold toward 1. **(one source, old: NEON)** No source gives a size or brightness at
  which Neon turns to a blob; [our pearl](../style/building-brief.md) is the only evidence.
- **How many lamps a phone takes: no source gives a number.** The rules instead: lamps that cast no shadow, stay
  still and reach a short way are cheap, and a few of them take the flatness out of big shaded areas (MCR). A lamp
  that casts shadows, a big lamp that moves, and lamps that overlap are what cost. **(several sources agree: D-PERF,
  V-OPT, MCR, S-R120)** Reddit agrees in passing: switching shadows off on the lamps themselves is "a common thing
  devs do for optimisation", and a wide dim lamp reads better than a small bright one.
- **Shadows from thousands of small parts** are a named cause of slow frames. **(docs: D-PERF)** What games do:
  `CastShadow` off on small parts, on far parts and on anything that moves. **(several sources agree: D-PERF, V-OPT,
  MCR, OPT26, V-CF; SmartyRBX says the same: leave GlobalShadows on and turn CastShadow off on everything that
  doesn't need it)** Crusherfire goes further and gives players a switch that turns shadows off altogether, which
  SmartyRBX also suggests. Phones on low levels get no shadows anyway. A part more than 0.75 see-through casts no
  shadow at all. **(one source: heard in V-BON1)**
- **See-through sheets one behind another are costly,** phones most of all: every layer redraws the pixels behind
  it. **(several sources agree: D-PERF, V-CF, OPT26)** The same is said of "light shaft" meshes: stacks of nearly
  clear Neon planes, for showcases only. **(several sources agree: heard in V-ELE1 and V-BON1; a Reddit reply)** Our
  water's shafts are that kind of thing.
- **A budget that kept a simulator at 60 frames on most phones** (2024): 500,000 triangles and 500 draw calls in
  view, under 1.3 GB of memory. **(one source: MCR)**

### 2.5 Lighting that changes by area

- **Each player's own machine does it, from where the camera is,** not the server and not the character.
  **(several sources agree: ZONE, MCR; both zone videos use a LocalScript)**
- **Blend by distance to the border; don't fire a tween on entry.** LightKit+ gives each zone a fade distance and a
  priority and mixes every frame. A developer who studied Emergency Hamburg says it tests the camera against a box
  for each building every frame and shifts exposure, Brightness and Ambient. **(several sources agree: ZONE)** The two
  videos are the older way: invisible parts mark a zone, and stepping in starts a tween to that zone's numbers,
  stepping out a tween back to the default look (V-EMA with the ZonePlus module, one zone at a time; V-ROB with a
  folder of parts and a folder of presets for each zone: sky, Atmosphere, ColorCorrection; the zones overlapping a
  little, "it will help you tremendously"). **(heard in both)** That is what a border crossed back and forth makes
  flicker; ours blends by distance already. RoBuilder calls lighting by zone "severely underused" in games.
- **What blends smoothly:** Ambient, OutdoorAmbient, Brightness, exposure, ColorCorrection, and Atmosphere's
  Density. **What steps:** Atmosphere's Color and Haze. Three developers in one thread: change the Lighting colours
  and leave the Atmosphere's alone. **(one thread, several voices)** V-EMA tweens every Atmosphere property and
  doesn't mention it (2022, before that thread).
- **Mix colours in linear light,** or the halfway point goes muddy. **(one source: LightKit+)**
- **LightingStyle cannot change by area:** scripts can't set it. **(docs; a Reddit thread)**
- **A zone held in a part only works once that part has streamed in.** **(one source)** Zones kept as numbers in a
  script, as ours are, don't have this. **(our guess)**
- **Leave other systems' effects alone and remove your own when idle.** **(one source)**
- An indoor look in a shipped game: Brightness about 2, Ambient about 170, a small lift in exposure. **(one source)**

### 2.6 Dark places that stay readable

The videos on dark scenes are mostly after realism or horror on strong machines: near-black shade light, and lamps on
Realistic doing the work. Their numbers mark the far end, not our aim. One creator states our aim outright.
- **A game's night should not be really dark.** Ice Guy: if players can't see in front of them, that is bad
  gameplay. His night, from his day: **raise Ambient and make it bluer; turn ColorShift_Top from yellow to blue
  (moonlight); thicken the Atmosphere so you can't see as far; take a little contrast off.** No lamp in the list.
  **(one source: heard in V-ICE at 11:06 to 12:30; no numbers said)** This is the nearest any source comes to "dark,
  but you can see", and it is all shade light and air: things a phone keeps.
- **Shade light, not sunlight, is what keeps a dark place readable.** Ambient lights what the sky can't reach, and
  it starts at black. With GlobalShadows off it lights everything and OutdoorAmbient is ignored. **(docs)** The
  shipped game above brightens interiors with Ambient and exposure and no lamps. **(one source)** Ice Guy does the
  same for a room with windows: raise Ambient a little, since Roblox has no bounced light. **(heard in V-ICE)**
- **What "dark" is on a creator's panel:** Ambient 12, 12, 12, OutdoorAmbient 0, 0, 0, Brightness 0.1, GlobalShadows
  off, an Atmosphere of Density 0.479 in a near-black blue (10, 13, 16), and a ColorCorrection left at 0 but for a
  pale blue tint. **(seen on a panel in V-RING at 7:33 and 7:47; the tint heard)** Another: Atmosphere Color and
  Decay black or dark grey, both Environment scales 0, exposure -0.4, lamps in a cold teal. **(one source: heard in
  V-BON1)** At these numbers nothing shows that a lamp doesn't reach, and on a phone the lamps are the part that
  degrades.
- **One lit thing for the eye to go to.** RingWorld puts a single lamp in his night scene "for the player's eye to
  catch", then cuts the glare. Reddit says it of night maps: players get lost in the dark, and a few lamps or glowing
  points keep the path clear; keep the background dim and use light for accents. **(several sources agree: heard in
  V-RING; two Reddit replies)** This is the plan's "few lamps as landmarks".
- **Two lamps in one spot:** a short bright one for the glow near the source and a long dim one for the reach,
  because one point light alone falls off in an ugly ring. Name them apart. **(several sources agree: heard in V-RING,
  V-BON1 and V-ICE)** Reddit, on a night scene that "looked horrible": the fix was a bigger range and a lower
  brightness. Ice Guy adds: a part that gives off light should be Neon; a lamp's colour should be a faint yellow,
  never a saturated one; a soft glow picture on a particle (LightInfluence 1) or a beam down a spotlight's cone gives
  the look of lit air without stacked meshes. **(one source: heard in V-ICE)**
- **A coloured lamp inside a shadow tints that shadow** (a blue one in the shade, a warm one for light spilling in).
  **(one source: heard in V-ELE1 and V-ELE2)** It is how creators get coloured shade locally; it needs lamps, so it is
  for a set piece, not a whole land.
- **Two kinds of fog.** Lighting's own fog is a plain start and end distance, and its settings are hidden while an
  Atmosphere is in Lighting. An Atmosphere thickens with distance and its Offset chooses between silhouettes and
  far things melting into the sky. **(docs)** No source sets "see-through fog" against "fog that hides" with
  numbers. [Our water note](../design/water.md) is ahead of them.
- **A lamp that travels with the player is the risky answer.** A moving light makes the engine redo its work every
  frame (V-OPT), and on low levels such lamps are reported to lag (2.2). **(docs, plus one player)** Lifting Ambient
  or exposure by area gives the same "I can see near me" at no cost. **(our guess)**
- **Roblox has no rim light.** Developers fake one with a copied mesh turned inside out, the ForceField material, or
  see-through layers; a `Highlight` gives an outline, at most 255 at once. **(one source; docs for the limit)**
  DatBoiEle's version for buildings: a soft glow picture on a SurfaceGui along a shadow's edge, with LightInfluence 1
  so it shows in light and fades in shade. **(one source: heard in V-ELE2)**
- Nothing read contradicts [our plan](../design/map-feel.md) (dark shapes against lighter water, glowing
  ledges, a few lamps as landmarks). The parts that agree with 2.4: few lamps, no shadows from them, short range.

### 2.7 Under water

Still thin, but the second pass found two videos with numbers. Neither is a stylised, phone-first look.
- **The cheap way: tint the screen while the camera is in the water.** The water is one see-through part (0.4, Pastel
  blue, 128, 187, 219). A ColorCorrection whose only change is TintColor set to that same colour, and a BlurEffect of
  size 9, sit in Lighting and are switched on by a LocalScript each frame while the camera is inside the part's box.
  **(one source: seen on a panel and in the script in V-UW2 at 1:18 to 2:06)** MCR's simulator does the same with fog:
  on while the camera is inside a part tagged as water, and a picture slid across the surface, four lines in all.
  **(one source)** Ours is the same idea, further along.
- **A showcase sea bed, by the creator developers recommend:** a blue shade light (Ambient 57, 122, 162), Brightness
  3.5, exposure 0.15; a thick Atmosphere (Density 0.7, Offset 0, Color 57, 157, 162, Decay 64, 106, 115, Glare 0.8,
  Haze 2.15); a ColorCorrection of Brightness 0.05, Contrast 0.5, Saturation 0.5 and a strong cyan tint (0, 255, 238);
  bloom left at Studio's 1, 24, 2. Round it: the sea floor's colour darkened, an underwater sky, a caustics picture
  laid over the ground, light-shaft beams, and a bright cyan sheet for the surface seen from below. **(one source:
  seen on a panel in V-UW1 at 2:20, 5:00, 6:20 and 8:00)** It is on Future, from 2021. The Atmosphere does the
  hiding, and the Atmosphere is what a phone at level 1 doesn't draw.
- **Both tint the whole picture toward the water's colour, strongly:** all the way to the water's own colour in one,
  to a full cyan in the other. **(two sources)** We tint too (`WaterColour` in [the water note](../design/water.md)),
  but lightly. How strong ours is against theirs has not been compared.
- Roblox staff, on the engine's own terrain water: phones can't afford refraction, because reading what lies behind
  the water is what costs on a phone's kind of graphics chip. **(docs: S-QL)**
- For depth by land, fog reach tied to draw distance, and what a phone keeps, [our own note](../design/water.md) is
  still the most detailed thing found.

### 2.8 The usual mistakes, and how lighting is checked

- **Judging at full quality on a desktop.** Roblox's first advice with the new draw distances is to look at the game
  at every quality level in Studio. **(docs: S-QL)** Every video judges at full quality; none looks at a low level.
- **A look that lives in bloom, glow and shadows.** The low levels have none of them (2.2).
- **Too much saturation, contrast and bloom at once.** **(several sources agree)**
- **A strongly blue shade light under a full sky tint.** It shifts every hue the same way. **(our measurement: green
  to mint)** V-ICE's cartoon scene shows it: under his blue ambient the grass is drawn a mint green. The simulator
  recipe tints its shade too, but lilac, which keeps red up, and at a sky tint of 0.3. Whether that keeps our greens
  green is test 3.
- **Lighting first, building after.** **(one source: V-ELE2)**
- **Raising Atmosphere Offset or Density without looking far off:** sky through the hills, or far models popping.
  **(docs)**
- **Testing far views with too small a streaming radius:** what isn't loaded can't be seen at any level. **(docs:
  S-QL)**
- **How people check:** walk the map with the render figures open (Shift+F2 in the game, Ctrl+Shift+F2 in Studio)
  and look for the spots where draw calls and frame time jump; do it often, and in the live game too (MCR). Use the
  MicroProfiler on a real phone, where a slow frame shows (OPT26). Compare with a successful game of the same kind,
  side by side (CL). Switch an effect off and on to see what it does (V-ELE1). **(several sources agree)**
- **Ours to add:** a Studio window in the background is held to 15 frames and sits at the lowest level. **(our
  measurement)**

## 3. Where the sources disagree

| Question | One side | The other |
|---|---|---|
| Realistic or Soft for a cartoon look | Soft: the whole simulator recipe (V-GM8, V-NS, V-RB, V-VH), V-LEN, V-SM, V-BON2's verdict, SIM, AM, CL, MCR | Realistic: V-DEV, V-ICE, V-RING, Reddit's stock reply, KH; Roblox's tutorials. All aiming at realism or showcases |
| Colour of the shade light | Lilac, violet or blue, and high: the videos (V-GM8 family, V-VH, V-SM, V-LEN, V-ICE), KH, Roblox's island | Grey or warm: the written recipes (SIM, BR, the shipped game), and us since 2026-11-12 |
| Shadow edges | Hard: 0 (Roblox's island), 0.05 (CL), 0.07 to 0.12 (V-ICE, V-SM) | Softer: 0.2 (the recipe), 0.27 (SIM), 0.37 (V-VH), 1 (KH) |
| How much saturation | 0.12 to 0.25 (AM, V-GM8, V-RB, V-ICE, V-SM, V-WAD) | 0.5 to 0.6 (V-VH, V-DEV, V-LEN, KH, a reply), 1.1 (BR) |
| Contrast | 0.1 to 0.2 | 0.3 to 0.5 (V-DEV, V-LEN, V-VH, KH) |
| The tint | White (the recipe, V-SM) or warm (SIM, AM) | Pale blue (V-ICE, V-DEV) or lilac (V-VH, KH, us) |
| Bloom | None (the recipe, SIM, V-SM); left alone (BR) | A faint all-over glow (V-ELE1, V-ICE); raised (V-DEV); wide and strong (KH) |
| The air | No Atmosphere, a lilac fog to 2,500 (the recipe) | An Atmosphere at Density 0.3 to 0.4 (V-DEV, V-ICE, V-VH, V-SM) |
| Blur | No use in a map's base look (SMARTY, V-ICE; deleted in the recipe) | Size 4 for a cartoon look (one reply); a slight blur helps (a 2025 reply to SMARTY) |
| Sun rays | Deleted (the recipe) | "A really good effect": spread high, intensity low (V-SM); kept very low (V-ICE, V-LEN 0.083) |
| How much the sky tints | 1, for realism (D-TUT); 0.62 to 0.66 (V-SM, V-ICE's cartoon scene) | About 0.3 (the recipe, BR, us, V-ICE's everyday 0.2 to 0.3); "turn down" (V-ELE1) |
| The Retro tone mapper | Duller and flatter (docs) | Gives back the colours that were set (TONE) |
| Where shadows stop | Under level 4 (docs) | Under 5 (older forum posts). Neither names the scale |

All but the last two are taste, and on most the genre's own sources stand together on one side. The last two are
facts only a test settles.

## 4. What this means for our game

**What we already do right**
- **A sky tint of 0.35** is where the genre stands (0.24 to 0.4 on four panels). We got there by measuring.
- **Saturation 0.3 and Brightness 2.8** sit inside what the genre uses. Exposure -0.25 has no company (the sources
  are at 0 or slightly up), but it came from the user's eye.
- **A land told apart by hue, not by darkness** survives at level 1, where shadow and glow don't. The recipe's own
  tools for hue are Ambient, ColorShift_Top and the fog colour, all of which a zone can blend.
- **The fog's reach is tied to what is drawn,** with the inside-out box behind it. No source has anything as careful.
  Our measured draw distances are exactly the ones Roblox published a week before.
- **Lands blended by distance on the player's machine, the Atmosphere swapped rather than blended, and two systems
  that never write each other's numbers:** as the written zone sources advise, and a step past both zone videos.
- **`CastShadow` off on decoration and on the water's sheets.**
- **A cartoon sky swapped in.** Every video does this first.

**What the second pass takes back**
- **"The blue taken out was the right call, for the reason the sources give."** Half right. The measured fault stands:
  a blue shade light with the sky's tint at 1 turned green to mint. But the videos do tint the shade, on purpose. They
  use lilac, keep the sky's tint at 0.3 and saturation at 0.15, and warm the sunlit faces. We removed the colour from
  the shade and put nothing warm on the light, so our light and shade now differ only in brightness. That may be the
  "washed out" the user keeps reporting. **(our guess)**
- **"We began from the outlier."** Less than it seemed. KH's Contrast 0.5, Saturation 0.5 and lilac tint are V-VH's
  numbers almost exactly; its blue shade light and Realistic are V-ICE's; its Brightness 4 is V-ICE's 4.05. It is a
  loud member of a family, not a stray. It still stands alone on ShadowSoftness 1 and on bloom at 1, 56, 2.
- **"The lilac tint works against the green fix; every other source tints warm or not at all."** Three videos tint
  pale blue or lilac. The arithmetic stands (245, 234, 255 takes 8% off green), so it stays a test, lower down.

**What looks wrong, or has never been tested**
- **The look has only been judged at the top quality level, and mostly by its numbers.** That is the first mistake
  on the sources' list. On a phone at levels 1 to 3 there are no shadows and no bloom, and Neon is flat. Nobody
  knows what our hub or our water looks like there, or whether our ColorCorrection is drawn at all.
- **No warm colour on sunlit faces.** ColorShift_Top is not set. It is in every video recipe, with nearly one number.
- **Realistic is still the wrong default for this genre until someone shows otherwise.** The simulator recipe and
  the one creator who compares the two are for Soft; the creators for Realistic are lighting showcases. It is the mode
  phones fall out of, so what a phone shows is not what we tuned.
- **Shine at 1 on studded SmoothPlastic.** The genre uses 0.25 to 0.5, and there is an open bug about blown
  highlights on exactly our kind of surface.
- **ShadowSoftness 1** is the one number of ours no source comes near (0.07 to 0.37).
- **Contrast 0.25 is a little above the recipe's 0.1 to 0.2.** With a strong sun it is one cause of pale floors
  clipping.
- **Bloom 0.6, 48, 2.2 is a look only stronger machines see,** and Roblox moved it one level further out this month.
  The simulator recipe has none. "Creatures glow" in [the lighting note](../design/lighting.md) is true for part of
  the audience only.
- **The Anime Sky** is the one a video tried and dropped as too bright. Ours is turned down by exposure; worth a look
  beside another.
- **The water's colour is carried by Neon layers** (the top water, the deep sheet, the lit ceiling, the ledges). At
  low levels Neon doesn't glow and may not match in colour. The ledges should stay bright lines, which is what
  they are for; the water's blue may shift. Not looked at.
- **`water_look.luau` reads `SavedQualityLevel`** to pull the fog in for levels set by hand. Roblox asks games not
  to and means to remove it. It is the only tool for the job today; expect to replace it.
- **PrioritizeLightingQuality is not recorded anywhere in our notes.** On, the engine gives up view distance first,
  and view distance down the lane is what our deep lands need.
- **The see-through stack** (four water layers, sheets below, shafts, specks, a ceiling) is the cost every
  performance source names for phones, and two creators say it of light shafts by name. Unmeasured, as
  [the water note](../design/water.md) already says.
- **The loading radius of 2,400** is past what the middle levels draw (1,600). Already flagged by the game-code
  chat; the sources add that phones with 2 to 3 GB are a real tier.
- **`WaterSoft`, the depth-of-field effect,** may not be drawn on weak devices. Harmless if absent; no reason to
  lean on it.

**What is missing**
- A pass at the low levels, with pictures, using the new Performance Simulator.
- A choice between Soft and Realistic made by eye.
- A warm sun colour, and with it a decision on whether the shade gets a colour back (lilac this time, not blue).
- A choice of tone mapper. We didn't know there was one.
- A sun angle chosen for shape. ClockTime 14.5 at latitude 0 is the place's start, not a decision. The sources now
  give two: latitude 40 at 14:00, and about 73 at about 15:00.
- Air for the hub. `Config.Look` has none. The sources give two: a fog in the shade's colour to 2,500 studs, or an
  Atmosphere at Density 0.3 to 0.4, Offset 0.
- For the dark lands: the sources back the plan's second point (flat, tinted shade light instead of sun) and its
  "landmark" lamps. Lamps should be few, still and shadowless; a short bright one with a long dim one where a lamp
  must both glow and reach.

## 5. Tests for Studio

Each is one change against today's `Config.Look`, judged from fixed spots: the hub from the spawn, a wall face along
the lane, under water in the Shallows and in one deep land. Before and after from the same spot. The swatch test of
2026-11-12 (a part coloured 83, 214, 100, read off the screen) is the measure for colour. Most promising first.
Rewritten in the second pass: tests 3, 5, 8 and 13 are new, and the warm sun colour moved from tenth to second, now
with numbers from panels in place of our guess.

| # | The change | Numbers | What to look for | Why |
|---|---|---|---|---|
| 1 | **Quality level only.** Nothing else | Today's look at level 21, then 4 (menu 2), then 1. Use Test > Device Simulator > Performance, or Editor Quality Level | Is ColorCorrection still drawn at 1 (compare with `Look.On` 0)? What do the hub, the water's blue, the ledges and the creatures lose? | 2.2. Everything else depends on this |
| 2 | **A warm sun** | ColorShift_Top from unset to 215, 190, 135 (the recipe's), then 232, 222, 160 (SmartyRBX's, paler) | Do lit faces part from shaded ones? Does the sand go orange? The swatch in sun and in shade | 2.3: the most repeated number in the videos, and never tried here. It survives level 1 |
| 3 | **The simulator recipe, whole** (V-RB's panel) | Soft. Brightness 2.5, Ambient 200, 160, 225, OutdoorAmbient 125, 100, 150, ColorShift_Top 215, 190, 135, EnvDiffuse 0.4, EnvSpecular 0.5, ShadowSoftness 0.2, Exposure 0. ColourBrightness 0.05, Contrast 0.1, Saturation 0.15, Tint white. Bloom off. Above water only: fog 200, 170, 250 from 0 to 2,500 | Side by side with ours in the hub: which reads more like the games the user means? The swatch in shade: green, or mint again? Are the floor's squares and studs there? | The nearest thing to a standard (five videos). A yardstick first; if the user likes it, the proposal |
| 4 | **LightingStyle** | Realistic to Soft, PrioritizeLightingQuality on (old ShadowMap). Set in Edit mode; a script can't. View at 21 and at 4 | Do the studs and wall faces read as well? Does the picture change less between levels? | 2.1: the genre's choice, and steadier on phones |
| 5 | **A lilac shade, alone** | Ambient 118, 128, 138 to 200, 160, 225 with test 2's ColorShift_Top; everything else ours. Then halfway: 160, 145, 180 (our guess) | The swatch in shade against today's 38, 236, 125. Does shade read as coloured, without the mint? Does the hub flatten (this Ambient is far brighter than ours)? | 2.3: warm light, cool shade. The step between test 2 and test 3 |
| 6 | **Tone mapper** | Add a `ColorGradingEffect` to Lighting, `TonemapperPreset` Retro. If it goes flat, Contrast 0.25 to 0.35 | The swatch: nearer to 83, 214, 100 than today's 38, 236, 125? Do the three tones of a colour keep apart? | 2.4: docs and developers disagree; no video knows of it |
| 7 | **Shine** | EnvSpecular 1 to 0.5, then 0.25 | Pale patches on studded floors and stall tops, looking toward the sun | 2.3, 2.4: four panels between 0 and 0.5 |
| 8 | **Shadow edge** | ShadowSoftness 1 to 0.2 | Does a shadow at a wall's foot give the wall weight? Does it look harsh on creatures? | 2.3: ours is the only 1 |
| 9 | **Bloom off** | BloomIntensity 0.6 to 0, at level 21 | What the look loses. This is what menu levels 1 and 2 see, and what the recipe has. If little: leave it off or low for everyone (try 0.3, 24, 2.4) | 2.2, 2.3 |
| 10 | **Contrast for a lift** | Contrast 0.25 to 0.1, ColourBrightness 0 to 0.05, Saturation left at 0.3 | Do the floor's squares and studs come back in bright sun without the colours dulling? | 2.3: the recipe's balance |
| 11 | **Sun angle** | Latitude 0 to 40 with ClockTime 14 (the recipe's), then latitude 73 with ClockTime 15 (SmartyRBX's) | Which wall of the lane is lit; a shadow at a wall's foot; do creatures show a light and a dark side? | Never chosen. Both pairs are from panels |
| 12 | **Tint** | 245, 234, 255 to 255, 255, 255, then 226, 240, 255 (V-ICE's pale blue), then 255, 243, 235 (Adopt Me's) | The swatch's green; the sand; skin tones | 2.3: taste; ours takes 8% off green |
| 13 | **Air for the hub** | A fog 200, 170, 250 from 0 to 2,500 (the recipe's), against an Atmosphere of Density 0.3, Offset 0 in the sky's colour. Above water only: under it the water's own fog takes over | Does the far wall of the hub sit back? Does anything pop at the draw distance? At level 1 the Atmosphere isn't drawn; is the fog? | 2.3: the hub has no air today |
| 14 | **What goes first on a weak device** | PrioritizeLightingQuality on, then off; view down the lane at levels 4 and 7 | How far the lane is drawn against how near the shadows stop | 2.1. Likely off for us |
| 15 | **A deep land lit by shade light alone** | In Midnight only, Ice Guy's night method with our guesses for numbers: Brightness 2.8 to 0.5, Ambient to 150, 150, 190, ColorShift_Top to a pale blue 190, 210, 255, Contrast 0.25 to 0.1; nothing else. Then one still, shadowless lamp at a landmark | "Dark, but you can see": do walls, floor and creatures read against the water? Is it the same at level 1? | 2.6, and the plan in [the map's feel](../design/map-feel.md) |

The BR recipe (the first pass's test 3) is dropped as a test: it is one written post against five videos, and its
Saturation of 1.1 has no company. Its numbers are in 2.3 if wanted.

After test 1, also look once at the water's Neon layers at level 1 beside level 21. If the blue shifts, the fix is a
choice of colour and needs its own trial.

## 6. Frames

### Seen in the second pass
17 stretches (the table's V-DEV row is two), each fetched, cut to frames, looked at and deleted. Two more were
refused. The values read are in 2.3, 2.6 and 2.7.

| Video | Seconds | What it showed |
|---|---|---|
| V-RB | 12 to 100 | The whole recipe on large panels: Lighting at 0:45, fog at 0:54, ColorCorrection at 1:24 |
| V-NS | 19 to 81 | Gamer M8's numbers on large panels: Lighting at 0:34, sun and fog at 0:49 |
| V-WAD | 70 to 170 | The same recipe typed in. Panel too small to read; clock 14 and the fog fields made out |
| V-VH | 385 to 481 | ColorCorrection at 6:31, Atmosphere at 6:43, final Lighting at 7:43 |
| V-LEN | 4 to 76 | Lighting at 0:16 and 0:22, ColorCorrection at 0:40, Atmosphere at 0:52 and 0:58, SunRays at 1:04 |
| V-SM | 545 to 1140, a frame every 17 seconds | Lighting at 10:13 and 14:28, ColorCorrection at 11:38, Atmosphere at 18:09, the quality-level menu at 9:22 |
| V-ICE | 1930 to 2081 | The cartoon chapter: four rules written on screen; Lighting at 32:45, Atmosphere at 33:20, ColorCorrection at 33:45. The grass is drawn mint under his blue ambient |
| V-ICE | 20 to 215 | His realistic base: Lighting at 0:50 and 3:10; each property with a one-line note on screen |
| V-DEV | 28 to 168, and 150 to 166 again larger | ColorCorrection at 2:38; a Studs MaterialVariant at 2:42. Lighting's own values not readable |
| V-DH | 33 to 49 | His settings blurred; the Lighting panel in view shows a new place's start values |
| V-BON2 | 40 to 237 | Soft against Realistic on one ball and one corridor, with his verdicts written on screen; PrioritizeLightingQuality on a field of lamps; the quality-level menu |
| V-BON1 | 98 to 261 | A dark corridor lit by lamps in teal. No panel worth reading |
| V-RING | 404 to 523 | The night scene: Lighting at 7:12 and 7:47, Atmosphere at 7:33, ColorCorrection at 8:01 |
| V-EMA | 313 to 436 | Zones as parts with one attribute for each Atmosphere property |
| V-UW1 | 20 to 500, a frame every 20 seconds | The sea bed's Lighting at 2:20, Atmosphere at 2:40 and 8:00, bloom at 5:00, ColorCorrection at 6:20; the steps written on screen |
| V-UW2 | 6 to 150 | The water part at 1:18, the tint at 1:26, the blur at 1:34, the script at 1:58 |

### Still wanted
| # | Video | Seconds | What it should show | Why not yet |
|---|---|---|---|---|
| 1 | V-GM8 | 20 to 180 | The origin of the recipe, on its own panels; its sky | YouTube refused the stretch once (403). Not retried. The numbers were heard and are seen in V-NS |
| 2 | V-ELE1 | 444 to 520 | DatBoiEle's bloom and ColorCorrection numbers | Refused once (403). Not retried |
| 3 | V-ROB, [Lighting presets](https://www.youtube.com/watch?v=6I0kOivyxBo) | 160 to 250 | A bought pack's "simulator" presets loaded onto his old pet simulator: the panels, if they are in view | Not fetched: found late. He reads no numbers aloud |
| 4 | V-DEV | 50 to 58, at full size | His Lighting panel (Ambient colours) | Not fetched; a thin source |

Not a video: DeHapy's settings stand as pictures on [his page](https://www.shopdehapy.com/lighting-settings). One
image fetched, with the user's yes, would give a simulator builder's full numbers. His video blurs them.

## 7. What could not be found out

- **How Ride a Dino or Throw an Egg are lit.** No source shows it. The nearest are the simulator recipe (one video
  names Pet Simulator and Grow a Garden as its aim, by eye), BR (rebuilt from brainrot games by eye) and a kit video
  for a Steal an Egg copy, where the lighting arrives ready-made inside a model. Our own private frames of Ride a Dino
  could be measured for on-screen colours as the hub's were.
- **Whether the lilac shade light keeps greens green.** The recipe's makers never test a colour. Tests 3 and 5.
- **Whether ColorCorrection, ColorShift_Top, Lighting's fog and Atmosphere are drawn at level 1.** Not written down
  anywhere, and no video looks. Test 1 answers them; we measured the Atmosphere ourselves.
- **Which features switch on at which level, as a table.** Roblox publishes none and says it varies by device. A
  fan wiki has one; the site refused us.
- **What Realistic costs against Soft on a phone,** in frame time. Nobody gives a figure. One creator says "less
  optimized" and no more.
- **How many lamps a phone tolerates.** No figure; only the rules in 2.4.
- **Plastic against SmoothPlastic under light.** No comparison found.
- **When Neon turns to a blob.** No figure.
- **Whether the Retro tone mapper helps or hurts flat colours.** Test 6.
- **A dark place a phone player can read, with numbers.** One creator gives the method (2.6) and no values; every
  dark scene with values is a showcase on Realistic. Test 15.
- **A stylised under-water look with numbers.** See 2.7.
- **Who developers recommend on Reddit before mid-2026.** The archive's comment search times out over longer spans,
  and it did not answer for r/roblox at all.
- **A simulator builder's numbers from a shipped map.** DeHapy blurs his; RoBuilder's come in a bought pack and he
  reads none aloud (its panels were not looked at). SmartyRBX's are the only ones seen. Section 6.
- **Which scale the docs mean when they say shadows stop under level 4.**
