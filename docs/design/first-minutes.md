# The first minutes: showing a new player where to go

Up: [Home](../../Home.md), [the dive-in](dive-in.md), [UI](ui.md) ("The first minute"), [Refinement](../Refinement.md) (stream 3),
[Ride a Dino in depth](../reference/ride-a-dino-deep.md) ("The first minutes").
Written 2026-11-23 by a side chat of the game-code chat. The user: "come up with a strategy for the start of the game, we need
introductary visuals which show the player where to go, how to deposit fish etc... study ride a dino intensley to find out the
strategy to go about doing this."

**A study and a proposal; the four picks in section 6 are settled (the user, 2026-11-23: "Yes, all four"). The smallest set is
built, off ([Built](#built-2026-11-23)).** Tags: *seen* (in a frame), *said*, *inferred*, *unknown*.

## The short of it
- **Ride a Dino never explains anything. It points.** One line of words, one place on the ground or one button, until the player
  does it; then the next. A new player is never without a next thing for the first three minutes.
- **It can't go wrong until the first deposit.** The first two catches are staged, can't be lost, and bring the player home by
  themselves. First catch about 13 seconds after taking control (video time), home at 27 to 29, **first deposit at 31 to 43** (game clock).
- **Ours today points at nothing.** There is no trail, no marker and no lesson. But three of our rules already do what theirs stages:
  the dive catches a fish for you, a failed dive keeps the catch, and a player with a catch wakes in front of their own tank.
- **So the smallest set is not a tutorial screen.** It is: a first fish you can't lose, one line with one pointer, the deposit's
  words, the failure naming its cure, and every step counted. Listed under "The smallest set".
- **Bluntly:** an arrow to the water helps little if the first fish throws the player off. The first item is the one that matters
  most and nobody sees it.

## 1. How Ride a Dino opens
**Where this comes from.** The user's own recordings (2026-11-09 and 10) are of a veteran account, so **they don't show a new
player's start.** Four creators' videos do, and agree: Foltyn `wK71CIlxDXU`, SSundee `KjSPLw3nEO8`, BemmyBlox `PIet23DxjZc`, yalc
`n8yGgfSBCWk`. The frames are on the user's PC only (`D:\ResearchCache\yt\frames\<video>\`, not in the repo). To make them again, **one at a time**
(the last three ranges are about right, not noted down):

```
python tools/sources/yt.py frames wK71CIlxDXU 6 80 --every 0.5
python tools/sources/yt.py frames KjSPLw3nEO8 0 176 --every 2
python tools/sources/yt.py frames PIet23DxjZc 0 80 --every 2
python tools/sources/yt.py frames n8yGgfSBCWk 100 184 --every 2
```

### The timeline, one new player
Foltyn's video time, in `wK71CIlxDXU\sheet_6_0.jpg` to `sheet_6_9.jpg` (single frames `6_NNN.jpg`, time = 6 + (N - 1) x 0.5 s).
"Control" is when the player can walk: 0:38. All *seen* unless marked. **The video is cut**, so "after control" is video time and runs
a little short; the true times, by the game's own clock, are in the table after this one.

| Video | After control | On screen | What starts it | What ends it |
|---|---|---|---|---|
| 0:13 to 0:38 | | Cutscene with black bars and a SKIP button: your own avatar leaps dino to dino; back over the hub, others' pens with +$12 to +$1.2K over them, "EVERY DINO EARNS YOU MONEY"; then yours, "YOUR PEN IS EMPTY..."; then the first dino with a "!", "NOW IT'S YOUR TURN / CATCH YOUR FIRST DINO!" | Joining | Its end, or SKIP |
| 0:38 | 0 | The screen slides in: Stamina, coins, the slots, a **GOAL panel** of three lines with circles that become ticks. **No Shop, no Index, no zone strip yet** | Cutscene over | |
| 0:39 | 1 s | A dark strip across the top, typed: "Catch your first dino!". A yellow **"!" with metres** over the target; a **trail of white chevrons from your feet to it** | Control | Getting there |
| 0:42 | 4 s | "The stampede left one behind. Catch the Dodo!": one waiting dino, nothing else near | Crossing the start strip | |
| 0:45 | 7 s | "Jump onto the Dodo!": **the whole screen dims but the Jump button**, boxed in white with an arrow at it; the world nearly stops (*inferred*) | About 37 metres from it | The press |
| 0:46 | 8 s | "Aim at the Dodo", then "Press Drop!", dimmed and boxed again | Each in turn | The press |
| 0:48 | 10 s | "Stay on the Dodo to catch it!", a "Steer left / right" hint. **No jump button: you can't leave it** | Landing on it | It is tamed |
| 0:50 | **12 s** | Hearts. "You caught the Dodo! It's already yours!" | Tamed | |
| 0:52 | 14 s | "Now catch the Pachycephalosaur!": the same once more, "Hold on! It's almost tamed!" | | Tamed, 0:59 |
| 1:01 | 23 s | Black, and **you are home**, the dino held over your head, confetti. "Go to your pen!", the caption **"GO TO YOUR PEN TO DEPOSIT"**, the trail again, to your pen | The second tame | |
| 1:07 | **29 s** | The caption becomes **"CLICK YOUR PEN TO DEPOSIT"** | Reaching the pen | The click |
| 1:09 | **31 s** | "Pachycephalosaur is in your pen!", "Your dinos earn money every second!", **+$2/s** | The click | |
| 1:10 | | GOAL is now **"Buy your first Dino Machine $2 / $300"** with a bar, and three lines: tame a dino, put it in your pen, save $300 | | Bought |
| 1:12 | | "Tame 1 or more new dinos in the canyon!", the trail back out. From here tags show what each dino needs | | |

BemmyBlox's start matches: the same cutscene, a "!" with 256 m at control, the deposit, then "GREAT RUN" and the trail to the pen
(`PIet23DxjZc\sheet_0_0.jpg`, `sheet_0_1.jpg`).

Then, from SSundee (`KjSPLw3nEO8\sheet_0_1.jpg` to `sheet_0_5.jpg`; video times, with cuts):
- **The second run** (1:08 on): the dim-and-box prompts **come back for it** (1:46; not seen again after, in a cut video read every 2 s). A first dino too strong for
  them: "Too strong! **A Dino Machine builds your Stamina.**" (1:28). They are thrown: "Stamina 20 / 60 needed" (1:30). Home:
  "GREAT RUN! You caught 2 dinos!", trail to the pen.
- **The first purchase:** "Click the sign to buy your Dino Machine!", a red "!" over its green price ($300), about **2:00 after
  control** by the game's clock. "More Stamina lets you stay on dinos longer."
- **Only then do the Shop button, the Robux offers and the "+" buttons appear** (2:16).
- **The second purchase:** "Buy your first aura at the Aura Stall", the trail there, the $100 button dimmed and boxed, about **2:45**.
  Then "Ride your fastest dino", the trail back, and the lesson is over.
- Later, one at a time as each opens: "NEW UNLOCK! JURASSIC AIRLINES" (yalc, 2:50, `n8yGgfSBCWk\sheet_100_2.jpg`), events, "Leave a Like!".

### Times to the first things
By the game's own clock, so the cuts don't matter (*seen*).

| | Foltyn | SSundee | BemmyBlox |
|---|---|---|---|
| Control to home with the first catch | 29 s | 27 s | |
| Control to the first deposit | 43 s (about 14 of it dawdling) | 31 s | about 32 s |
| Control to the first purchase | | about 2:00 | |
| Control to the second purchase | | about 2:45 | |

### What a returning player sees
From the user's recording (`research/ride-a-dino/sheet_00.jpg`, `f_0168.jpg`, `f_0285.jpg`): **no trail, no GOAL panel, no "!" with
metres, no dimming.** What stays for good: the captions "GO TO YOUR PEN TO DEPOSIT" then "CLICK YOUR PEN TO MAKE ROOM", "PEN FULL!"
with a bobbing arrow under Equip Best, a small house over your own pen's name, and a red "!" on anything newly affordable or new.

**One thing to add to [Findings](../Findings.md):** it already says the reference marks places with a "!" and metres, and gives the floor
trail to its neighbours. The frames show **the reference lays a trail itself, in the lesson only**; a veteran sees neither.

### What it never explains, and creators ask about
What the two rings mean; whether you keep what you tamed; how to go home; the Meteor event; that an aura acts on training only; that a
tag at exactly your number holds. **Ours has the same gaps today, and the second and third are ours to answer** (steps 4 and 5 below).

### What it is worth
Its badges (*seen*, all players ever): **93%** the first tame, **87%** the second zone, **78%** the end of the lesson, **64%** the
third zone. Outside numbers: one studio's test of an on-rails first ride and a goal list after it gave +10% on day 7 (*said*;
[loop review](loop-review.md), "From the videos"). We have no numbers of our own at all.

## 2. The strategy
1. **One line, one pointer, at a time.** Never two instructions. Each names a place (marker and trail) or a button (arrow on it).
2. **Nothing can be lost before the first deposit.**
3. **Get to the payoff fast:** first catch by about 10 seconds, first deposit by about 45.
4. **Follow our own path, not theirs.** Walk out, the dive catches a fish for you, run out of air, wake at your tank, deposit, ride
   the seahorse beside it, dive deeper. The run-out of air *is* our way home, so it must not read as losing.
5. **Every failure names its cure** ("too strong: your seahorse builds your Oxygen").
6. **Sell nothing and show no shop until the first deposit.** Screens arrive as they start to matter.
7. **A thing is taught when it first matters, never before.** Selling, the submarine and the upgrades wait for their moment.
8. **Each step ends by being done, not by a timer**, and a step the player has already done is skipped. So it can never hold
   anybody up.
9. **Words stop, captions stay.** Button help goes after one use. The deposit caption stays for good. A trail is for the lesson only.

## 3. What a new player must learn, and what teaches it now
| To learn | Today | Proposed |
|---|---|---|
| Where to go | The DIVE IN arch and strip. No line, no arrow | Step 1 |
| The dive | Stepping off the strip dives and hooks the nearest fish by itself (`Config.Dive.AutoHop`, `AutoGrab`) | Nothing needed: our best piece |
| Taming | The ring fills in 2 seconds; a TAMED! banner | Step 2: the first one can't be lost |
| Hopping fish to fish | A HOP / GRAB button with the key name. Nothing says when | Step 3 |
| The Oxygen meter | The ring and the bar; the ring goes red | Step 3: the hop line comes up as it turns red |
| Too strong | Red tag, red ring, "Too strong!" with the number. **Not the cure** | Step 4 |
| What happens when you run out | A fail screen, then the dock. **Nothing says you keep your fish** | Step 4 |
| Carrying home and depositing | Wakes at your own tank; "GO TO YOUR TANK TO DEPOSIT" stays on even when you stand at it; the window's PUT ALL IN | Step 5 |
| Coins | "+$2/s!" over the tank; a coin row | Step 6 |
| The seahorse (trainer) | A TRAIN sign over your own, one free level. Nothing says why | Step 7 |
| The first purchase | Nothing in reach: see "The first purchase" | Step 8 |
| Selling | A stall with a ring | Later: the first time the tank's earning places are full |
| The submarine | Free. A prompt at its ring; nothing points to it | Later: the first Coral Reef catch. **Not before: it drops a 100-Oxygen player among fish that need 525 and up (a Tiny one 420)** |
| Tank and seahorse upgrades | Signs with prices | Later: a red "!" the first time one is affordable |
| The Index, riding a fish on land | Nothing, or a slot | Later, each on first use |

## 4. Our first session, step by step
In order. **The words are placeholders, the times are estimates (nothing was played).** On a phone "CLICK" is "TAP" throughout. Times are after the player takes control.

| # | About | The player | What shows, and where | Starts | Ends |
|---|---|---|---|---|---|
| **0** | 0 s | Spawns on the line from the tanks to the strip | The herd through the gap, straight ahead. (How it looks from the spawn and whether DIVE IN reads right way up were **not checked**: no Studio.) No cutscene | Joining | |
| **1** | 0 to 4 s | Walks about 56 studs to the strip's inner edge (3.4 s spawn to gate by script; 28 studs a second) | Line at the top: **"DIVE IN! Catch your first fish"**. A marker with metres over the strip, a trail from the feet to it | Spawned with nothing ever caught | Leaves the dock |
| **2** | 6 to 10 s | Lands on a fish by itself | The fish is **one they can hold and can't lose** (below). Line: **"Hold on! It's almost yours"**. The hop button is not there yet | First landing | The tame (2 s): "IT'S YOURS!" with its +$2/s |
| **3** | 10 to 25 s | Hops on, two to five more fish | White plate and arrow on the hop button: **"TAP TO HOP TO THE NEXT FISH"** (`SPACE` on a keyboard). It is ui.md's help 2, moved from "the ring turns red" to "just tamed, or the ring turns red" | The first tame | First landed hop. Comes back at the first red ring, once |
| **4** | about 20 s | Falls off: too strong, or out of air. About 15 seconds on, where most first dives end now | On the first fish too strong: **"Too strong! Your seahorse builds your Oxygen."** And on the fail screen, the first time only: **"You keep your fish!"** | The first too-strong landing; the first drown with a catch | The fail screen |
| **5** | 25 to 40 s | Wakes **8 studs in front of their own tank**, already inside its 36-stud click reach | The caption says **"CLICK YOUR TANK"** (today's "GO TO YOUR TANK TO DEPOSIT" is wrong here), an arrow bobbing on the tank; in the window a bobbing arrow under **PUT ALL IN**, the first time only | Home with a catch | `Deposited` |
| **6** | **about 40 s** | Sees what it was for | The existing view of the tank and "Clownfish is in your tank!". Line: **"Your fish earn every second!"**. The coin row counts up for the first time | The deposit | 2 seconds |
| **7** | 40 to 75 s | Rides the seahorse, beside the tank | Trail to it. **"Ride your seahorse: more Oxygen holds stronger fish"**. Goal line: **"Coral Reef fish: 100 / 613 Oxygen"** with a bar. At 16 a second that is **about 33 seconds**; they can leave it at any time | The first deposit | 613, or a second dive |
| **8** | 75 to 90 s | Buys the first aura (only if aura buying is on: the pick below) | Trail to AURAS; arrow on its buy button. "**Auras make your seahorse stronger!**" | 100 coins | Bought |
| **9** | 90 s on | Dives again, reaches the Coral Reef and holds a fish there | Trail to the strip; the goal line says **"Catch a Coral Reef fish"** with the bar ticked | Step 7 or 8 done | First tame of one of the Reef's own kinds. Lesson over, trail never again |

**Why 613 and not 525.** 525 holds only a Normal Parrotfish; Angelfish is 588, Lionfish 613. Worked out from `Config` (the spawn mix and
the size rolls; colours left out): at 532 a player holds about a quarter of the Reef's own fish, so most of the second dive is red and
it looks as if the seahorse did nothing. At 613 they hold a bit over half. The tuning chat to confirm.

**After the lesson:** nothing more is staged. The goal line keeps one next goal (proposed in the [loop review](loop-review.md): tame 3
fish, reach the Reef, a Silver, a Big, fill the tank; a set with a reward that takes more than one session).

**What a returning player keeps:** the captions, "TANK FULL!", the red "!"s. Never the trail.

### Step 2 is the important one
Today the dive takes the **nearest** fish. [The dive-in](dive-in.md) already lists "a first fish that is always one you can hold" as not
built. The Shallows at 100 Oxygen:

| Held at 100 | Not held (needs more than 100) |
|---|---|
| Pufferfish 76, Clownfish 80, SergeantMajor 82, Cuttlefish 85, YellowTang 90; the Big ones of the first three (92, 96, 99) | Sea Turtle 102, Stingray 104, Seahorse 130, Reef Shark 540; a Big YellowTang 108, a Big Cuttlefish 102 |

So a first catch can be a red one, which throws a new player off (`StrainTime`) in their first ten seconds. Proposed rule for a
player's first dive: **the hook takes the nearest fish they can hold, Normal size and no variant, for the first fish; its meter does
not run until it is tamed; no hop button until then.** This is the reference's "you can't leave it", in one server rule.
**And such a fish has to be there:** the gate is sometimes empty within 100 studs ([dive-in](dive-in.md)). So the server puts one in
reach for a first dive, as `Config.Sub.Stock` already puts fish ahead of a sub's arrival (the waiting shoal is the planned version).

### Where the pointer sits and what it costs
- **One pointer, shared by all steps:** a marker (arrow with metres) over the target, and a trail from the feet on the dock floor.
  In the water no trail: the fish's own tags and the lock already point.
- **Our own look:** yellow, our rule for "press this / go here" ([UI](ui.md), colours). Not their white chevrons. Drawn on this
  player's screen only, MaxDistance set, off when the target is near. A beam is one draw call but its picture has to be **uploaded**
  (the user's word); pooled flat parts need nothing. Both to be judged on a phone.
- **State:** the server keeps each player's lesson step (it decides what has happened; the client only draws). It lasts the session, so
  **it replays on every join until saves are in**. Off in the movement sandbox.
- **Players with no plot** (a full server) have no tank: their lesson ends at step 4.
- **A first hop that lands on nothing** already leaves them floating (`Config.Dive.ForgiveMiss`), with 20 seconds before the dock takes them
  back (`FirstDockWait`): the line then says "TAP TO HOP" and step 2 waits. Nobody can drown before the first tame.
- **A skip** is one small button; or nothing at all, since each step skips itself once done.

## 5. What matters most
Rank = which funnel step it protects. **The order is *inferred*:** from the reference's badges and the creators' confusions, not from our
own players.

| Rank | Piece | Protects | Why |
|---|---|---|---|
| 1 | The first fish can't be lost, and the first dive's rules (step 2) | First tame (their 93%) | Their whole lesson hangs on it. Ours can throw a new player off in ten seconds |
| 2 | Steps counted (below) | All of them | Nothing else can be judged without it. Roblox's onboarding funnel, the game's own steps |
| 3 | DIVE IN line and pointer (step 1) | First tame | Cheap; also the one the user asked for |
| 4 | Deposit: the caption, the tank arrow, the PUT ALL IN arrow, "you keep your fish" (steps 4 and 5) | First deposit | Our most confusing screen today. The "go home" answer is a line, not a mechanic |
| 5 | "Too strong" names the cure (step 4) | Second zone (their 87%) | One line where one exists |
| 6 | The hop prompt (step 3) | First tame to second | Already designed in ui.md |
| 7 | Seahorse pointer and the goal line (step 7) | Second zone, lesson done (their 78%) | The bridge to "why come back" |
| 8 | The first purchase (step 8) | Lesson done | Waits on aura buying |
| 9 | HUD and shop hidden until they matter | Reads better | Polish |
| 10 | Cutscene, dimmed screen, confetti | | **Polish. Leave it out.** The reference's cutscene is the biggest piece of its opening and the least useful to copy first |

### The smallest set
**Ranks 1 to 6 and the goal line of 7, with no new art:**
1. The first-fish rule, **and a fish they can hold put at the gate for it**.
2. One line at the top and one pointer (marker and trail), used by steps 1, 5 and 7.
3. The deposit words: caption that changes when you are near, arrows on the tank and on PUT ALL IN (first time only).
4. The three lines that answer what creators asked: "You keep your fish!", "Too strong! Your seahorse builds your Oxygen.",
   "TAP TO HOP".
5. The goal line, with the Oxygen bar.
6. The steps counted: spawned, left the dock, first landing, first tame, first dive ended, first deposit, seahorse ridden, second
   dive, reached the Coral Reef, first purchase, second day (Roblox's `AnalyticsService` onboarding funnel; none of it is in `src` yet).

It needs `RideService` (the first-fish rule and the lesson step), one new client controller for the line and pointer, and edits to
`DockNotes`, `TankPanel`, `HopButton` and the fail screen's words. **Do the saves flag with the save system, not before.**

**Second, when the smallest set shows where players stop:** aura buying and step 8; the HUD arriving by steps; a goal list with a
reward. **Last:** anything in rank 10.

### The first purchase
The reference sells a $300 machine, then a $100 aura, by about 2:45. **Ours has nothing cheap in reach:** the free seahorse level is
already given, its next is **15,000**, the tank's first stage 1M, the submarine free. At 2 to 2.6 coins a second a fish, seven
Shallows fish earn about 15, so 15,000 is **about 17 minutes**; seven Coral Reef Uncommons earn about 95, so under 3. The
accepted economy draft ([progression](progression.md), "draft 2") has the reference's answer: a **$100 aura at about 1 minute**.
*(Built 2026-11-24: auras are bought at the stall, the first for $100; step 8 of the lesson is still not built.)* **It was drafted, not built:** `Shared/Auras` has no prices and the server doesn't listen for the buy (the game-code chat has already asked
whether to build it). Turning it on at the draft's price is the one piece that gives this game a first purchase, and changes no agreed number. One Clownfish earns
100 coins in 50 seconds, three fish in about 17, so it arrives while they sit on the seahorse (33 seconds at 2 to 6 a second is 66 to 200 coins).

### Built (2026-11-23)
On the user's "yes, game code is busy right now but if you can do both at same time then yes". **It is off: `Config.Lesson.On` = 0,
and then the server hooks nothing and the client builds nothing** (played that way, a whole dive and fail: no errors, none of it there). `On` = 1 turns
it on for everyone. In Studio the workspace's `LessonTest` attribute, set before Play, turns it on whatever `On` says.
**The second version (2026-11-24),** after the user tried the first by hand: "make sure none of the tutorial UIs overlap with any of
the normal UIs, and also get rid of any of the UIs which are unnecessary, like the go down to the coral reef and catch some fish …
make sure the arrows on the floor … connect with each other properly and they don't have any artifacts".
- **Cut:** the line under the land strip, the Coral Reef goal with its Oxygen bar and number, the metres by the arrow, "Your fish
  earn every second!", "Too strong!", the dark plate by the hop button and its repeat at the first red ring, the arrow on PUT ALL IN.
  The lesson's server steps beyond the second dive went with them.
- **The server** (`Services/LessonService`): each player's step, `Dive`, `First`, `Hop`, `Run`, `Deposit`, `Train`, `Again`, in the
  player's `Lesson` attribute (none: over). `LessonHold` is on while the first-fish rule is.
- **The first fish:** one they can hold, Normal and plain. Any other is refused, and the lock skips it. Its meter waits for the tame,
  there is no hop off it, and nobody drowns before it: at 0 they come home. With none in reach, two are put ahead down the stream.
  The rule lets go after 60 s in the water, or 8 s on one fish with no tame.
- **The screen,** one thing at a time, in the game's own lettering (yellow for what to press or where to go):

| Step | Words | Points at |
|---|---|---|
| Dive | DIVE IN AND CATCH A FISH (the dock's one line, where GO TO YOUR TANK TO DEPOSIT is) | arrow over the strip, trail to it |
| First, floating | HOP ON A FISH | arrow on the hop button |
| Hop, the first fish theirs | HOP TO THE NEXT FISH | arrow on the hop button |
| Deposit | the game's own caption; CLICK (or TAP) YOUR TANK when near | arrow over the tank's board, trail; then a ring round PUT ALL IN |
| Train | RIDE YOUR SEAHORSE TO HOLD STRONGER FISH | arrow over the seahorse, trail |
| Again, off the seahorse with Oxygen gained | DIVE IN AGAIN | arrow over the strip, trail. **The dive ends the lesson** |

- **Where:** `Controllers/LessonController` decides; `UI/DockNotes` has the line; `UI/LessonPointer` the arrow and the trail;
  `UI/LessonPrompt` the hop button's words and arrow and the ring. All of it waits for the black, the fail's words, the catch
  screen and any window (and 0.25 s after the tank's window closes).
- **The arrow** comes down with nearness over the strip and shrinks away whenever the view would put it behind the HUD.
  **The trail:** chevrons of wedges with a dark plate under each, walking toward the place; each is whole (both arms meet in one
  point), grows in and out at the ends, needs flat floor under all of it, and closes up before a seahorse's stand.
- **Waking up at the tank** the camera now looks where the body does (it kept the dive's direction, often sideways).
- **Found and fixed on the way:** a line asked away and back within one frame vanished (`Anim.toast` takes it for shown;
  guarded in `DockNotes`, the root is in `Anim`, the UI chat's); the deposit caption came up over the fail's words and the catch
  screen (`StallController`).
- **"You keep your fish!" is not one of our lines:** the fail words already say "YOUR CATCH IS SAFE" (`Config.Fail.Safe`).
- **The steps counted** differ from the list above: "first purchase" and "second day" are not in, "reached the Coral Reef" counts
  the first fish tamed there (counted, no longer a step), "first dive ended" counts only a dive with a tame. Fix the list before it goes live: the numbers can't be changed
  after.
- **Saves:** nothing of the lesson is kept yet. Fish given back to a tank before any tame end it (not a new player). When the saves
  go on, give `SaveService` a "Lesson" part, so a returning player with an empty tank doesn't get it again.

**Checked in Studio by script** (`tools/studio/lesson_check.py`; `do overlaps` lists every pair of a lesson piece and any other drawn
thing that met on the screen, looked at every second frame): the whole run, spawn to the second dive, on the PC layout, and to the
tank on Studio's pretend touch; a picture of each step (`work/lesson/sheet.jpg`, this PC); no chevron corner inside a stand in
12,000 parts looked at; no errors or warnings of ours with it on; off, a whole dive and nothing built.
**Waking at the tank:** 6 studs from the board, the camera dead on it (measured; the one odd view was the test driver walking on).
**Overlaps left:** the ride's speed streaks and, for a look or two, a passing fish's name tag under the hop words; the dock's line in its 0.1 s fade as
the tank's window opens; the arrow over the land strip or a slot for 2 to 8 looks (up to about a quarter of a second) when the
script threw the player or camera about; the trail under a slot for 2 looks, and once as the view faced away from where it leads
(it lies on the floor, so it goes under the HUD wherever the floor does).
**Seen, not the lesson's:** `Infinite yield possible on ReplicatedStorage.Shared:WaitForChild("Pose")` and the asset 203785492 of the wrong
type, in every Play, with the lesson on or off.
**Not checked:** "HOP ON A FISH" (the dive lands on a fish before its 0.8 s are up, every time); the tank's window opened by a click (opened by script); a real phone (Studio's
pretend touch only, at the PC's size); two players at once; the rule's two time limits; the real funnel (it prints in Studio); this version
played by hand.

## 6. The user's picks
**Settled 2026-11-23: A on all four** (asked "Go with the recommended option on all four picks?", the user: "Yes, all four"; [Decisions](../Decisions.md)).

| # | Question | A | B | Recommended |
|---|---|---|---|---|
| 1 | How the first dive ends | **A: runs its course** (about 15 s, the first failure) and brings them home with the catch | B: home by itself after the second tame, as the reference | **A.** It is what our game already does, it shows the cure early, and it needs nothing new. B is gentler; it costs a scripted end |
| 2 | The first purchase | **A: turn on aura buying** at the draft's $100 | B: no purchase in the lesson; the Oxygen bar is the goal | **A, when the game-code and tuning chats can take it.** Until then the smallest set ships with B. No prices change |
| 3 | The first deposit | **A: the popup stays,** with an arrow on PUT ALL IN the first time | B: the first click of all puts everything in straight away | **A.** Hugo's rule (2026-11-20) is that a click never puts a fish in by itself; B would reverse it for the first time only |
| 4 | The pointer's look | **A: marker and trail** of flat yellow arrows | B: marker only, no trail | **A**, one small trial of each on a phone before the art is settled. If the trail is ugly, B loses little: our hub is 56 studs to the strip |

Also asked, smaller: the words (they are placeholders), and whether step 7's 33 seconds feel long. **Proposal, not a pick:** everything else here.

## 7. What couldn't be found out
- **Sound** through the whole opening; **the phone layout** of it; **what happens if you skip, miss or wander off** in the lesson;
  whether the world **truly stops** in the dimmed prompts (it looks near-stopped); the **welcome-back screen** (offline earnings).
- Whether the lesson changed since these videos were made.
- **A recording of a brand-new account's first two minutes** (a fresh Roblox account, phone if possible, sound on, skip nothing)
  would settle most of this. It isn't needed to build the smallest set.

## 8. Not to do here: follow-ups seen
- [Findings](../Findings.md), "What we had wrong", last row: add that the reference itself lays a trail, for a new player only.
- [Loop review](loop-review.md), "The first five minutes, as they play now" is from before the aquarium and the seahorse: out of date.
- [Progression](progression.md) says in one of its older tables that a new player holds the Shallows' Commons **and** Uncommons. By `Config`
  today Sea Turtle (102) and Stingray (104) are over 100. For the tuning chat: meant, or 2 to 4 Oxygen too high?
- [UI](ui.md), "The first minute": this note would replace its three agreed helps if accepted (they are steps 1, 3 and 4 here).
- The caption "GO TO YOUR TANK TO DEPOSIT" shows while the player stands at their tank (`StallController`, `DockNotes`).
- Map chat: check in Studio whether the spawn sees the gap and the DIVE IN words the right way up.
