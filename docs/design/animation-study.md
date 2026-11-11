# Animation study
Up: [Home](../../Home.md).

A study with proposals, 2026-11-11. **The first slice (section 5) was built the same day, as seen-only layers in
`AnimController` with `Config.Animation` and `Shared/RideStyles`; see [Handoff](../Handoff.md). Nothing was played.** It is read from the code, and
measured from the swim keys of all 82 exported creatures (`art/creatures/*/game/*.mesh.json`) with a throwaway script in
`work/animstudy/`. Numbers marked "computed" come from the code's own formulas, not from the game running. Every number
in the proposals is a first guess. The user decides what gets built.

## 1. What moves today

| Thing | Where | How it is driven |
|---|---|---|
| A creature's swim | `AnimController.animateFish`; keys from `voxel_kit.py --export`, through `collect.py`, to `Creatures.swim` | One loop of 12 keys for each moving joint, joined by `Lerp`, written to `Motor6D.Transform` every frame. Beats a second = (0.5 + 0.03 x speed) x pace; pace = 14 / length, held between 0.4 and 1.3. The size of the swing never changes. Each fish starts at a random point of the loop |
| The buck | `animateFish`, set off by `DeathController` on "ThrowOff" | The only event the body answers: nose 40 degrees, roll 18, a faster beat |
| A ridden fish's path | `RideController.drive` | Heading comes round to the camera. Pitch only holds `Herd.RideHeight` above the floor. Roll = how hard it turns x `Ride.Bank` (28). Speed ramps over 1.2 s with a 1.25 surge for 0.5 s (`Ease.rideSpeed`), then is constant |
| The fish just left | `RideController.coast` | Straight on, levelling, slowing to the herd's pace over 2 s |
| The herd | `FishService.steer`, on the server every frame | Each fish keeps one place across the lane, one height and one speed (0.85 of its rarity's ridden speed), heading for a point 60 studs ahead. No roll. It shifts sideways only for big obstacles |
| The hop | `JumpController.hop` | Placed by CFrame each frame: `heightAt`, `speedAt`, a 78 degree tilt, an 18 degree bank |
| The rider | `AnimController.pose`, `animateRider` | One fixed pose a state. Every joint eases at one rate (18). Arm bob, strokes and kicks are sines of the wall clock. The landing squash is 0.45 s on the Root joint |
| What is animated | `animateFish` | Every fish within 450 studs of the camera, every joint, every frame, in view or not. The server parks fish beyond 700 studs of every player |

**Cost today (computed, not measured).** `Spawn.PerThousand` is 24 fish to 1,000 studs of lane, so about 22 fish are
within 450 studs on a straight lane. The 33 creatures in the game average 11.6 moving joints (all 82: 13.0; the most are
the Aurora Jelly's 40 and the Giant Squid's 37). That is about 250 `Lerp`s and joint writes a frame, not hundreds of fish:
the 800 is the whole lane. The loop does call `GetChildren` on `workspace.Fish` every frame, which is every fish near
any player.

## 2. What is weak
Most important first.

1. **One loop for ever, the same in every situation** (`animateFish`). Only the beat's rate changes, and only with speed.
   A Clownfish goes from 2.1 beats a second wild to 2.4 ridden (computed): 12% more. Turning, the surge on mount, a
   landing, a crash and coasting show nowhere in the body. The surge is a number in `Ease.rideSpeed` that the fish
   never acts out.
2. **The ride is a rail** (`drive`). After 1.2 s the speed, the height and the roll are constant unless you steer. A ray,
   an eel, a turtle and a whale handle the same; only top speed differs.
3. **The beat is blind to body type.** Pace goes by length alone. Computed: the Sea Turtle flaps 1.8 to 2.0 times a
   second, the Manta Ray 1.4 to 1.6, the Seahorse bobs 2.3 to 2.6, and the Aurora Jelly's "slow pulse" runs 1.8 to 2.1.
   A jaw keyed "once a beat" chomps at that rate for ever (29 of 82 have a `Jaw`). The other way round, every creature
   beats too little for its speed: beats x length / speed is 0.5 to 0.7 for the 16 I worked out, and 1 to 2 for real
   dolphins and whales (Rohr and Fish), so ours slide about twice as far a beat. That reads as a toy gliding.
4. **The rider sits on the Root, not on the back** (`RideService.mount` welds to `Root`; `FishModel` puts `Saddle` on
   `Root`). The body's parts swing under a rider who doesn't move. Measured from the keys, at the seat: Pearl Serpent 2.5
   studs side to side, Kelp Wyrm 2.3 up and down, Bone Leviathan 2.3, Coral Dragon 1.5, Storm Serpent 1.3,
   Basilosaurus 1.2 (the only one of these in the game today). Most creatures are under 0.7.
5. **The herd is on rails** (`steer`). Fixed place, fixed height, fixed speed, no bank in the lane's bends
   (`Turn.CFrame` is a plain `lookAt`), no sign that a rider passed or landed. Speeds differ only by rarity.
6. **The rider's poses are held, not acted** (`pose`). On a fish: a still pose and a 3 degree arm bob that is not tied
   to the fish's beat, the turn or the surge. In the hop: the strokes run on the wall clock, so each glide starts at a
   random point of a stroke. All joints ease at one rate, so pose changes read as one block moving. Other players never
   show the pop or the pull-in pose: `State.JumpPhase` and `State.Reeling` are local, so they see the glide stroke.

**What the best `pose()` functions do that a plain `SWIM` chain doesn't.** A `SWIM` chain is a yaw wave down the spine
with a fixed 2 degree head counter, and nothing else: all 18 `SWIM` creatures move no fin and no jaw (Barracuda,
BlueChromis, Butterflyfish, Clownfish, ElectricRay, FrilledShark, Garibaldi, GiantSeaBass, GreatWhite, HammerheadShark,
Helicoprion, HellfinShark, LeopardShark, ReefShark, Sawfish, SergeantMajor, Swordfish, YellowTang). The authored ones
add: a head that turns against the body's mean heading so the animal keeps its line (the eels); a second rhythm (fins
"twice a beat": Parrotfish, Boxfish, Cuttlefish); a beat that is not a plain sine (the Kraken's arms open slowly and
shut fast); parts that follow late (tails, tendrils, threads); a body that rocks or nods (Archelon, Manta Ray); a jaw.

**Stiffest bodies** (how far the spine sweeps, as a share of length; sharks are 0.2 to 0.35): Brimstone Eel 0.06, Ember
Serpent 0.10, Abyssal Watcher 0.10, Galleon Whale 0.11, Shonisaurus 0.12, Dakosaurus 0.13, Coral Dragon 0.14. The
Brimstone Eel's swim strip shows three frames that hardly differ. Turtles, the Elasmosaurus, the jelly's bell and the
Cuttlefish are rigid bodies by design: their life has to come from the layers below.

**Seen in passing (by reading, not in play):**
- **A likely bug in the buck.** `body.Transform = rot(...) * body.Transform` assumes the keyed loop rewrote that joint
  this frame. Where the first part has no keys it doesn't, so the turn piles up frame on frame and is never reset:
  Cuttlefish and Octopus (both spawn today), Kraken, Anomalocaris, Elasmosaurus.
- The swim's numbers are literals in `AnimController`, not in `Config`, so the N panel can't reach them.
- `Net.Ride` "Mounted" carries a `landing` flag that `RideController` ignores.
- `AnimController`'s opening comment still describes the dash, the hook window, the rope and slow motion.

## 3. Proposals
Ranked by effect for effort. Two ways to add motion, and they differ in risk:
- **Seen only** (in `AnimController`, on every client): an extra turn or shift on the fish's first joint, which is how
  the buck is done already. The Root and the Saddle don't move, and `Lib/Lock` reads the Root, so the lock, the pull-in
  and the server's checks are untouched.
- **Real** (in `drive`, for the fish we own): the Root itself moves. Others see it and the camera follows. Nobody can
  land on a ridden fish, so the only hop it can touch is the rider's own next launch.

**1. The landing: dip, kick and brace.** *Free for all 82.*
- **See:** the fish sinks and noses down under your weight, springs back, and beats hard three times as it surges.
  Your knees fold, your arms fly up, then grab. A small fish dips a lot, a whale hardly.
- **How:** on "Mounted" with `landing`, `drive` kicks a damped spring on pitch and height (real), sized by 14 / length.
  All clients, on the "Land" effect, raise that fish's **effort** for 0.6 s (proposal 3). The rider gets a 0.25 s brace
  pose before the riding pose.
- **Where:** `RideController.onMounted` and `drive` (`Lib/Spring`); `AnimController.animateFish` and `pose`.
- **Cost:** nothing to speak of: one fish, one rider.
- **Risk:** in the Shallows the herd is pressed to 5 or 6 studs above the floor, so the dip must stop at
  `Ride.FloorClearance`. A hop pressed mid-dip (the cooldown is 0.3 s) leaves from a stud lower: harmless.

**2. The turn layer: the body curves into a turn.** *Free for all 82.*
- **See:** steer, and the head leads, the spine bends into a C, the tail trails and comes round late. Wild fish bank
  and bend through the lane's bends and round obstacles.
- **How:** each fish's turn rate (`AssemblyAngularVelocity.Y`, smoothed twice: fast for the head, slow for the tail)
  adds a small yaw to each spine joint on top of its key, and a roll to the first joint. The spine is found from
  `Parts`: the chain from the first part to the rearmost part on the centre line.
- **Where:** `animateFish`; the chain worked out once in `Creatures.swim`.
- **Cost:** one more CFrame multiply a spine joint, only for fish that are turning. A straight herd pays nothing.
- **Risk:** none for the hop (seen only). A joint built to bend up and down may show its seam when bent sideways: hold
  it to 3 or 4 degrees a joint and check the whales.

**3. Effort: bursts, glides and a flinch.** *Free for all 82.*
- **See:** the fish works when it speeds up and eases when it coasts. A crash makes it rear and shake. The fish you
  left relaxes into a glide.
- **How:** one number a fish, 0.5 to 1.6, from its change of speed and from events (landed on, crashed, let go). It
  scales the swing (`identity:Lerp(key, effort)`) and adds to the beat's rate. The crash flinch is the buck at a third.
- **Where:** `animateFish`; `State.CrashAt` already exists.
- **Cost:** one more `Lerp` a joint, only while effort is not 1.
- **Risk:** none for the hop. Whether `Lerp` past 1 swings wider needs one check in Studio.

**4. The body layer by style, with the rider on the back.** *Needs a number per archetype.*
- **See:** a whale rolls up and down under you, a ray sails, an eel snakes, a turtle rocks with each stroke, and you
  ride that motion instead of hovering over it. Wild fish move the same way.
- **How:** each beat, by style (section 4), the first joint gets a heave, a nod, a sway and a rock. For a ridden fish
  the rider's Root joint gets the same shift, plus the seat part's own keyed motion, so the rider stays on the back.
  This also cures weakness 4.
- **Where:** `animateFish` and `animateRider` (the fish's `Rider` attribute finds the character); a style word a
  creature, in `Config` or added by `collect.py`.
- **Cost:** one CFrame a fish in range; a short chain of multiplies for each ridden fish.
- **Risk:** none for the hop: the Saddle stays put, and the rider's shift eases in after the landing. The camera stays
  smooth, because it follows the Root. The seat part is guessed from the pivots today; exporting it would be safer.

**5. The beat by style, and jaws off the beat.** *Needs a number per archetype; the jaw is free for the 29 that have one.*
- **See:** turtles and rays beat slowly, jellies pulse slowly, small fish stay quick. A jaw hangs, and opens now and
  then, or when you lock on to it or land near it. No fish is quite the same from one minute to the next.
- **How:** a `Cadence` number a style multiplies the rate. Parts named `Jaw` are scaled by a slow envelope on a 3 to 8 s
  timer and on events. A slow drift (5 to 9 s, its own for each fish) moves effort by a tenth.
- **Where:** `animateFish`. **Cost:** nothing new. **Risk:** none for the hop.

**6. The rider's secondary motion.** *Free for all 82.*
- **See:** you lean into turns with your head level, rock back on the surge, pump with the fish's beat, and look at the
  fish you have locked. In the hop the stroke starts from the launch, limbs trail, and legs swing forward to sit as
  the pull-in ends.
- **How:** lean from the fish's roll; surge from its change of speed; bob from the fish's own phase, not `sin(t * 6)`;
  the neck toward `State.JumpTarget`; strokes on the hop's clock; a rate for each joint (hips fast, hands slow)
  instead of one. For other players, read pop and pull-in off their speed.
- **Where:** `AnimController.pose`, `animateRider`. **Cost:** players only. **Risk:** none.

**7. The herd as animals.** *Free; strings need a number per species.*
- **a. Weave, bob and pace** (server, `steer`): each fish drifts 3 studs across and 1.5 in height on slow sines (6 to
  10 s), and keeps its own pace within 5%. Two sines a fish a frame. **Risk: low.** The saddle then moves at up to 2 or
  3 studs a second; the pull-in closes on the moving saddle, and the lock is sticky.
- **b. A glance and a startle** (seen only): a fish you pass leans away; a landing, a crash or a broken prop near by
  makes fish roll off and beat hard for half a second. **Risk: none**, the fish don't really move. A real dart would
  pull a fish out from under the aim: not proposed.
- **c. Strings** (server, `spawnFish`): small schooling fish spawn as two or three in a file, 15 to 25 studs apart, the
  followers copying the leader's weave a moment late. **Risk: medium.** Tight balls would leave gaps wider than
  `Jump.GrabRange` (130); a loose file keeps today's spacing.
- **d. A wave down the school** (seen only): start each fish's phase from its place along the lane, not at random.
  Cheap and safe, and the weakest of these.

**8. Cheaper animation, to pay for the rest.** *Free for all 82.*
- Skip fish behind the camera. Past 200 studs, update every second frame; past 320, every third. Keep the list of fish
  from `ChildAdded` and `ChildRemoved` instead of `GetChildren` each frame.
- **Risk:** none for the hop. Worth measuring on a phone before and after: no timing was taken for this study.

**9. A real surge-and-glide for jetters and paddlers.** *Needs a number per archetype.*
- **See:** a squid shoots and coasts, a turtle pulls and glides; the view breathes with it.
- **How:** `drive` moves the speed up and down by `Pulse` in time with the beat (the phase shared from
  `AnimController`); the average is unchanged.
- **Risk: the highest here.** The hop's launch is 1.6 times the fish's speed at the press, so it would vary with the
  beat: `JumpController.request` should then read the steady speed. The server's `Ride.SpeedSlack` (1.6) has room.

**10. New joints where the build is stiff.** *Needs authoring per creature, and a new upload.*
- Fins and a jaw on the 18 `SWIM` chains; wider waves on the stiff serpents. Only after 1 to 5 show what still looks
  dead, because uploads are permanent.

## 4. Ride styles by body type
An archetype is a loose guide (the user's rule), so a style is a starting row and any creature may change one number.
Heave, nod, sway and rock are seen only, each beat. Bank replaces `Ride.Bank`. Pulse is proposal 9. All first guesses.

| Style | Feel | Cadence | Heave (studs) | Nod / sway / rock (degrees) | Bank | Pulse | Dip on landing |
|---|---|---|---|---|---|---|---|
| Darter | light, twitchy | 1.0 | 0.15 | 1 / 3 / 2 | 32 | 0.03 | 1.6 |
| Cruiser | level, heavy head | 0.9 | 0.1 | 0 / 2 / 1 | 24 | 0.02 | 0.8 |
| Snake | S-curves, the tail late | 1.0 | 0 | 0 / 5 / 4 | 18 | 0 | 0.6 |
| Galloper | a rolling up and down | 0.7 | 0.9 | 4 / 0 / 0 | 20 | 0.05 | 0.4 |
| Glider | sails, banks steeply | 0.5 | 0.6 | 2 / 0 / 0 | 42 | 0.04 | 1.0 |
| Paddler | stroke, then glide | 0.6 | 0.5 | 3 / 0 / 3 | 22 | 0.10 | 0.7 |
| Jetter | pulse and coast | 0.45 | 0.3 | 0 / 0 / 0 | 12 | 0.18 | 0.8 |
| Bobber | waddles and wobbles | 0.9 | 0.3 | 2 / 4 / 5 | 14 | 0.03 | 1.4 |
| Crawler | a level raft, rippling | 0.8 | 0.2 | 1 / 0 / 2 | 16 | 0.04 | 0.6 |

- **Darter:** SergeantMajor, Clownfish, BlueChromis, Butterflyfish, YellowTang, Angelfish, Garibaldi, Parrotfish,
  Lionfish, FlyingFish, Viperfish.
- **Cruiser:** ReefShark, LeopardShark, GreatWhite, HammerheadShark, GoblinShark, Sawfish, Swordfish, Barracuda,
  Helicoprion, HellfinShark, Megalodon, MoltenMegalodon, HalfboneMegalodon, Dunkleosteus, Hellmaw, TheDevourer,
  Xiphactinus, HumpheadWrasse, GiantSeaBass, GoliathGrouper, Mosasaurus, Dakosaurus, Shonisaurus.
- **Snake:** MorayEel, FrilledShark, BrimstoneEel, WraithEel, BobbitWorm, PearlSerpent, StormSerpent, EmberSerpent,
  CoralDragon, LanternLeviathan, BoneLeviathan.
- **Galloper:** Dolphin, Orca, SeaLion, StellersSeaCow, Basilosaurus, Livyatan, BlueWhale, GalleonWhale, PhantomWhale,
  VoidWhale, KelpWyrm.
- **Glider:** Stingray, MantaRay, ElectricRay, CinderRay, GraveRay.
- **Paddler:** SeaTurtle, Archelon, GraveTurtle, Elasmosaurus, Kronosaurus, Liopleurodon.
- **Jetter:** Octopus, Kraken, GiantSquid, Cuttlefish, AuroraJelly.
- **Bobber:** Pufferfish, Boxfish, Seahorse, Anglerfish, InfernalAngler, SkullAngler, AbyssalWatcher.
- **Crawler:** Anomalocaris, GiantIsopod, SeaScorpion.

**Not proposed: a turn rate by style.** "One rate on a fish, in the hop and floating" is a decision
([riding feel](riding-feel.md)), and `RideController.steer` is shared by all three. A whale can feel heavy through a
slow bank and a late tail without steering worse.

## 5. A first slice
One small piece of work, in `AnimController`, `RideController` and `Config` only. No new uploads, no server change.

1. **The landing** (proposal 1) with **effort** (3).
2. **The turn layer** (2).
3. **The body layer with the rider on the back, and the beat by style** (4 and 5), for the creatures of the first two
   lands: they spawn today and cover seven of the nine styles.
4. **Every number in a new `Config.Animation` group, on the N panel,** each layer off at 0. And the buck's fix.

**How to judge it, in the sandbox** (N for the panel, V for the side view):
- Ride a Clownfish, a Reef Shark, a Moray Eel, a Sea Turtle, a Stingray and an Octopus in turn. With your eyes half
  shut, can you tell which you are on from the motion alone?
- Hold A, then D: does the body curve and the tail come round late? Watch wild fish take a bend.
- Land ten hops: does the fish take your weight and kick off? Does the surge now look like the fish's doing?
- Set each `Animation` row to 0 and back, to see what each layer adds and whether any is too much.
- Count hops landed out of ten with the layers on and off. It should not change. If it does, that layer is at fault.

## 6. Not checked
- **Nothing was run in Studio.** No frame time, no joint-write cost and no count of fish in view was measured.
- The seat motion and spine sweep come from my own reading of the keys (rigid parts chained at their pivots), with the
  seat part and the spine guessed from the pivots. The sizes are right if `Motor6D` turns a part about its pivot, as
  `FishModel.fromRig` sets up. The buck bug is read from the code, not seen.
- Whether `CFrame:Lerp` past 1 swings wider; whether joints show seams when bent off their axis.
- The swims were judged from the keys and two swim strips (Brimstone Eel, Megalodon), not from all 82 gifs.
- How far a player can see under water (fog), which decides how much the far cut-off saves.
- `Lib/Lock`, `Lib/Course`, `PropService` and the server's checks in `RideService` were only skimmed.
- The reference's dinos: its recordings were not looked at again for body motion, only the notes.

## Sources
Read as search summaries, not as full pages.
- [Rohr and Fish, Strouhal numbers and optimization of swimming by odontocete cetaceans (2004)](https://cob.silverchair.com/jeb/article/207/10/1633/14703/Strouhal-numbers-and-optimization-of-swimming-by):
  fluke sweep 0.15 to 0.25 of body length; beats x length / speed between 1 and 2.
- [Bainbridge (1958), summarised by the USGS](https://www.umesc.usgs.gov/data_library/fisheries/fish_passage/bainbridge.html):
  a fish goes faster by beating faster, with the sweep nearly constant.
- [Godot's "Animating thousands of fish"](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html):
  a swim as layers (side to side, pivot, wave, twist) masked toward the tail.
- [Reynolds' boids, lecture notes](https://www.cs.uaf.edu/2015/spring/cs482/lecture/01_26_boids.html): separation,
  alignment, cohesion. Not proposed in full here: fish that steer by their neighbours stop being predictable to land on.
- [Creating the Art of Abzu, GDC 2017 write-up](https://80.lv/articles/gdc-2017-creating-the-art-of-abzu): many fish
  by maths instead of a skeleton and an animation tree.
- [Roblox's Motor6D reference](https://developer.roblox.com/api-reference/class/Motor6D) and
  [a DevForum request for bulk joint writes](https://devforum.roblox.com/t/bulktransformto-broadened-bulkmoveto/3602053):
  `Transform` is applied in a batch after PreSimulation, and there is no bulk way to set many at once.
