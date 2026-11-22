---
name: look-check
description: "How to get the Fable advisor's eye on a 3D model or a view in one cheap consult - a creature, a prop, a hub model, a map view, a UI screen - before showing it to the user. Load it whenever a look is ready to judge; the creature-builder helper preloads it."
---

# Look check: one consult, the right picture, a fixed rubric

The advisor (Fable 5.2) reads the whole chat but sees only what is in it. A look consult is worth its cost when the
advisor gets one clear picture, the reference, and a short list of what to judge. Do it once per model or view when it is
ready to show, and once more only if the fixes changed the shape a lot.

## 1. Put the picture in the chat
- **Creature:** `python tools/art/voxel_preview.py <Name>` (one sheet: 3/4, side, front, top, head, a rider on it) at
  `work/voxel/<Name>_preview.png`. Read that sheet. If the gate printed `  !` lines, fix them first: the advisor is not
  for gate errors.
- **The reference:** read the user's concept if there is one (`art/concepts/creatures/`, the drawn notes in
  `art/concepts/creatures/notes/`), or name the real animal and the workout note it follows.
- **Prop, hub model or map view:** one eye-level render or one Studio capture (the `studio-test` rules: one capture per
  message). Read it.
- One picture, not a gallery: a sheet already holds every angle.

## 2. Ask once, with the rubric
Call the advisor with: what it is (name, rarity, land, base size), what it is for (ridden, swum past, seen from the hub),
what to compare against (the concept, the real animal, a model the user already approved), and ask it to judge these, in
order, and to name at most five fixes, most important first:

**Creatures**
1. Reads as its real animal at game distance: the silhouette from the side, top and front.
2. Mass and proportions agree with the animal and with each other (depth, width, length; head to body; fins to body).
3. The user's block language: few big boxes, one per body part; slopes are whole turned blocks, never squeezed; fins and
   tails two or three angled boxes; tapers one step at a time; blocky first, detail second.
4. Joins: no gaps, no overlapping faces; colour bands only a touch proud and never where the body changes size.
5. Rarity budget and eyes as in workout 5 (halo eye for Legendaries, full glow only on a few Mythics), one flaw on rarer
   creatures, a seat for the rider.
6. It is our own creature: nothing copied from another game's character.

**Props, hub models, map views**
1. Reads at play distance; the shape says what it is.
2. Fits the land's colour and value (`docs/design/colour.md`) and the map's rules (the `map-build` skill).
3. Chunky, bright and cheap, in our own look (never the reference's models).
4. For a prop that breaks: built of loose boxes in its break groups.

## 3. Act on it
- Fix what the advice says and the user's rules back. Where advice and a rule the user set disagree, the user's rule wins;
  say so in your report.
- Rebuild, read the new sheet yourself, and consult again only if a fix changed the shape a lot.
- Show the user the final sheet with one line per fix you made.
