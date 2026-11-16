# Who to learn from, and what the trending games share

Up: [Home](../../Home.md).

**Second pass, 2026-11-16: 25 Reddit threads and about 8,800 comments read, 16 videos read.** The threads were read by
eye. The comments were fetched and counted by script, and about 600 of them read by eye. The videos were read whole
from their sound; 8 short stretches of frames were looked at as well.
**What changed most:** Reddit names one teacher far above all others (BrawlDev, 447 people, where the forum gave 16 and
put Suphi Kaner first). It vouches for Tizzy RBLX on design and discovery, where the forum was silent. It has **no
agreed name at all** for building, lighting, effects or UI. Watching settled who is filler and who is not: both
sites' favourites (Suphi Kaner, Tizzy RBLX) hold up when heard. And Reddit
explained two things no game page could: a **publishing gate** that keeps a new game from under-16s until it passes,
and what actually lifted Steal An Egg.

First pass read 2026-11-16 by a research agent, on the user's word ("look for the ones that are coming up constantly
as like, this is a good guy to follow for Roblox development. Something that's just not cope ... look at the ones that
are trending on Roblox right now. It's all like throw an egg, ride a dino"). The second pass was asked for because the
first could reach neither Reddit nor any video ("look through Reddit, look through forums ... something that's
actually useful to people in the space").

**What was read, first pass:**
- The Roblox DevForum, through its own search: about 1,300 posts from 2025 and 2026, and 30 threads opened in full.
- Roblox's public web APIs (the ones the Charts page itself calls): the chart lists, each game's page data, votes,
  game passes, icons and thumbnails. All player counts in section 4 are from **2026-11-16, about 15:40**.
- [RoWatcher](https://rowatcher.com) pages for 18 games (peaks and release months).
- YouTube upload lists, descriptions and chapter lists for about 30 channels and 60 videos.
- Two trade articles and one written game guide.

**What was read, second pass** (through [the two shared readers](research-tools.md) only):
- **Reddit**, r/robloxgamedev and r/ROBLOXStudio, 2025-01-01 to 2026-11-16, month by month from the public archive:
  every comment naming one of 25 creators, every comment with an asking or recommending phrase ("youtuber",
  "playlist", "best tutorials", "learn building" and the like), comments on effects, lighting, building and modelling
  tutorials, and (r/robloxgamedev, 2026-06 on) comments on the trending games. About 8,800 comments from 5,700
  threads by 4,200 people. 25 threads opened and read.
- r/roblox (the players' subreddit) is too big for the archive to search by month: only October and November 2026
  answered, 39 comments naming the trending games.
- **Videos.** YouTube still refused captions all session, so the sound was turned into text on this PC. 16 videos
  read whole this way (three of them fetched by other studies the same day). Three first came back as nonsense,
  because the reader had picked a machine-dubbed foreign track (Suphi Kaner, Tizzy RBLX, RoBuilder); it was mended
  that evening and all three were heard again from the original sound. 8 stretches of frames (40 to 60 seconds
  each) from 8 videos.

**Tags:** *seen* = on a page, API answer or video frame loaded today. *heard* = a video read whole from its sound (a
speech model's text: names and numbers can be wrong). *said* = a source's claim, linked. *inferred* = my reading.
*unknown* = could not be found.

Related: [ten talks already summarised](roblox-videos.md), [repos](roblox-repos.md),
[Ride a Dino](ride-a-dino.md), [the building brief](../style/building-brief.md),
[the loop review](../design/loop-review.md), [how Reddit and YouTube are read](research-tools.md).

## 1. Who to learn from

**How names were counted.**
- **Reddit:** distinct accounts, since 2025-01-01, that name the person in a comment (the person's own account left
  out). A name is not always a recommendation: where it matters, the number who attach a warning is given. Names in
  the first table were searched for directly. Names found later (BONES, Stewiepfing and so on) were only counted
  inside what had already been fetched, so theirs are floors. *(seen)*
- **DevForum** (first pass): posts since 2025-01-01 that name the person next to a word like "tutorial", "watch" or
  "recommend". The search returns at most 100 posts a query, so these are floors too. *(seen)*
- The two sites are different crowds. Reddit's askers are mostly beginners ("how do I learn to code" is asked every
  few days). The forum's answerers are mostly working scripters. Read the columns with that in mind. *(inferred)*

**The plain finding, now from both sites: there is a consensus on scripting and nowhere else.** For building,
lighting, effects and UI, Reddit's most common answers are "the docs", "Blender Guru's donut", "take other people's
work apart" and "there aren't many channels". The picks in those tables rest on my own watching, and are marked so.

**The second finding: working developers trust video less than beginners do.** 430 of the 4,200 Reddit accounts
bring up the documentation or the DevForum; 25 use the words "tutorial hell". One long-time answerer says he has
never seen a Roblox tutorial worth following ([thread](https://www.reddit.com/r/robloxgamedev/comments/1no4zoh/));
the same person still sends beginners to BrawlDev.
The advice that repeats: watch a beginner series once, then close YouTube and build something small. *(said)*

### Scripting and game architecture (both sites agree it matters; they disagree on who)
| Name | Good for | Reddit | DevForum | My read after watching | Wary of |
|---|---|---|---|---|---|
| [BrawlDev](https://www.youtube.com/@BrawlDevRBLX/videos) | Luau from zero: beginner, advanced and GUI playlists (2024 to 2025), each episode ending in a task to do yourself | **447 people**, 2025-01 to 2026-11. Nearly three times the next name. About 180 name the beginner playlist, 90 the advanced, 40 the GUI one | 16 users | **Holds up, for a beginner.** [Beginner #9, scoping](https://www.youtube.com/watch?v=CJfDSEN-Q5Q) *(heard whole)*: one idea, typed slowly, broken on purpose to show the error, then a task to do. Too slow for us. It also says one thing that is not so (that a global cannot be made inside a function), which is the kind of slip Reddit's few dissenters complain of | His dozen newest uploads (latest 2026-02) are "ChatGPT vs Gemini make X" *(seen)*: the teaching has stopped. Dissent: one watched the beginner series twice and learned little; one says read the docs beside him |
| [GnomeCode](https://www.youtube.com/@GnomeCode/videos) | Whole small games built in series: tower defence, doors, an RPG (16 parts, to 2026-03) | 98 people. The usual "after BrawlDev" answer | 26 users | **Holds up.** [RPG #11, alerts and notifications](https://www.youtube.com/watch?v=h5XPshZp4iY) *(heard whole, 11 min)*: starts from a design reason (a player who cannot afford something must be told), then one small system end to end: a template label, one event from the server and one inside the client, a fade in and out, a sound for failure. A pattern we could lift as it stands | Follow-along, built on a free model he supplies: easy to copy without learning. About four Reddit posters say exactly this |
| [Suphi Kaner](https://www.youtube.com/@5uphi/videos) | Advanced systems: networking (his Packet library), anti-exploit, animation sync, a 7-hour tower defence | 16 people, always for "after the basics" | 28 users. The forum's first name | **Holds up, and is the densest teaching heard this pass.** [RemoteFunction](https://www.youtube.com/watch?v=A14qFAyFYhQ) *(heard whole, 22 min)*: starts from a warning in Roblox's own docs (the server waits for ever if a client never answers `InvokeClient`), shows an exploiter can cause it on purpose, proves the memory leak in the developer console, builds the fix line by line (a RemoteEvent, a per-player list of waiting threads, a five-second timeout), tests it, and only then offers his free module. No padding, no sponsor. The forum is right about him | Last tutorial 2025-03. Most are far longer than this one. Assumes you already script |
| [Crusherfire](https://www.youtube.com/channel/UCgad0WxRzUeXxaxOyHTCOVw) | Code structure (OOP, types), memory leaks, performance | 9 people | 12 users | His ["ranking the best YouTubers"](https://www.youtube.com/watch?v=qECHr_u-4DE) *(heard, 25 min)* is filler: a sponsor read, then 30 channels ranked on how often they upload. His [lag video](https://www.youtube.com/watch?v=YWyJHwynM1M) was not heard; its chapters and the forum write-up stand | Sells a course. One Reddit buyer says it is clear but nothing YouTube lacks; another recommends it. Mixes teaching with opinion videos ("is Roblox cooked") |
| [AlvinBlox](https://www.youtube.com/@AlvinBlox/videos) | The classic basics series | 79 people, 7 of them adding "old" or "outdated" | 15 users | Not watched | Core tutorials are 5+ years old. Recent uploads are commentary, not teaching |
| [B Ricey](https://www.youtube.com/@BRicey/videos) | OOP, and a 6-part **plot placement system** (saving, validation, snap to grid) | 7 people, for "intermediate" and "the why" | 5 users | **Holds up.** [Plot placement #6, snap to grid](https://www.youtube.com/watch?v=n4ejoAIGV2I) *(heard whole, 9 min)*: works the maths aloud (round the position over the grid size, then multiply back), unbinds what it binds, says where the design choice is yours, code linked. The series is close to our tanks | Last upload 2025-08. Apologises himself for a slow schedule |
| [Stewiepfing](https://www.youtube.com/watch?v=RDugIlsRSbE) | Maths and performance ideas for scripters: Big-O, tweening, modulo | 2 people (floor) | not searched | Not watched. Chapters *(seen)* are concept-by-concept | Small sample |
| PeasFactory | A decade-old series still praised for plain explanations | 10 people | not counted | Not watched | 13 years old by one poster's count |
| [MonzterDEV](https://www.youtube.com/@MonzterDEV) | A ProfileStore saving tutorial | 4 people | 2 users | Not watched. Listed because [saving is our next feature](roblox-repos.md) | Thin evidence |
| sleitnick | His libraries (Trove, RbxUtil), not videos | 1 person | 7 users | Agrees with [our repo survey](roblox-repos.md) | |

Also named a few times on Reddit: CovertCode (3 people), TechWithMike (3), Paul1Rb for platform news (3),
RustySillyBand for small projects (1), SimTek (1).

### Building, stud style and low-poly (no agreed name on either site)
| Name | Good for | Reddit | DevForum | My read after watching | Wary of |
|---|---|---|---|---|---|
| [Kingkade 3D](https://www.youtube.com/@Kingkade3D/videos) | Building principles, a whole map build, stud UI | 0 | 0 | **Holds up.** ["10 building tips"](https://www.youtube.com/watch?v=J57CWAn7-34) *(heard whole)*: every tip is shown on his own maps and is a rule we can use: three tones on a path, big shapes before detail, props in clusters, one asset at many sizes, detail at the edges and open space in the middle, landmarks, props that tell a story. [Map build](https://www.youtube.com/watch?v=wSzIE4NCiSE) *(frames at 50:30)*: a finished low-poly map and the small kit it was made from | His maps are low-poly, not studded. Also posts "this AI makes games". Nobody on either site vouches for him: this rests on my read alone |
| [BONES](https://www.youtube.com/watch?v=XEXeFYNTrBA) | Building in Studio from the basics; composition | 5 people (floor), the only builder named with any warmth | not searched | ["5 tips"](https://www.youtube.com/watch?v=XEXeFYNTrBA) *(frames; chapters)*: starts from composition, with camera-angle diagrams. Not heard | 2024. Stylised realism, not our look |
| [RoBuilder](https://www.youtube.com/watch?v=Y3eUDs3FFGQ) | ["How to make good simulator maps"](https://www.youtube.com/watch?v=Y3eUDs3FFGQ): hub, borders, zones | 9 people, in passing | 5 users | **Holds up, and is about our hub.** *(heard whole, 9 min; frames at 5:00)* A layout method, not a build: a lobby of 250 to 300 studs; spawn in the middle; leaderboards beside spawn; the eggs a little way off "to give players a reason to leave"; the shop on the side opposite the eggs; something in every corner so the map gets walked; from spawn you should see where each thing is. Then the border: he dislikes the copied wall of bricks every simulator has, and says if you keep it, stagger it, cut the corners and never leave the map an exact square. Vary the ground height; add props until you cannot | From 2021, and he says himself it is taste. Newer uploads are entertainment |
| [DatBoiEle](https://www.youtube.com/@DatBoiEle/videos) | A painterly, "doesn't look like Roblox" style; lighting | 3 people; 2 recommend him as an environment artist | 1 user | **Split.** His [stylised tutorial](https://www.youtube.com/watch?v=YG-IZoKAaQI) *(heard whole)* is real method: paint a grey value texture outside Studio, bring it in as a material, build first and light last, coloured point lights inside shadows. His newer "I figured out" videos are filler: see section 2 | Not our style. Says himself most of it is done outside Studio |
| Blender Guru, Imphenzia, Ryan King Art | Learning Blender at all (the donut; low-poly modelling) | 16 people for Blender Guru; 2 and 1 for the others | the forum's stock answer | Not Roblox. Only if meshes are needed | |
| [VainOath](https://www.youtube.com/watch?v=3KBgLxPV-8E) | One video: a scene built classic-stud, low-poly and high-poly | 0 | 0 | Not watched | Tiny channel, 2024 |

What Reddit says in place of a name *(said)*: build from a reference picture; drop an R15 rig beside a model to check
its size; the F3X plugin for raw building; use Blender for anything that is not a box.

### Lighting and atmosphere (no agreed name; another study of the same day covers lighting in depth)
DevForum, first pass: nobody is named for lighting in more than a thread or two; Gamer M8 and Ice Guy not at all
*(seen)*.

| Name | Good for | Reddit | My read after watching |
|---|---|---|---|
| [Gamer M8](https://www.youtube.com/watch?v=YIyir52FiYo) | A 3-minute cartoon lighting setup | 2 people | **Holds up, as a recipe.** *(heard whole; frames)* Every value is spoken: purple ambient, yellow ColorShift_Top, EnvironmentDiffuseScale 0.3, ShadowMap, clock 14, pale purple fog ending at 2,500, colour correction +0.05 / 0.1 / 0.15, an afternoon sky. The scene is a bright low-poly island: our look. No reasons given, only numbers |
| [DatBoiEle, lighting tutorial](https://www.youtube.com/watch?v=aq0Fi0R2FAY) | Why lighting works | 0 for this video | **Holds up, as the reasons.** *(heard whole)* Pick the time of day first; warm light against cool shadow; Ambient colours the shadows, ColorShift_Top colours the light; lower EnvironmentDiffuseScale for contrast; bloom with a tiny threshold and a big size; clouds soften shadows. His fog-mesh light shafts lag, by his own warning. Aimed at moody interiors: take the method |
| [RingWorld Studio](https://www.youtube.com/watch?v=UlvSrWHESwA) | A working builder's order of steps | not searched | Opening read only (another study heard it): mood first, clock time, then properties, then sky and effects |
| [Ice Guy](https://www.youtube.com/watch?v=j2ZhZv_L38M) | Lighting in depth (34 minutes) | 0 | Not read |

Reddit's own advice on lighting is one line: add a ColorCorrection and move the sliders until you understand them
*(said)*.

### Visual effects (no agreed name)
DevForum, first pass: nobody is named for effects in more than a thread or two; plebarae posted his own series
*(seen)*.

| Name | Good for | Reddit | My read after watching |
|---|---|---|---|
| [Twist VFX](https://www.youtube.com/watch?v=GJOTJiUiYr4) | Particles, beams and trails from the start | 0 | **Holds up.** *(heard whole; frames)* Every ParticleEmitter property in order, shown live, with working tricks: a flipbook as four still pictures so one texture loads instead of four; beam segments = colour points minus one; never author an effect in dark lighting. Then the paid plugins and what each is for, and the two Discords (VFX Society for help, RoVFX for open-source effects). His main advice is to take open-source effects apart |
| [plebarae, "VFX Academy"](https://devforum.roblox.com/t/3894228) | Colour principles, then Studio | not searched | Self-posted on the forum. Not watched |

Reddit *(said)*: "there aren't many VFX channels to learn from"; effects are "messing around with properties" plus a
texture pack; copy other games' effects for practice; DatBoiEle's two VFX videos are not named by anyone. Tools the
forum rates *(seen, by likes)*: [VFX Forge](https://devforum.roblox.com/t/3867553),
[Emitter2D](https://devforum.roblox.com/t/3742009).

### UI (no agreed name)
DevForum, first pass: nobody is named for UI in more than a thread or two *(seen)*.

| Name | Good for | Reddit | My read after watching | Wary of |
|---|---|---|---|---|
| [Kingkade 3D, stud GUI](https://www.youtube.com/watch?v=vitiAMlaupQ) | Stud-textured UI built inside Studio | 0 | **Holds up, and is the closest thing to our UI found.** *(heard whole; frames at 10:20)* Builds an upgrade panel ("+1 Speed", a price button) and a Robux shop, "pretty similar to that tsunami game". Exact steps: the stud picture as an ImageLabel set to Tile with a fixed tile size so it never stretches; a dark blue, slightly see-through background, never pure black; a bottom-to-top gradient; a darker copy nudged down as the shadow; a thick black outline with bevelled joins on the text. His own correction of his earlier video: **studs on the header and buttons only**, because studs on everything "looks messy" | |
| [Kek](https://www.youtube.com/watch?v=z16zs2v-FNI) | The cartoony simulator UI, drawn in Figma (42 min), and a [beginner guide](https://www.youtube.com/watch?v=lmNWskz9cEI) (18 min) | not searched | **Holds up.** The beginner guide *(heard whole; frames)* builds one currency counter and teaches, on the way, the things that make UI survive a phone: anchor points, scale and never offset (shown breaking on a small screen), ZIndex, an aspect-ratio constraint, outline thickness that scales, Studio's device simulation, an icon drawn outside and brought in through the Asset Manager. The long one *(frames at 40:10)* ends on a finished pet inventory with rarity frames, search and filter buttons | Sells UI kits and plugs a Discord. The tutorials stand without them |
| BrawlDev's GUI playlist | How UI objects and scripts fit together | about 40 people | Not watched. Reddit's actual answer to "how do I learn UI" | Teaches the plumbing, not the look *(inferred from its titles)* |
| [Leif](https://www.youtube.com/watch?v=Ezk3vEOvv8o) | UI as code, with React | not searched | Not watched. [Our survey](roblox-repos.md) ruled React too heavy for this game | |

Reddit *(said)*: 10 people bring up Figma for designing UI; one good exercise is to rebuild a menu you admire from
scratch.

### Game design, retention and money
| Name | Good for | Reddit | DevForum | My read | Wary of |
|---|---|---|---|---|---|
| [Tizzy RBLX](https://www.youtube.com/channel/UCb0CbfnzYo6mLreJIXDxMtQ) | Design, live ops, the algorithm and ads for small studios | **16 people**, all since 2026-06. "Explains really well how to get your game in the algorithm"; one poster set his game's age rating by a Tizzy video | 0 | **Holds up, and is the most useful thing found on these very games.** ["Game design explained like you're 5"](https://www.youtube.com/watch?v=CRCcsYEB_6A) *(heard whole, 17 min)* lays Ride A Pet, Steal An Egg, Escape Tsunami, Kick a Lucky Block and two more side by side on eight rows: the fantasy (the title's verb), the one unique mechanic, the loop ("leave base, get thing" in all of them), where the random roll shows (before or after you carry the thing home), the level shape (a line, or Ride A Pet's ring you explore), the tension (a chaser, other players, or a timer on the egg), what you train (faster or stronger), what you collect. His reading of Steal An Egg: it took Grow A Garden's five-minute restock out of a shop window and put it in the world, then added stealing between players on top of the monster. His rule: copy a reference and change a fifth, in the fantasy and the mechanic. [Our earlier reading](roblox-videos.md) of his other videos found the advice plausible and untested; so is this | The rule comes with "guaranteed" and a 1K to 10K player promise, and no evidence but his own new game. Swears. Most titles lead with an income figure. A [39-point thread](https://www.reddit.com/r/robloxgamedev/comments/1wzp93h/) asks why people earning that much make videos; the top answer (74 points) is "they're trying to sell you something". Two posters answer that Tizzy sells no course |
| **Roblox's own talks and posts** | What the platform rewards | the docs and forum: 430 people | | Still the strongest. Agrees with [the ten talks](roblox-videos.md) | |
| [AlvinBlox, "Why Grow A Garden Blew Up"](https://www.youtube.com/watch?v=BjyJlN1npdw) | The genre's parent, by a developer | 0 for this video | | **Holds up as one developer's reading.** *(heard whole, 12 min)* Studs mean old phones can run it and anyone can read it; a shop that restocks every five minutes with scarce stock keeps people in (short enough to wait, and once waited, hard to leave); growing while offline brings them back and ends the advantage of leaving a PC on; the title says what the game is; nobody competes, so players help newcomers. No numbers: he guesses at the retention | Offers paid game reviews at the start |

### Optimisation for phones
| Source | Good for | Evidence |
|---|---|---|
| [Crusherfire, "Your Roblox Game LAGS"](https://www.youtube.com/watch?v=YWyJHwynM1M) (39 min) | Memory, draw calls, culling, `BulkMoveTo`, animator throttling, network | Named in forum answers; written up by a user ([thread](https://devforum.roblox.com/t/3881861)). Not heard |
| [Roox4](https://www.youtube.com/watch?v=vBZMscweRDk) | What a shipped game did to run on weak devices | 544K views; cited on the forum. 0 on Reddit. Not heard |
| The forum's written guides | See section 3 | By likes |

### Does this agree with the ten talks' picks?
- **Yes on the main point.** [That note](roblox-videos.md) found Roblox's own talks say the most and high-view creator
  videos are thin. Reddit and the forum both say: documentation first, video for the basics only.
- **Tizzy RBLX is the one overlap now.** Zero on the forum, 16 people on Reddit. Silme, Develuper and PineappleDev
  are named by nobody on either site *(seen)*.
- Both sites' agreed names are all scripting teachers, which the ten talks did not cover.

### Which of the first pass's picks survived being watched
| Pick | Verdict |
|---|---|
| Kingkade 3D | Survived, three videos out of three: building principles, a map build, stud UI. His maps are low-poly, so not for stud *building* |
| Twist VFX | Survived. For craft, his and Kingkade's stud GUI are the two to start from |
| Kek | Survived: the beginner guide heard whole, the long one on frames |
| Gamer M8 | Survived as a recipe |
| B Ricey, GnomeCode | Survived, one video each |
| BrawlDev | Survived for beginners, which we are not. His channel has stopped teaching |
| DatBoiEle | Half. The 2024 lighting and stylised tutorials survive. The 2026 "figured out" videos do not |
| Crusherfire | Half. The lag video stands on its chapters. The ranking video is filler |
| Suphi Kaner | Survived, heard once the reader was mended: a real hazard, proved and fixed |
| Tizzy RBLX | Survived, likewise. The analysis is real; the promise attached to it is not proven |
| RoBuilder | Survived: a hub-layout method that fits our map, though from 2021 |
| AlvinBlox (the Grow A Garden video) | Survived as a reading of the genre's parent |
| Roox4, Ice Guy, MonzterDEV, Crusherfire's lag video | Not heard in time |

## 2. Who and what to skip
| What | Why |
|---|---|
| **TheDevKing** | Still named by 157 people on Reddit, the second most, but about 22 of them attach "outdated", "deprecated" or "avoid" (a rough count by the words nearby), and the usual next sentence is "watch BrawlDev instead". Tutorials from 2019 *(said)*; last upload 2024-08 *(seen, first pass)*. On the forum 13 users still name the old playlist and one warns newcomers off it ([thread](https://devforum.roblox.com/t/4128783)). Outdated, not harmful |
| **DatBoiEle's "I finally figured out" videos** | ["How all Roblox games make their maps"](https://www.youtube.com/watch?v=wmB8BW4y5EA) *(heard whole)*: two minutes of chat, then "the secret" is a sponsor's asset shop with his discount code, then a speed build. The real content is 30 seconds of lighting settings |
| **Ranking and "is Roblox cooked" videos**, from anyone | Crusherfire's ranking *(heard)* opens with a sponsor and grades channels on upload schedule, not on whether the teaching is right. One Reddit poster cites it as a guide; it is not one |
| **"ChatGPT vs Gemini make X"** (BrawlDev, RoDev) and "AI makes a viral game in 27 minutes" | Entertainment. A Steam developer on Reddit blames exactly these for the flood of copies ([thread](https://www.reddit.com/r/robloxgamedev/comments/1xfcomt/)) |
| **Income-figure titles** ("I made $X", "viral in 7 days": Zyonic, Developer Dank, waveshine, TEG, MoseyTube77 and more) | Reddit's settled view: the video is the business ([thread](https://www.reddit.com/r/robloxgamedev/comments/1wzp93h/), [second](https://www.reddit.com/r/robloxgamedev/comments/1v5yrgx/)). Screens show revenue, never profit. Tizzy RBLX is the exception for his analysis *(heard)*: take the comparison table, skip the "guaranteed" and the income figures |
| **SmartyRBX** | 13 people name him on Reddit, but one account wrote 8 of the 20 comments. A [thread about him](https://www.reddit.com/r/robloxgamedev/comments/1lmi4sa/) is mostly negative: "talks big, never had a successful game" *(said)*. 2026 uploads are "developers are cooked", "the solo dev dream is dead" *(seen, first pass)*. One forum developer reports weak feedback from him ([thread](https://devforum.roblox.com/t/4817034)) |
| **ByteBlox** | 16 people name him; 5 warn. One developer says his videos carry errors he was told of and left ([thread](https://www.reddit.com/r/robloxgamedev/comments/1jsv3ob/)); another warns off his Discord. Stopped uploading in 2025 *(said)* |
| **"RoDev" as a recommendation** | 82 people write it, but about 70 mean the RoDevs Discord, a hiring server. That and HiddenDevs are where Reddit sends people to hire or be hired, not to learn |
| **Kit and template shops** ("Steal An Egg Kit V6", "UNCOPYLOCKED leaked") | They teach assembling a copy. Leaked copies are someone else's property and a known route for backdoors ([forum warning](https://devforum.roblox.com/t/3913726), not read in full). Reddit on one template shop: generic, and dear for what it is |
| **Any tutorial older than about two years, for APIs** | Both sites' rule of thumb. The exception both allow: the language itself has not changed much |
| **Advertising in Reddit's own comments** | Some answers are adverts for AI script tools, called out by other posters. A few "channel lists" read as machine-written and get the names wrong |
| **Listicle sites** (creation.dev and the like) | They repeat AlvinBlox, TheDevKing, PeasFactory with invented praise |
| **RoLearn's "opportunity scores"** | Promoted on the forum by its own author. Unverified |
| **The forum's micro-optimisation fashion** | A well-liked post argues it misleads people who only want to ship ([thread](https://devforum.roblox.com/t/4298930)) |

## 3. The best written sources
**Roblox's own, on how games get shown** *(seen; opening posts read, replies not)*:
- [Recommended For You: longer-term retention](https://devforum.roblox.com/t/4684575) (2026-06-15). Signals now run
  over day 1, days 2 to 7 and days 8 to 28: play time, play days, play days with friends on purpose, spend days, Robux
  spent. Click-through and first-play bounce are measured apart. This confirms [the DISC talk](roblox-videos.md) and
  stretches it from 7 days to 28.
- [Build games people want to play](https://devforum.roblox.com/t/4779042) (2026-08-06, live 2026-08-20). Retention
  first. If retention is strong, fair monetisation earns more impressions. Strong in both gets the widest reach.
- [New publishing requirements](https://devforum.roblox.com/t/4573166) (in force from 2026-05-19). Publishing to
  under-16 accounts needs extra verification, and either a paid subscription or a one-time refundable 1,000 Robux a
  game. **Read in full before launch**; only the opening was read here. Reddit's account of how it bites, which adds
  an audience test the opening did not show me, is in section 5.
- [Creator docs: discovery](https://create.roblox.com/docs/discovery) and
  [monetisation foundations](https://create.roblox.com/docs/production/game-design/monetization-foundations) (linked
  from those posts, not opened).

**Forum tutorials and resources, by likes** *(seen)*:
| Post | Why |
|---|---|
| [Lightweight NPCs](https://devforum.roblox.com/t/4224897) (244 likes, uncopylocked) | Hundreds of creatures at low server cost. Our herd |
| [Simulating thousands of moving NPCs](https://devforum.roblox.com/t/4603494) (138) | Packing creature state into few bytes; 500 creatures at about 46 kb/s |
| [The Hitchhiker's Guide to Optimization](https://devforum.roblox.com/t/3358345) (136) | One long beginner checklist |
| [The definitive tutorial to game optimization](https://devforum.roblox.com/t/4629258) (71) | When to optimise, then how |
| [Never use math.random for rewards](https://devforum.roblox.com/t/3795980) (198) | Our catches are random rewards |
| [Ruski's Tutorial #5: designing a map](https://devforum.roblox.com/t/3554962) (71) | Layout and navigation before building |
| [Simplicity: the most underrated viral aspect](https://devforum.roblox.com/t/3605011) (15) | A developer's survey of top games: ease of understanding beats depth. Opinion, small |
| [Keeping your game on the algorithm](https://devforum.roblox.com/t/3281485) (38) | Translations, soft shutdowns, phones. From 2024 |

**Reddit threads worth the time** *(read; the longest not quite to the last comment)*:
| Thread | Why |
|---|---|
| [Why is Steal an Egg so big?](https://www.reddit.com/r/robloxgamedev/comments/1w266ht/) (2026-08-30, 56 comments) | Developers and players take the leader apart. Section 5 |
| [My roblox game and ad analytics](https://www.reddit.com/r/robloxgamedev/comments/1xpb0vg/) (2026-11-06) | A tame-and-ride egg game, close to ours, reviewed by a stranger, with its ad numbers. Section 6 |
| [The low quality meta is over](https://www.reddit.com/r/robloxgamedev/comments/1tkeruo/) (2026-05-22, 46 comments) | The publishing gate argued from both sides in its first week |
| [Why is everyone using studs??](https://www.reddit.com/r/robloxgamedev/comments/1uvzwgt/) (2026-07-14, 92 points) | How developers read the stud look, and what doing it properly means |
| [Game steals concept, gets 22x more players](https://www.reddit.com/r/robloxgamedev/comments/1xnspqn/) (2026-11-04, 129 points) | Copying, and what can and cannot be protected |
| [Who is the best YouTuber to start learning to code?](https://www.reddit.com/r/robloxgamedev/comments/1ixkcx4/) and [tutorials that go into the why](https://www.reddit.com/r/robloxgamedev/comments/1no4zoh/) | The two cleanest "who to watch" threads |

**Open-source games worth reading:**
- [asimo3089's uncopylocked games](https://devforum.roblox.com/t/4908296) (2026-10-01): the Jailbreak builder's older
  places, coasters and showcases. For building craft, not for our loop.
- The Lightweight NPCs place, above.
- Libraries: see [our repo survey](roblox-repos.md).

**Trade reading:**
[Newzoo and GEEIQ on the 2026 audience](https://gamedevreports.substack.com/p/newzoo-and-geeiq-the-roblox-audience)
(2026-10-26) *(said)*: half of 10 to 15 year olds find games through YouTube; about half of all players sit in the top
50 games; Steal an Egg led the third quarter with 6 billion visits; 26 copies of one Steam hit appeared in three weeks.

## 4. The trending games
Players and visits: Roblox's games API, **2026-11-16** *(seen)*. Peaks and their months: RoWatcher *(said)*. Prices
in Robux, from the public game-pass list *(seen)*. One-off purchases (developer products) are not public: *unknown*
for every game.

| Game | Studio | Players now | Visits | Made | Peak | The loop in one line | Passes on sale |
|---|---|---|---|---|---|---|---|
| Steal An Egg | "and Collect Rare Pets" (group) | 859,062 | 11.37B | 2026-07-25 | 14.3M, Sept | Steal an egg from a zone's guardian, run home, hatch it, it earns; train speed on a treadmill to reach richer zones; steal from players | 2: x2 Money 299, x2 Growth 467 |
| Throw Food For Animals | Goofy Chupacabra | 320,737 | 280.5M | 2026-09-18 | 2.4M, Nov | Time a throw; where the food lands decides the animal; it earns on your plot; pull-ups raise throw power | 2: x2 Cash 99, x2 Training 149 |
| Break and Steal an Egg | ILGames x Eggs | 86,330 | 445.5M | 2026-09-05 | 1.3M, Oct | Break eggs with a pickaxe, carry the animal past guards, it earns | None listed |
| Net a Fish! | UpdatesDev (one user) | 27,413 | 14.8M | 2026-10-15 | 41K, Nov | Cast a net, show the best fish in your pool for cash a second, rebirth | 33, from 29 to 999 |
| Cut a Rock | Duality Works | 15,116 | 19.5M | 2026-09-14 | 31K, Nov | Train power on anvils, break floors, cut rocks open for random finds, sell | 5: anvils 199 to 499, VIP 999 |
| Steal A Pet And Ride It! | Snail Riders | 12,260 | 43.1M | 2026-10-04 | 127K, Nov | Steal a cage from a sleeping boss, run, open it, **ride the pet to go faster** | 22, from 49 to 399 |
| Throw Key for Cars | VEGA TRUTH | 12,152 | 2.0M | 2026-10-29 | 15K, Nov | Throw Food For Animals with cars | 2: x2 Cash 99, x2 Training 149 |
| Throw a Seed | Fish Time Studios | 11,606 | 3.0M | 2026-11-07 | 20K, Nov | Throw a seed down a canyon; distance is luck; a plant grows and earns | 6, from 79 to 799 |
| Bike For Egg! | Huron Games | 10,893 | 73.2M | 2026-09-15 | 151K, Oct | Steal An Egg on a bike | 2: both 199 |
| Steal a PC | vaultstudio | 10,463 | 8.9M | 2026-10-06 | unknown | Steal An Egg with computers | 3, all 99 |
| Jump for Cases | Lucky Animals! | 9,317 | 6.2M | 2026-09-22 | 34K, Nov | Jump far, roll a case, outrun a tsunami, the animal earns | 16, from 49 to 1,049 |
| Harpoon a Fish | FirstTry | 9,306 | 22.5M | 2026-08-28 | 20K, Oct | Sink deeper, aim and reel, the fish grows in your aquarium; harpoon other players' fish | 9, from 179 to 499 |
| Kick a Lucky Block | No More Flops | 8,756 | 1.97B | 2026-04-07 | 1.7M, May | Kick a block, roll a creature, outrun the tsunami you set off, it earns | 6, from 99 to 729 |
| Ride An Egg | eggs on my mind | 5,233 | 11.3M | 2026-09-24 | 38K, Nov | Go far for luck, roll an egg, run back from what chases you | 9, from 39 to 249 |
| Pull a Dino | dawyd02 (one user) | 5,039 | 1.05M | 2026-11-03 | 9K, Nov | Throw a harpoon into mud on a timing bar, pull out a dino, it earns | 15, from 40 to 999 |
| **Ride a Dino** | "and Catch Them All" (group) | 2,897 | 37.1M | 2026-08-24 | 110K, Oct | [Our reference](ride-a-dino.md) | 1: 2X Money 199 |
| Ride A Pet | this game is gud | 2,548 | 458.5M | 2026-04-14 | 1.6M, Oct | Find eggs, hatch faster pets, ride them to rarer eggs | not fetched |
| Throw An Egg! | "1K CCU slop" (group) | 319 | 6.6M | 2026-09-16 | 20K, Oct | Throw an egg, outrun a tsunami, it hatches on your plot and earns | None listed |

Where these sit on the charts *(seen)*: Steal An Egg is first in Top Playing Now, Throw Food For Animals third and
first in Top Trending. Both are in Top Earning's first six. Break and Steal an Egg is tenth in Top Playing Now. The
rest are 40th or lower, or off the list.

Of the same kind, not in the table: Dart & Dash (7.4K), Clean The Ballpit (11.8K), Sweep The Moon (21K, a cleaning
game "inspired by" a Steam one), Pull a Lucky Fish (3.5K, peak 19K in August), Throw a Coin (1.7K).

Player counts quoted by Reddit posters, for the dates *(said)*: Steal An Egg "1.5 million" on 2026-08-30, "9.9M" on
2026-10-03, "almost 1M" on 2026-11-14; Throw Food For Animals "almost 500K" on 2026-11-14.

## 5. What they share

### In nearly all of them *(seen in pages, passes and pictures, unless marked)*
1. **The title is the instruction.** A verb and a thing: Steal An Egg, Throw a Seed, Kick a Lucky Block. A child knows
   the game from the name.
2. **One loop, the same in every game.** A short act of skill or nerve (throw on a timing bar, grab and run, jump)
   **reaches a zone**; the zone decides **a random creature** with a rarity, a size and a mutation; it goes **on your
   plot and earns money every second**, offline too; money buys a better tool; and **one stat, trained on a machine
   at your base**, lets you reach the next zone. Then again.
3. **One trained stat.** Speed on a treadmill, throw power on a pull-up bar, strength on a bench, power on an anvil,
   grip on Ride a Dino's machines. It is the gate to every zone and the thing most often sold doubled.
4. **Zones in a line, each richer.** 9 biomes in Steal An Egg (speed needed: 900, 10K, 40K ... 700 million, *said* by
   [a guide](https://allthings.how/steal-an-egg-beginner-guide-biomes-speed-and-pets-explained/)), 15 in Throw Food and
   Throw a Seed, 30 in Steal a PC. The thumbnails draw them as a row of coloured strips.
5. **The same rarity ladder and the same words.** Common up to Secret or Divine; Tiny to Giant; Gold, Diamond, Rainbow;
   an Index with rewards; odds shown as "1 in 999B".
6. **Small servers.** 5 to 8 players (Throw Food 5, Steal An Egg 7, Ride a Dino 8). So plots are few and close.
7. **A x2 money pass,** 99 to 399 Robux, in every game that lists passes. Usually next to it: x2 of the trained stat,
   luck, auto-collect, VIP.
8. **One look.** A bright green studded baseplate, flat saturated colours, creatures made of blocks, sky blue above.
   The icon is the default "bacon hair" avatar beside one huge creature or object. The thumbnails carry a money-a-second
   figure, an arrow, "YOU!", and a silhouette with "???". Nearly all of this art looks machine-generated *(inferred)*.
9. **A copied page.** Steal a Brainrot, Steal An Egg, Ride a Dino, Ride A Pet, Steal a PC and Throw Food For Animals
   share one description layout, down to the "Supports Desktop, Console, Mobile, and Tablet players" line. Two groups
   use the group's name to finish the title: "Steal An Egg" "and Collect Rare Pets", "Ride a Dino" "and Catch Them All".
10. **Something chases you home,** in most: guardians, a tsunami, a shark, a boss. The trip out is the skill; the trip
    back is the risk.
11. **Scheduled spectacle.** "Admin abuse" hours (Pull a Dino daily at a fixed time; Throw Food's are covered by
    guides and videos), codes at visit milestones, "World 3" in the title.
12. **The same YouTubers carry each one.** Foltyn, CaylusBlox, BachaBlox, SkellyPlays and Vindooly post "I became the
    #1 player" and "starting over as a noob" within days, at 300K to 6M views *(seen in search listings)*.
13. **A fast rise and a fast fall.** Kick a Lucky Block: 1.7M in May, 8.8K now. Ride A Pet: 1.6M, now 2.5K. Ride a
    Dino: 110K in October, 2.9K now. Throw An Egg: 20K, now 319. The peak usually comes within one to two months of
    release (Ride A Pet, at six months, is the exception).
14. **Copies arrive in weeks.** "Throw Key for Cars" has Throw Food's description, passes and prices word for word.
    Videos titled "ChatGPT vs Claude make Throw Food For Animals" and "full template + source code" are out already.

### Only the biggest
- **They lead a family of copies.** Steal An Egg and Throw Food For Animals each have a row of same-verb followers. A
  follower gets under 4% of its leader (Throw a Seed and Throw Key for Cars: about 12K each against 321K). That is
  still thousands of players. Whether the leader was first with the verb was not checked. *(inferred from the counts)*
- **The fewest things for sale.** Steal An Egg lists 2 passes, Throw Food 2, Bike For Egg 2, Ride a Dino 1. The games
  with 15 to 33 passes are all under 30K players. What the big two sell as one-off purchases is unknown, so this is
  about the pass shelf only.
- **Low prices.** Throw Food's two passes are 99 and 149. Steal An Egg's are 299 and 467. This fits
  [Voldex's finding](roblox-videos.md) that small prices win.
- **Fewer systems.** The mid-table adds clans, crew wars, battle passes, arenas and mini-games. The top two pages
  describe six or seven steps and nothing else. *(inferred; small sample)*
- **Steal An Egg alone has lasted:** 16 weeks, still first on the platform, at 6% of its own peak. It is also the one
  where players steal from each other (a bat and a trap, *said* by the guide). Whether that is why is unknown.
- **Steal An Egg's like ratio is among the lowest of the group** (91%; most are 94 to 98%). Stealing annoys people and
  they stay anyway. *(inferred)*

### What developers on Reddit add *(all said; second pass)*
Reddit's developers mostly dislike these games, so read their "why" as hostile witnesses: what they concede counts for
more than what they sneer at.

**Why they rise**
1. **A stack of proven hooks, not a new idea.** Steal An Egg is read as random rolls + the "Steal a" theme + the
   training stat of an older incremental game, joined up
   ([thread](https://www.reddit.com/r/robloxgamedev/comments/1w266ht/), several posters). "Thousands of things
   happening in seconds, simple actions."
2. **One stat is the point.** A developer reviewing someone's game: in Steal An Egg there is one thing to upgrade,
   speed, and that is all a player needs; "simple is better" is the rule he says his own work is moving to
   ([thread](https://www.reddit.com/r/robloxgamedev/comments/1x4phdw/)). Others say the same: learnable in five
   minutes or the child leaves; rounds of 10 to 15 minutes are "way too long".
3. **Timed rare spawns pull people back.** "Players don't want to miss the next egg round." The Steal An Egg thread
   filled with adverts for Discord bots that ping when a rare egg appears: the game's timer has grown its own alarm
   clocks outside the game. Two creators, heard separately, name the source: Grow A Garden's shop that restocks
   every five minutes with scarce stock, which Steal An Egg moved from a shop window into the world *(heard: Tizzy
   RBLX, AlvinBlox)*.
4. **YouTubers, by name.** A content creator says Vindooly draws about 100,000 views on a daily Steal An Egg video,
   and that this is the main engine. A friend's game went from 50 to 1,500 players in a day on one foreign
   YouTuber's video ([thread](https://www.reddit.com/r/robloxgamedev/comments/1uwem8a/)).
5. **Steal An Egg had a scrolling video feed inside the game,** to watch while standing on the treadmill. Four
   posters name it as what first lifted the game, and two say Roblox banned the mechanic and the row made the game
   bigger. Tizzy RBLX also speaks of "the doom scrolling in the beginning" *(heard)*. A player on 2026-11-03
   describes it as still there. **Unsure which is true now; do not copy it.**
6. **Admin-abuse hours** are credited with record player counts, and resented for being short.
7. **Players stay for collecting.** The few players who defend the game say the same thing: rare things to collect,
   and the thrill of stealing from another player.

**How they are made so fast**
8. **With AI, posters say.** They say whole games (models, sound, scripts) are prompted in hours;
   one says Roblox itself described two of the current hits as nearly all machine-made. *Unverified.* A Steam
   developer's counter-view: AI gives speed, and speed in unskilled hands is what makes a copy feel like a copy.
9. **By copying, which is old and legal.** "It doesn't matter if you made it first or second, what matters is the
   execution." A copy with the same idea and near-identical thumbnails took 22 times the players of its original
   ([thread](https://www.reddit.com/r/robloxgamedev/comments/1xnspqn/)). An idea cannot be protected; copied assets
   can be taken down.
10. **By buying.** Two posters, one saying he was the seller, describe big studios buying small games for about a
    week's revenue and reskinning them, and say Steal a Brainrot began as a bought copy of an earlier "Steal a
    Character". *Contested in the same thread; unverified.*
11. **"The dropshipping of 2026."** One poster's recipe: copy a proven game, change the theme, spend 200 to 500
    dollars on ads, profit guaranteed. The answer under it, from someone who did it: a Steal An Egg derivative,
    8.7 minutes average play time, over 300 dollars of ads, 50 to 100 players, no profit after three games and
    1,000 dollars ([thread](https://www.reddit.com/r/robloxgamedev/comments/1xabmvg/)).
12. **No template was named.** Nobody on Reddit says which kit or template the egg games come from. One template shop
    is mentioned and dismissed. *Unknown.*

**Why they fall**
13. **They are built to.** Their makers "know how to beat algorithm and get their stuff trending for like a week,
    while making more". Developers who have made their money stop updating. A player on 2026-10-06 expects Steal An
    Egg to die within months.
14. **Roblox now leans against them.** The June and August discovery changes (section 3) are read on Reddit as aimed
    at exactly these games. One developer says the brainrot *theme* stopped being recommended around the end of
    June 2026: his game had 6,600 players "and the algorithm still ignored us"
    ([thread](https://www.reddit.com/r/robloxgamedev/comments/1w0zi21/)). *One source.*
15. **The cycle is older than the games.** Tycoons, then simulators, then incrementals, then brainrot: the same
    complaint each time. Saturation has not stopped new ones reaching thousands of players.

**The publishing gate** (the thing no game page shows)
16. Since 2026-05-19 a new game is shown **only to players of 16 and over** until enough age-checked players have
    played it in an engaged way ("highly engaged players"), or a larger fee is paid for an early review. Reddit's
    numbers do not agree: the threshold is given as 500 (May) and 250 (August on); the fee to skip it as 50,000 and
    as 100,000 Robux, refundable; the 1,000 Robux or subscription is described as the price of publishing at all.
    **Read Roblox's post for the real figures.**
17. What it means for a children's game, in one developer's words: adults who pass the age check dislike these games,
    so a game for children struggles to earn its way through the gate and "needs to foot the bill".
18. Ads: "play" campaigns bring very young players who leave in seconds; "engagement" campaigns bring adults. The
    prices quoted vary 50-fold between games: 0.008 dollars a play for one, 0.40 for another. Machine-made thumbnails
    are read as "slop" by the over-16s who must come first; click-through rates of 1.1 to 1.4% are called poor.

**On the look**
19. **Studs everywhere are called "retroslop".** The 92-point thread's reasons: one texture does everything, it is
    cheap, and children take to it. What its critics call doing it properly: studs on top faces only, sizes in whole
    studs, parts not rotated, as in Roblox's own early maps. The same thread admits the look works on its audience.

### What a page and captions cannot show
Retention, session length and revenue. One-off purchases and their prompts. The real first minute and whether there is
a tutorial. How the hub is laid out: thumbnails are advertising, not screenshots. Whether player counts are honest
(a 2025 analyst claim of bots on another hit was denied by Roblox, *said* in the Newzoo piece; two Reddit posters
suspect the same of Steal An Egg, with no evidence).

## 6. What this suggests for us
Offered humbly. These games have players and we do not yet.

1. **The name is taken.** A game called "[UPD] Ride a Fish" exists: group "Current Game", made 2026-09-24, 793,411
   visits, 18 playing on 2026-11-16 *(seen, in Roblox's own search results for "ride a")*. Its page describes grabbing
   eggs and hatching faster fish, not riding a herd. Worth a decision before any icon or title work.
2. **Our reference has faded.** Ride a Dino is at 3% of its peak, twelve weeks old. The riding idea is still alive in
   Steal A Pet And Ride It (12K). The window for any one verb looks like weeks, so how soon matters as much as how good.
3. **Fish are crowded, riding is not.** Net a Fish, Harpoon a Fish, Pull a Lucky Fish, Fish It and Fisch are all
   about catching. None is about riding. Our verb is the difference; the icon and title should say "ride", not "fish".
4. **Say the loop in the title and the first screen.** Every one of these does.
5. **Start the shop small and cheap:** x2 money and x2 of the trained stat, 99 to 299. Add later.
6. **Small servers:** 5 to 8, as they all do, and as our eight plots already assume.
7. **Plan for the fall on day one.** Roblox now counts days 8 to 28 and spending days. These games mostly do not last
   that long. The [loop review](../design/loop-review.md)'s "returns that unlock" is the part the genre is weakest at,
   so it is where a newcomer could be better, not just later.
8. **Our look is already theirs,** by [the building brief](../style/building-brief.md): studs, big, bright, chunky.
   Their pictures add one thing: a money-a-second figure and a rarity floating over the creature, in every shot.
9. **Check the publishing rules** (section 3) before the launch plan is fixed.

Added by the second pass:

10. **Budget for the gate, in the plan and in money.** Our players are children, and a new game cannot be shown to
    them until it has passed (section 5, points 16 to 18). Either the first audience is over 16 and must like it, or
    a fee is paid. This changes what "launch" means and should be settled with Roblox's own post open.
11. **A game very like ours was reviewed on Reddit ten days ago**
    ([thread](https://www.reddit.com/r/robloxgamedev/comments/1xpb0vg/), 2026-11-06): tame animals, ride them, a
    training area, eggs, a fuse machine. Its makers reported 40 highly engaged players after a first ad campaign;
    the reviewer read their figures as 30 dollars for 70 plays. The stranger's review is a free checklist for us:
    the name was a mouthful and hid that riding was the fun; a slow loading screen; no icons in the shop; key
    prompts that broke on a non-English keyboard; a separate step to place an animal after riding it home (getting
    off in your base should do it); a tutorial that ended on the most confusing machine. What he praised: the
    animals, and a training area that "is funny and actually works". His verdict on the niche: crowded, and a sink
    without an ad budget. *(said; one reviewer)*
12. **One trained stat, and keep it one.** Reddit's developers name this as the leader's real strength.
13. **A timed rare arrival is the genre's return hook,** and players build alarms round it. Ours could be a rare
    shoal on a clock. It fits "returns that unlock" and costs little. Five minutes is the interval both Grow A
    Garden and Steal An Egg use *(heard, two creators)*: short enough to wait for, and once waited, hard to leave.
14. **Studs, done the careful way.** Tops only, whole-stud sizes, square to the grid. It is the difference developers
    see between a stud game and "retroslop", and it is free.
15. **Do not buy children's attention with a video feed.** The one mechanic credited with the leader's first rise is
    also the one Roblox is said to have banned.
16. **Draw the thumbnail, or at least keep it simple.** The first people who must click are over 16 and read a
    machine-made picture as a warning.
17. **Fill in Tizzy's eight rows for our game** (section 1, design table) before the loop is frozen: verb, one
    mechanic, loop, where the roll shows, level shape, tension, training, collection. It is the quickest check of
    what we change against Ride a Dino and whether the change is in a row that matters.
18. **Lay the hub out RoBuilder's way:** spawn in the middle, the training machines and shop in sight from it, the
    thing you most want a short walk off, and a border that is staggered rather than a square wall.

## 7. A reading list for the other studies
Marked with how far this study got: *heard* (read whole from sound), *frames*, *read* (text), or *not read*.

**Lighting**
1. [Gamer M8, cartoon lighting](https://www.youtube.com/watch?v=YIyir52FiYo) *(heard, frames)*: 3 minutes, every number spoken, on a bright low-poly island. Start here and copy the values.
2. [DatBoiEle, ultimate lighting tutorial](https://www.youtube.com/watch?v=aq0Fi0R2FAY) *(heard)*: the reasons behind those numbers: which property colours light, which colours shadow.
3. [RingWorld Studio, lighting and atmosphere](https://www.youtube.com/watch?v=UlvSrWHESwA) *(opening read)*: a working builder's order: mood, clock, properties, then sky and effects.
4. [Ice Guy, "MASTER Roblox Lighting"](https://www.youtube.com/watch?v=j2ZhZv_L38M) *(not read)*: the long one, if the three above leave gaps.

**Building assets and maps**
5. [Kingkade 3D, 10 building tips](https://www.youtube.com/watch?v=J57CWAn7-34) *(heard)*: ten rules shown on real maps; most could go into the building brief as they stand.
6. [Kingkade 3D, a full map build](https://www.youtube.com/watch?v=wSzIE4NCiSE) *(frames at 50:30)*: 53 minutes; its last minutes show the finished map beside its kit of rocks, trees, fences and ground tiles.
7. [RoBuilder, simulator maps](https://www.youtube.com/watch?v=Y3eUDs3FFGQ) *(heard, frames at 5:00)*: from 2021, but the only one on laying out this kind of hub: where spawn, leaderboards, eggs and shop go, and what to do about the border wall.
8. [BONES, 5 tips](https://www.youtube.com/watch?v=XEXeFYNTrBA) *(frames)*: composition and camera angle before any part is placed. Reddit's one builder.
9. [Why is everyone using studs??](https://www.reddit.com/r/robloxgamedev/comments/1uvzwgt/) *(read)*: how developers judge the stud look, and the three rules for doing it properly.
10. [Kingkade 3D, stud textures](https://www.youtube.com/watch?v=Ak9Xd8DALqM) *(not read)*: how others get the stud picture; under 4 minutes.
11. [DatBoiEle, stylised tutorial](https://www.youtube.com/watch?v=YG-IZoKAaQI) *(heard)*: not our style, but "build first, light last" and coloured lights inside shadows carry over.

**UI and effects**
12. [Kingkade 3D, stud GUI](https://www.youtube.com/watch?v=vitiAMlaupQ) *(heard, frames at 10:20)*: the upgrade panel and Robux shop of this genre, built in Studio with stud textures, every setting spoken. The UI study should start here.
13. [Kek, beginner's guide to GUI](https://www.youtube.com/watch?v=lmNWskz9cEI) *(heard, frames at 12:00)*: 18 minutes; a currency counter from drawing to Studio, and how to make UI hold its shape on a phone. Then his [42-minute inventory](https://www.youtube.com/watch?v=z16zs2v-FNI) *(frames at 40:10)* for the Index and shop.
14. [Twist VFX, how to start](https://www.youtube.com/watch?v=GJOTJiUiYr4) *(heard)*: every particle, beam and trail property, with the tricks that save textures, and where effects artists gather.

**Ride a Dino and the genre**
15. [Why is Steal an Egg so big?](https://www.reddit.com/r/robloxgamedev/comments/1w266ht/) *(read)*: the leader explained by people who dislike it and people who play it.
16. [My roblox game and ad analytics](https://www.reddit.com/r/robloxgamedev/comments/1xpb0vg/) *(read)*: a tame-and-ride game's first ad campaign and a stranger's review of it.
17. [The Steal An Egg guide](https://allthings.how/steal-an-egg-beginner-guide-biomes-speed-and-pets-explained/) *(read, first pass)*: thresholds, guardians, the 5-minute respawn.
18. [CaylusBlox's first Throw Food video](https://www.youtube.com/watch?v=D6wVp6vArzU) *(not read)*: a first session on camera, for the first minute. Better as frames than as sound.
19. [Tizzy RBLX, "Game design explained like you're 5"](https://www.youtube.com/watch?v=CRCcsYEB_6A) *(heard)*: six of these games compared row by row: verb, mechanic, loop, roll, level shape, tension, training, collection. The genre study should read this first and fill in the same table for Ride a Dino and for us.
20. [AlvinBlox, why Grow A Garden blew up](https://www.youtube.com/watch?v=BjyJlN1npdw) *(heard)*: the genre's parent: the five-minute restock, growing offline, studs for old phones.

**Launch and discovery**
21. [Roblox's publishing requirements](https://devforum.roblox.com/t/4573166) *(opening read)* with [Reddit's first-week argument](https://www.reddit.com/r/robloxgamedev/comments/1tkeruo/) *(read)*: the gate, and how it lands on a children's game. Then [Roblox's two discovery posts](https://devforum.roblox.com/t/4684575), [second](https://devforum.roblox.com/t/4779042) *(openings read)*: what the platform now rewards.

**Creatures at scale, phones, plots, networking**
22. [Suphi Kaner, RemoteFunction](https://www.youtube.com/watch?v=A14qFAyFYhQ) *(heard)*: why the server must never wait on a client, and the timeout pattern that replaces it. The scripts study should check our remotes against it.
23. [Lightweight NPCs](https://devforum.roblox.com/t/4224897) and [thousands of NPCs](https://devforum.roblox.com/t/4603494) *(read, first pass)*: our herd's problem, solved twice.
24. [Crusherfire's lag video](https://www.youtube.com/watch?v=YWyJHwynM1M) *(not heard)*, from 16:05 (draw calls) and 27:50 (`BulkMoveTo`).
25. [B Ricey, plot placement #1](https://www.youtube.com/watch?v=FaEMgVDlaNQ) and [#4, saving](https://www.youtube.com/watch?v=NK8VHcNHJG4) *(not heard; [#6, snap to grid](https://www.youtube.com/watch?v=n4ejoAIGV2I) heard, and clear)*: plots, players and saving what stands on them.

## What could not be reached
- **Captions, still.** YouTube refused this PC's caption requests again during the second pass (17:37, for two more
  hours). Everything "heard" is a speech model's text. It was slow: several studies shared one queue, so some
  videos chosen for this pass were never reached: Roox4, Ice Guy, Crusherfire's lag video, Kek's long one (seen as
  frames), and the gameplay videos.
- **Dubbed sound tracks: mended the same evening.** For Suphi Kaner, Tizzy RBLX and RoBuilder the reader first
  fetched a machine-made foreign dub and the text was nonsense. The reader now asks for the original track; all three
  were heard again and judged (section 1). The three bad texts are set aside in the cache with "dubbed-bad" on
  their names. Anything else "heard" before 18:00 on 2026-11-16 that reads as nonsense has the same cause.
- **r/roblox by month.** The archive timed out on it. Players' own talk about these games is thin here: 39 comments.
- **UI and game-design phrases as a separate Reddit search** timed out. Those areas were read from the comments the
  other searches brought in, so a name could have been missed.
- **Reddit's own search, top lists, pictures and videos.** Not used. The archive's scores are not reliable for
  ranking, so threads were chosen by title and comment count.
- **One month of one search** (effects and art in r/ROBLOXStudio) did not answer; the other gaps were refetched.
  Every count is a floor all the same.
- **roblox.com/charts** as a page (it is drawn by script). The same lists were read from the API behind it.
- **Rolimons and RoMonitor:** not tried. RoWatcher gives no day-by-day history, so "how long on the charts" is
  release month, peak month and today, nothing finer.
- **Developer products, revenue, retention, session length** for every game.
- **Discord servers,** where effects artists and builders actually trade advice (VFX Society, RoVFX, RoDevs,
  HiddenDevs, and each big creator's own).
- **Which template or kit the egg games are built from.** Nobody on Reddit names one.
- **The real figures of the publishing gate.** Reddit gives two different thresholds and two different fees.
