# Land motion: riding the ride fish in the hub, by body type

Hugo, 2026-11-20: riding an equipped fish on land, each body type moves in its own way (the turtle slides with its
limbs paddling, fish flop forward in little hops, the octopus pulls itself with its tentacles, the seahorse hops on
its tail, and something fitting for every other body). Built by NULLROOM task e4 from the plan's E4
([plan](../plans/2026-11-20-oxygen-equip-landride.md)), on top of [the ride fish](equip.md) (task e3). Numbers in
`Config.LandRide`; code in `AnimController` (the "On land" block). Not played by hand.

## Decided (built)
- **All procedural, on the creature's own joints** (its `Rig_<part>` Motor6Ds from the mesh.json pivots): no uploaded
  animations. Every joint is written afresh from rest each frame. The underwater layers (the keyed swim, the slow wave,
  the fits, the buck, the landing's reaction) are not used on land.
- **The Root never moves:** RideService's humanoid does the walking (`Equip.LandSpeed` 32). Hops, heaves and lunges
  are the body joint's shift; the rider is locked to the part they sit on (`Animation.RiderLock`, as underwater), so
  they rise, roll and lunge with it and stay seated. The camera follows the walker, so it doesn't bob.
- **The stride follows the walk:** its pace and size come from how fast the fish really moves (0 standing to 1 at
  full land speed, eased by `Blend`). Stopping settles it into a rest pose with a slow breath and the fins stirring.
  Turning leans the body into the turn (less for wide, flat bodies; less when spun on the spot), the head chain leads
  and the tail chain trails.
- **Size:** a longer animal strides slower (`Slow`) and hops more studs but not more times (`Heavy`); a giant's angles
  are calmer (`BigCalm`). The same land speed for all.
- **The floor:** a roll or a pitch lifts the body by what its core (no limbs, no arms) would sink (`Keep`). Limbs and
  arms that would dig in on the down-stroke only lift (`LimbDown`, `ArmDown`). Checked on the flat dock only: no part
  sank more than the check's tolerance, 12% of its height (0.6 studs at least) through a stride; that is a loose bound,
  not "nothing sinks" (grade issue 13).
- **The ground under it** (2026-11-22, grade issue 7, `groundFit`): three rays (under the nose, the middle and the
  tail; never fish, riders or held fish) a few times a second; the body tilts to the floor's slope (at most
  `LandRide.GroundTilt` 18 degrees) and lifts when an end would sink into a step (at most `GroundLift` 0.6 x its
  height), both eased (`GroundBlend`). Past a ledge's edge a ray finds nothing and that end is left as it is.
- **The rider:** astride (the same pose as underwater, no rodeo arm), leaning forward a little with speed and into
  turns; the hops come through the seat and the whiplash. This replaces e3's stand-in (the avatar's sit animation),
  which since 2026-11-22 plays only if `LandRide.On` is 0 (grade issue 6: one pose writer).
- **Two players:** every machine animates every land fish in `Workspace.LandFish` (registered with the animator next
  to `Workspace.Fish`), from the replicated walk. The stride's phase starts from the server's mount time
  (`LandEpoch` on the model) and is set back on that shared clock whenever the fish stands still, so two machines
  agree at every stop and on a fish first seen mid-walk; while walking each runs it on from its own view of the walk
  (grade issue 10; not yet compared on two clients). Far or behind-the-camera land fish are moved less often, as wild
  fish are; your own is always moved. A rider stays locked to their fish on the frames it is not moved (grade issue 9).

## The body types (82 kinds, each once: `Config.LandRide.Kinds`)
A joint's role is worked out once a fish from its rig: the head chain and the tail chain (the spine), limbs (the
first part off the centre line on each side and the segments out from it: side fins, flippers, wings, legs), arms
(names `A1a`, `T1a`, `TRa`, `Tendril*`, `Skirt*`, `Arms`: tentacles, a jelly's skirt and arms), jaws, and the rest
(dorsal fins, crests, rods).

| Body type | Kinds | What it does |
|---|---|---|
| Flop (18) | BlueChromis, SergeantMajor, YellowTang, Butterflyfish, Clownfish, FlyingFish, Angelfish, Parrotfish, Lionfish, Garibaldi, Viperfish, HumpheadWrasse, GiantSeaBass, GoliathGrouper, Barracuda, Swordfish, Xiphactinus, Dunkleosteus | rolls onto each flank, a short hop as it rolls upright, nose up on the hop, tail flick; big and armoured ones roll less and hop lower; the Flying Fish opens its wings on each hop |
| Turtle (3) | SeaTurtle, Archelon, GraveTurtle | shell low, flippers paddle in a diagonal stroke (front right with back left), a little roll, head nodding |
| Seahorse (1) | Seahorse | upright; the tail curls under, then kicks it up into a hop; head and fin follow late |
| Tentacle (2) | Octopus, Kraken | the arms reach and pull one after another round the ring, the mantle rocks; the Kraken slower |
| Squid (2) | GiantSquid, Cuttlefish | the arms all pull together and the mantle scoots ahead; the Cuttlefish's fin edge ripples |
| Ray (5) | Stingray, MantaRay, ElectricRay, CinderRay, GraveRay | the wings lift one side then the other in a wave out to the tips, the body shuffles, the tail trails |
| Slither (12) | MorayEel, BrimstoneEel, WraithEel, PearlSerpent, StormSerpent, EmberSerpent, CoralDragon, LanternLeviathan, BoneLeviathan, KelpWyrm, Basilosaurus, BobbitWorm | an S-wave down the body, head leading; the Bobbit Worm also ripples up and down |
| Crawler (3) | SeaScorpion, GiantIsopod, Anomalocaris | legs in a wave from back to front, one side half a step behind; the body low |
| Shark (12) | ReefShark, LeopardShark, GreatWhite, HammerheadShark, Sawfish, Helicoprion, GoblinShark, FrilledShark, Megalodon, MoltenMegalodon, HalfboneMegalodon, HellfinShark | a strong tail sweep shoves a low chest lunge each side, the body yaws against it, the jaw works; the Frilled Shark waves along its whole length |
| Whale (9) | Dolphin, Orca, BlueWhale, GalleonWhale, Livyatan, Shonisaurus, VoidWhale, PhantomWhale, StellersSeaCow | the belly heaves up and settles, flippers push together, the tail flexes up and down; the Dolphin quick, the giants slow |
| Reptile (6) | Mosasaurus, Dakosaurus, Elasmosaurus, Liopleurodon, Kronosaurus, SeaLion | flippers in opposed pairs, the torso sliding, the tail swinging, the head leading (the Elasmosaurus' long neck most); the Sea Lion galumphs on its front flippers |
| Bulbous (7) | Boxfish, Pufferfish, Anglerfish, InfernalAngler, SkullAngler, AbyssalWatcher, Hellmaw | rolls side to side on stubby fins with small round hops; the lure lags; the Hellmaw hops heavier |
| Jelly (1) | AuroraJelly | the skirt and arms reach to the floor and pull it forward in short scoots |
| Stomp (1) | TheDevourer | a low heavy heave and drag, the tail hauled behind, the jaw working |

**Rigs without the limbs their type wants** (body motion only, by `landInfo` in the check): most fish and all the
sharks (no fin joints: the flop and the lunge are body and tail), the eels and serpents, the Dolphin, the Octopus and
Kraken's mantle (arms only), the Seahorse, the Hellmaw, the Devourer, the Aurora Jelly (arms only) and the Electric
Ray (no wings: its body rolls more instead, `NoLimbs`). The Giant Isopod has no legs, only antennae: it ripples its
segments and waves the antennae. A future crab needs an entry in `Kinds` (a kind with none flops and warns).

## How it works
- `Config.LandRide`: the common numbers, `Base` (every field), `Profiles` (the 14 body types), `Kinds` (each kind's
  body type and its own changes). `Config.landStyleOf(id)` merges them once a kind (so a change there needs a new play).
- `AnimController`: `landRigOf` sorts the joints by role; `landStep` writes them each frame; the rider's state
  "Land" (the player's `LandMounted` on the dock) is posed astride and locked to the seat.
- **For the partner's hand animations:** `AnimController.LandHook(fish, style, phase, move)`: return true and that
  frame the fish's joints are left alone (the rider stays locked to the seat). `style` is the body type's name,
  `phase` the stride's clock in radians, `move` 0 standing to 1 at full speed. Also listed in
  [archetypes](archetypes.md#animation-hooks).
- **Studio only:** workspace attributes `LandClock` (seconds; holds the stride) and `LandMove` (0 to 1) freeze the
  motion for recordings.

## Checked
`python tools/studio/e4_land_check.py install`, `studio-run.mjs play`, `... run` (log `work/e4/check.log`): 10 of 10.
Every one of the 82 kinds built as a land fish and set up with its own body type; every one moves through a stride;
standing, each settles to the idle stir; nothing sinks past the 12% tolerance above; Q rides the Sea Turtle, animated as ours; the
rider's torso rises and falls with the body; walking at 32 drives the stride (0.96), stopping settles it to 0.
`... gifs` records `docs/attachments/e4-land-a.gif` to `-d.gif` (frozen clock, one stride, real speed).

## Open
- Nobody has played it by hand, nor with two players at once; how the motion reads at speed is the first thing to judge.
- Giants at true size (option F) are as big as e3 left them: the motion is calm, but a Colossal fish still fills the hub.
- Ground following, slopes, steps, hub bounds and walls belong to the land movement (RideService, the humanoid): the
  fish's Root stays where the walker is; on a step its body doesn't tilt to the slope.
- The numbers are first guesses tuned only against the checks and the GIFs.
