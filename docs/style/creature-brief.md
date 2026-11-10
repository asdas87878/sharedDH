# Brief: build one voxel creature
Up: [Home](../../Home.md). The rules of [workout 4](04-voxel-style.md), [5](05-rarity-look.md) and [6](06-textures.md)
boiled down for whoever builds a creature, a person or a Claude agent. It was written for batch building on
2026-11-10; how to run a batch is at the end.

You build ONE sea creature as a model file for an existing kit, check it, and finish it. Work lean: this is a batch job and
tokens matter. Aim for about 20 tool calls. Do not read the long style notes; everything you need is here and in the files
named below.

## Where things are
All paths are from the project folder (the vault). Do not use git; do not edit anything but your own creature's files.
- The kit: `tools/blender/voxel_kit.py`. Read ONLY its opening notes (the model format, down to `class Part`) and
  `class Part` itself (the shapes you can make, down to `class Model`). Do not read the rest.
- Two models to copy the manner of (read both, they are short):
  `art/creatures/ReefShark/voxel.py` (a fish or shark body, snout, jaw, teeth, eye and brow, fins) and
  `art/creatures/Basilosaurus/voxel.py` (a long body in slices on joints, `pose()`, flippers, a fluke).
- `python tools/art/voxel_preview.py <Name>` builds the model and writes `work/voxel/<Name>_preview.png` (3/4, side,
  front, top, head, a rider on it). If it prints lines starting `  !` the gate failed and NO new picture was made: fix
  them first.
- `python tools/art/voxel_finish.py <Name> "one line about it"` runs the gate, the close views and the swim, and writes
  the sheet `docs/attachments/voxel-<name>.jpg` and `voxel-<name>-swim.gif`. It refuses if the gate fails.
- `work/` is not kept in the repo: renders and checks go there. Write temporary things only there.
- Blender is found by `tools/art/voxel_paths.py` (the `BLENDER` environment variable, or `blender` on the path, or the
  newest one installed in the usual place).

## Your file
Write `art/creatures/<Name>/voxel.py`. Conventions: the creature points to -X, up is +Z, coordinates are in cubes of `U`
studs. A cube column j is centred on y = j. Each part is one rigid piece with its pivot at its joint.

## The style (these are rules, learned the hard way)
1. **Big blocks first.** A few big blocks, each a body part. When in doubt, simpler. Half the surface stays plain.
2. **Design from the real animal.** Get its side, top and front outlines right first: depth, width and length must agree
   with the animal's mass, and the parts with each other.
3. **Bodies are slices of cubes** (`hull` with stepped corners), each slice on its own joint for long animals. From one
   slice to the next change ONE thing by ONE cube (width, or back, or belly). A slice is about as long as it is thick.
4. **A slope is a whole block turned** (`beam`, `block`), never squeezed cubes. Snouts are 2-3 tilted blocks in a chain,
   each smaller and starting inside the last. Fins and tails are 2-3 angled boxes, each smaller and thinner than the last
   and starting inside it. Bury every root.
5. **A curved surface is a wide flat plateau and one or two broad steps,** never runs of one-cube terraces.
6. **Colour:** 3-5 named colours. A pale belly under a darker back is usual. No pure black for big areas (use a dark tint);
   black is for pupils. `name-` and `name+` tones are made for you.
7. **Eyes:** a dark pupil block on the side of the head; a cream ring behind it if the animal is friendly. A brow box sits
   on the eye, cuts the top of its square, and comes PAST the eye in front for a mean animal (see the Reef Shark). A
   Legendary may have a thin soft halo round a dark pupil (`GLOW`), nothing more.
8. **Teeth** are small pyramids (`tooth`), bases sunk in. Toothy mouths get a thin dark gum line set INSIDE the lip's edge.
9. **Thin stripes are welcome.** Don't be afraid of thin, continuous stripes running the whole length of the animal
   (one cube row of another colour painted along every slice, or a very thin `band`): they add variety and texture. An
   accent colour works for this. Keep them really thin, and keep them continuous from slice to slice.
   **Raised colour** (a bar, a band) is `band(...)`, 0.3 proud, never where the body changes size. A non-glowing recess
   is `dent(...)` (gills, the rider's leg slot), never a full cube deep.
10. **The rider's seat:** set `SEAT = (x, the back's height, the back's half width)` where the back is biggest, and give
    a `dent` leg slot either side if the back is narrow enough. Leave the seat clear: no spike, fin root or knob there.
11. **Rarity shows.** Common: 2-3 colours, no extras. Uncommon/Rare: one pattern or one odd feature. Epic: bigger, a
    clear idea, at most 2 kinds of extra. Legendary: at most 3, one focal point and one echo. Glow only with a reason.
12. **Scale shows in the build, not in bigger cubes.** Use the cube size given. A big animal gets more slices, more
    teeth, three-step corners where a small fish has one; a small fish stays very simple.
13. **Studs:** add `TEXTURES = [{"tile": "stud", "on": "top", "colours": [<the back's colour name>]}]` (or the placement
    you are given).
14. **A swim:** either `SWIM = {...}` (side-to-side fish) or `pose(parts, phase)` (see the two models). Tails and fins on
    their own joints where it matters.
15. **Quality first.** Lean does not mean careless: never ship something you can see is wrong. Check the side outline
    against the real animal (a belly that curves, a back that arches, a head that isn't a brick), and the eye and mouth.

## The gate (it stops the build)
- No free piece may float: its root must be buried in cubes or another piece.
- No two faces facing the same way may lie in one plane or under 0.05 studs apart (give thickness steps of 0.3 cube).
- A joint's hidden sleeve is sized from the smaller of the two pieces and kept clear of their corner steps.
Read the fault lines; they name the piece and where it is.

## Steps
1. Read the kit lines and the two models. 2. Write the model. 3. `python tools/art/voxel_preview.py <Name>`; fix gate faults. 4. Look at
`work/voxel/<Name>_preview.png` ONCE and fix what is wrong (silhouette first). At most three look-and-fix rounds. 5. `python tools/art/voxel_finish.py
<Name> "<its idea in one line>"`. 6. Look at the swim strip it names once; fix a broken joint if you see one.

## Report (under 120 words)
Its idea in one line; studs long, triangles, parts (voxel_finish.py prints them); what is still weak; nothing else.

## Running a batch (for the chat that hands the work out)
This is how the Shallows and the Coral Reef were built on 2026-11-10 (15 creatures in two batches).
- **One fresh builder to a creature.** Give it this brief and one block about its creature: folder, `NAME, ZONE, RARITY`,
  what the animal is and its one idea, `U` (the cube's size), the length in studs, a triangle limit, and where its studs go.
  A fresh agent that reads only this brief and the two models costs far less than a copy of a long conversation.
- **A foreman to a batch.** One agent starts the builders (at most four at a time), runs the gate on each when it reports
  (`voxel_kit.py ... --check`: one `voxel kit: <Name>:` line and no lines starting `  !`), sends a builder back once if it
  fails, and reports one table. The main chat is then woken once a batch, not twice a creature.
- **Cube sizes used:** 0.35 studs for small fish (9 to 12 studs long), 0.4 for 12 to 22 studs, 0.45 for 22 to 45 studs.
- **Stay on the best model.** The user's rule: never a cheaper model, and never a saving that costs quality.
- **What it cost** (Fable, November 2026): about 185,000 to 215,000 tokens and 9 to 13 minutes a creature; about half a
  point of the weekly all-models limit a creature when a foreman runs the batch.
- **What comes back are first drafts.** They pass the gate and read as the animal; expect a boxy head, a flat belly or a
  stiff outline on some. Mark them "first draft" until someone has worked them over.

## After a batch
1. A sheet of the batch: `python tools/art/voxel_batch_sheet.py voxel-batch3-kelp.jpg "Batch 3: the Kelp Forest" Folder=Name ...`.
2. Game meshes and the queue note: `python tools/art/voxel_export_all.py [Folder ...]` (it rebuilds the table in
   [the creature queue](../design/creature-queue.md) and leaves the rest of the note alone).
3. To check an export: `blender --background --python tools/blender/check_glb.py -- <Folder>`.
4. Tell the chat that has the game code which creatures are new or changed: each needs an upload, and uploads are permanent.

## Trying textures and variants
`python tools/art/voxel_looks.py [part of a name]` renders the looks listed in it (stud placements, gold, rainbow) with
the kit's `--look`; `python tools/art/voxel_look_sheets.py placement|selective|shape|directions|variants|spread` lays
them out as the sheets of workout 6.
