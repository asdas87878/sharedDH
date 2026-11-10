# Creature method

How every creature is designed and built, so the set stays cohesive while still borrowing from references. Agreed 2026-11-09;
step 6 is the user's addition.

## Why
References look better, but they tie the model to a picture's proportions, which don't hold up in 3D, and each creature ends up
belonging to a different picture, so the set stops feeling like one game. A picture mixes three things: the design (features,
colours, how chunky), the drawing (perspective, a pose, cheats that only work from one angle) and the light (shadow and highlight
in the colours). Only the design survives into 3D.

Two more traps in this game: you mostly see a creature from behind and above while riding (references are side-on portraits),
and the water colour tints everything ([workout 1](01-going-down.md)).

## The steps
1. **Read the references, don't match them.** What they all share is the style; it goes in the style sheet. For each creature,
   note its two or three signature features and its colour scheme.
2. **One kit for every creature:**
   - **The body** is 4 to 6 chunky segments along a spine. That's also how it swims: each segment follows the one in front, so
     every creature moves the same way.
   - **Shared pieces:** one set of fins, eyes and teeth. The eye comes in two looks, picked by the concept: a cream square
     with a black square in it, or a plain black square (the user, 2026-11-09).
   - **Colours:** 3 or 4 flat colour areas (body, belly, accent, eyes), so the Silver and Golden versions and the Tiny to Giant
     sizes come almost free.
   - **Proportions** come from the kit's rules, not from a picture.
3. **Build one hero creature first** (the Mosasaurus): shape first, then colour. Judge it in Studio from the riding camera, in the
   reef's water and the twilight's, at game distance.
4. **For a colour target if we need one,** Claude renders the 3D creature and writes a prompt, and the user has ChatGPT paint over
   that render. The result already has our proportions, so it maps straight back onto the model.
5. **Lock it in:** the hero creature's rules go in the style sheet. Every later creature is the rules plus its own signature
   features.
6. **The shape pass** (the user's addition): if ours looks less cool than the reference, Claude brings the reference's shapes into
   the design.
   - **Compare like with like:** our creature rendered at the reference's angle, side by side, plus a view from the riding camera.
   - **Name the shapes that make it cooler:** say a jaw jutting past the snout, fins like swept blades, a bigger head, spikes down
     the back. The user can circle them on the picture, or draw the planes they want over our render in red;
     `tools/art/lines_overlay.py` maps those lines back onto the renders to check the rebuilt model against them.
   - **Bring each one in as a kit change, not a one-off edit:** a new piece, or a rule such as "a predator's head is a third of
     its length". Every creature can then use it, and the set stays together.
   - **Rebuild it for the game's 3D view:** a shape that only shows side-on gets pushed where the riding camera sees it, like the
     back or the width of the head.
   - **Keep or drop each shape** by a before and after from the game camera.

**Proposed additions** (2026-11-09, from the first three concepts after the Sergeant Major, not agreed yet): rules for every
creature and three body plans (fish, shell, disc) in [workout 3](03-creature-set.md).
