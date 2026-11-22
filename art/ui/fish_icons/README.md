# Fish icons drawn from our renders

The user, 2026-11-19: "im thinking we could use the icons to chatgpt generate the icons from those. Im thinking ride a
dino probably does that, because their icons show a different geometry to the actual models and its hard for us to
properly replicate it."

**State:** the renders and the reference sheets are made; nothing has been generated yet (an image model costs credits:
the user says yes first, and says which: ChatGPT on their own account, or GPT Image through Higgsfield).

## What is here
- `renders/<Id>.png`: every fish as the game draws it (`src/client/UI/Portrait.luau`), 380 px on white, the same
  angle, size and place for every fish of a kind. Made by `python tools/ui/export_portraits.py <studio_id> --tile 380`
  (Studio in Edit, on screen). `renders/contact.jpg` shows them all, named.
- `sheets/sheet_01.png` to `sheet_10.png`: the renders nine to a sheet (3 x 3, 1536 px square), in rarity order;
  `sheets/sheets.json` says which fish is in which square. Made by `python tools/ui/icon_sheets.py make`.
- `drawn/` (after generating): one transparent `<Id>.png` per fish and a `check_NN.jpg` per sheet (render above,
  drawing below), made by `python tools/ui/icon_sheets.py cut <generated sheet> <sheet number>`.

## The prompt (one sheet at a time, the sheet attached)
> Redraw this 3x3 sheet as nine game inventory icons, in the same 3x3 grid. Keep every creature exactly where it is
> in its square, at the same size, the same angle and the same crop (where a body is cut off, keep the cut). Keep
> each creature's own colours, markings, eyes and teeth, and make every creature's eyes clearly visible.
> Style: a chunky, blocky creature with softly rounded edges, smooth clean shading in three tones (bright top, mid
> side, darker underside), a soft highlight along the top edges, a bold black outline around the outer silhouette
> only (about 2% of a square's width), no thin inner lines, no drop shadow, no glow.
> Pure white background (#FFFFFF) in every square and nothing else in the picture: no text, no frames, no grid lines.

Square output, as large as the tool allows (1536 x 1536 or 1024 x 1024). Try one sheet first and judge it before the
other nine. If a creature drifts in its square, the cut still works (each square is cut alone), but its place in the
slot will differ: regenerate that sheet rather than fix by hand.

## Trials (before the ten sheets; the study and the plan are in docs/design/ui.md)
The trial sheet `trials/trial_sheet.png` (nine fish of different shapes, `trials/trial_sheet.json`) and one fish alone
(`trials/trial_single_megalodon.png`). The trial prompt adds what the study of the reference found:
> Redraw this 3x3 sheet as nine game inventory icons, in the same 3x3 grid. Keep every creature exactly where it is in
> its square, at the same size, the same angle and the same crop (where a body is cut off, keep the cut), and keep each
> creature's own colours, markings, eyes and teeth; make every creature's eyes clearly visible.
> Style: clean stylised 3D game icons. The blocky shapes kept but with softly rounded, bevelled edges; rich saturated
> colours a little brighter than the input; three clear tones of shading (bright lit top, mid side, darker underside)
> with the shadows warmer and more saturated, never grey; small crisp glossy highlights on top edges, fins, teeth and
> spikes; smooth surfaces with no texture noise. A dark, nearly black outline round the outer silhouette only, about
> 2.5% of a square's width; no inner lines. No drop shadow, no glow. Pure white background (#FFFFFF) in every square and
> nothing else: no text, no frames, no grid lines.
For one fish alone, the same with "this creature" for "every creature" and no grid. For method E, add: "Match the
rendering style of the second image exactly." Cut a result with
`python tools/ui/icon_sheets.py cut <result.png> trial art/ui/fish_icons/trials/<method> --plan art/ui/fish_icons/trials/trial_sheet.json`.

## Through ChatGPT (2026-11-19)
The folder to drag into ChatGPT, with the two-step prompt, is `research/fish_icons_chatgpt/` (private: its style sheet
is the reference game's art). Its results go through `python tools/ui/icon_sheets.py align
research/fish_icons_chatgpt/3_results`, which puts each icon back in its render's place, into `drawn/`.

## Then, in the game (not built yet)
Each drawn icon is uploaded (the user's yes) and its id goes in a table the picture code reads; a fish with an icon
shows the image in its slot, on the catch banner and on the end-of-dive tokens; one without still gets the live
render. A new fish works without an icon until one is drawn.
