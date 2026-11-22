# UI: stud fades and motion (research, 2026-11-22)

Up: [Home](../../Home.md). Written by a research helper for the UI chat. It answers two questions from the user:
do good Roblox UIs fade their pattern textures, and which transitions and motion top games use. Sources are
DevForum threads (read as JSON), Roblox's docs, and the captions of three YouTube tutorials (through
`tools/sources/yt.py`). The Reddit archive timed out, so Reddit was not read. **No images were looked at**, so
everything here comes from what people wrote or said, not from screenshots of real games. Checked against what
[UI review 1](../design/ui-review.md) already built.

## Q1. Do good UIs fade their pattern textures?

**Short answer: I found no written evidence that transparency fades on patterns are common.** The one thread that
asks for a fading, scrolling pattern got no working answer ([3597675](https://devforum.roblox.com/t/3597675)). What
the tutorials do show is narrower: the pattern is **turned down**, and a **colour gradient underneath shades it**
from top to bottom. Whether top simulators fade their studs toward the edges or into a corner is still open. Only
screenshots (the user's own references) can settle that.

What the sources show:
- **Stud UIs are their own recognised style.** Grow a Garden is the example everyone names
  ([thread](https://devforum.roblox.com/t/grow-a-garden-ui-example/3764006)). The two biggest tutorials are Kingkade's
  "How To Make Stud GUI" (about 189k views, [video](https://www.youtube.com/watch?v=HjjPZAFaClE)) and Kek's "The
  Greatest Stud UI Tutorial" for the UI Genesis community (about 76k views, [video](https://www.youtube.com/watch?v=gnIKtS3nUqo)).
  Ride a Dino itself has "faint square studs" on the header and a dark studded body ([UI review 1](../design/ui-review.md)).
- **Kingkade shades the studs, he does not fade them.** He tiles the stud image (ScaleType Tile, fixed-pixel
  TileSize) and puts a rotated colour UIGradient on the button. The studs then get darker from top to bottom along
  with the base colour.
- **Kek turns the studs down.** He finds them "too harsh on the eyes" and sets the stud layers to the Overlay blend
  mode, so each stud is only as strong as the colour under it. That goes on the window body and other layers. He
  leaves the header's studs on Normal "for now". Then he exports the result as an image. Roblox has no blend modes,
  so in practice this look is baked.
- **Develuper keeps the brightest colours at the top** ("Make Your Roblox UI Look 10x Better", about 174k views,
  [video](https://www.youtube.com/watch?v=F6AtQKo3uIY)). Shine, stars and texture sit inside a mask with a blend mode.
  Window bodies are plain white with small details, or a see-through black.
- **Feedback threads: patterns behind content hurt.** A pattern behind a header bar was called "distracting and
  confusing" ([980257](https://devforum.roblox.com/t/980257/8)). A see-through criss-cross pattern was told to get a
  solid frame behind it ([1815345](https://devforum.roblox.com/t/1815345/3)). On the other hand, a flat cartoon UI was
  told to add a checkerboard pattern so it "pops" ([963338](https://devforum.roblox.com/t/963338/7)).
- **Not found:** any source saying "pattern on headers and buttons only", a corner-weighted pattern, or a pattern that
  fades behind content. These may well be common, but I could not show it from text.

How each kind is built in Roblox:
| Kind | How |
|---|---|
| Fade top to bottom | Put the pattern on its own ImageLabel (ScaleType Tile, BackgroundTransparency 1) and give it a UIGradient child, Rotation 90, with a Transparency NumberSequence, for example 0.55 at the top to 0.9 at the bottom. A UIGradient on an ImageLabel affects both the image and the background, which is why the pattern needs its own label. |
| Fade to the edges or corners (vignette) | The UIGradient Type **Radial / Elliptical** (fully released 2026-10-29, [post](https://devforum.roblox.com/t/4846594)). Elliptical stretches to the panel's shape. Before this, only linear gradients existed, and anything uneven had to be baked ([2031199](https://devforum.roblox.com/t/2031199/5)). |
| Stronger in one corner | A linear gradient at Rotation 45, or a radial one with its Offset toward the corner. |
| Gradient over the pattern (two layers) | Base frame with a colour gradient, and the pattern label on top at low opacity. Or bake both into one image (Figma Overlay, as Kek does). |
| Baked into the image | Costs memory instead of processing time ([UIGradient docs](https://create.roblox.com/docs/reference/engine/classes/UIGradient)). It is the only way to get blend modes. |
| Fading a whole group | A CanvasGroup with GroupTransparency. CanvasGroups can look low-resolution at some sizes ([2946471](https://devforum.roblox.com/t/2946471)). |
| Slow scrolling | Put the tiled label inside a ClipsDescendants frame and tween its Position by exactly one tile, Linear, RepeatCount -1, so it loops without a seam ([2819198](https://devforum.roblox.com/t/2819198)). If GuiService.ReducedMotionEnabled is on, stop it (Roblox's own advice, [2723187](https://devforum.roblox.com/t/2723187)). |

Release-note tip: animating a gradient's Offset, Rotation or Scale is cheaper than animating its colour or
transparency ([4846594](https://devforum.roblox.com/t/4846594)). A moving fade or a shine should slide Offset, not
re-key the transparency.

## Q2. Transitions and motion

"How common" below is judged from three things: what the simulator UI kits and plugins ship as standard, what
tutorials teach, and what feedback threads mention. Nobody has counted it in actual games. Timings marked *(ours)*
are a starting point I suggest, not taken from a source. Links marked *(title only)* were found in a search and not
opened.

| Technique | How common | Polished or too much | Timings / easing | Sources |
|---|---|---|---|---|
| Pop open (scale up from small) | Baseline, everywhere | Polished if short | 0.3-0.4 s Quint Out, with Back for opening (one developer's habit). Play the close tween before setting Visible false | [994529](https://devforum.roblox.com/t/994529/5) |
| Slide in from a side or the bottom | Very common. A standard preset in simulator kits (From Bottom/Top/Left/Right, Drop, Zoom) | Polished. Can read as slow if it travels far | Park off-screen in Scale units, tween to place. *(ours)* 0.25-0.35 s Back/Quint Out | [4997223](https://devforum.roblox.com/t/4997223), [4916421](https://devforum.roblox.com/t/4916421) |
| Scale + fade together | Common, often through a CanvasGroup | Polished, and the safe "reduced motion" fallback | GroupTransparency 1 to 0 alongside the scale | [UI animation docs](https://create.roblox.com/docs/ui/animation), [2723187](https://devforum.roblox.com/t/2723187) |
| Blur or darken behind a window | Common for big menus. Roblox's docs suggest BlurEffect for this | No feedback found on menu blur itself. A separate thread found camera motion blur while turning "annoying", so keep any blur light | Put BlurEffect under the Camera so it stays local. *(ours)* Size about 8-12 over 0.2 s, or a black frame at 0.5-0.6 | [post-processing docs](https://create.roblox.com/docs/environment/post-processing-effects), [4825295](https://devforum.roblox.com/t/4825295/4) (turning blur, not menus) |
| Camera FOV change on open | Known from PLS DONATE, which zooms out on open and back on close (the poster's description) | Fine once. In another game, FOV changes during a repeated roll got tiring after about 5 minutes | No PLS DONATE values. A reply's sample tweens FOV 70 to 60 (a zoom in) over 0.2 s | [2736751](https://devforum.roblox.com/t/2736751), [4825097](https://devforum.roblox.com/t/4825097/21) (roll, not UI) |
| Shine/gloss sweep on buttons | Very common in the simulator style. A standard toggle in kits ("hover-grow plus shine sweep"), several free modules | Polished on a few key buttons. Too much on every button *(ours)* | Tween a UIGradient across a child frame. *(ours)* 0.6-0.8 s sweep every 3-5 s | [4816664](https://devforum.roblox.com/t/4816664), [4997223](https://devforum.roblox.com/t/4997223), [3555590](https://devforum.roblox.com/t/3555590) *(title only)* |
| Hover grow (and tilt) | Very common. Grow is standard, a small rotation sometimes | Polished if small and quick. One example's 1 s Bounce is far too slow | *(ours)* scale 1.05-1.08, rotation 2-4°, 0.1-0.15 s Quad Out | [4032089](https://devforum.roblox.com/t/4032089/5), [1243736](https://devforum.roblox.com/t/1243736/4) |
| Idle bob / pulse / wiggle | Kits ship them (Pulse, Heartbeat, Jelly, Sway, Wiggle, Bob, Spin) | Draws the eye. *(ours)* too much on more than one or two things | Adjustable cycle. *(ours)* 1.5-2 s Sine InOut loop | [4997223](https://devforum.roblox.com/t/4997223) |
| Staggered card entrances | Seen, and liked in showcases | Polished if short. A long stagger was called "way too long". Desktop systems animate everything at once in one short move | *(ours)* 30-50 ms per card, the whole set done in about 0.35 s | [2225292](https://devforum.roblox.com/t/2225292), [2334223](https://devforum.roblox.com/t/2334223/5) |
| Tab/page switch inside a window | Thin evidence. A fade is the default answer | Unknown | *(ours)* crossfade or a short slide, 0.15-0.2 s | [2175725](https://devforum.roblox.com/t/2175725) |
| Notifications sliding in | Kits ship notification UIs. No timings found | Unknown | *(ours)* slide plus fade, 0.25 s in, about 3 s hold, 0.2 s out | [4884711](https://devforum.roblox.com/t/4884711) |
| Number tick-up | Modules exist (NumberSpinner). No data on how common it is | Reads as polished for money *(ours)* | *(ours)* 0.4-0.6 s, plus a small pop on the label | [4748302](https://devforum.roblox.com/t/4748302) |
| Reward burst (particles) | Wanted for years. Roblox's native ParticleEmitter2D is Studio beta only and **cannot be published yet**. The Spray library works today | Polished on rare moments *(ours)* | Not stated | [4996850](https://devforum.roblox.com/t/4996850), [4905086](https://devforum.roblox.com/t/4905086), [3742009](https://devforum.roblox.com/t/3742009) *(title only)* |
| Slow scrolling backdrop pattern | Kits ship "animated scrolling backdrops" | *(ours)* fine on a special screen, distracting behind content | About 10 s per loop in the example. Linear | [2819198](https://devforum.roblox.com/t/2819198), [4605754](https://devforum.roblox.com/t/4605754) |

General: Roblox's own docs give no recommended durations (their examples use 2 s, which is a demo, not a target).
The default easing is Quad Out. For players with Reduce Motion on, Roblox says to swap fly-ins for fades and stop
motion loops.

**Designers and portfolios: not examined (a gap in the brief).** These leads were found and not read:
- DevForum portfolio threads: [RIPWhipp](https://devforum.roblox.com/t/4559562), [Showy19](https://devforum.roblox.com/t/4462562), [metatablesnow](https://devforum.roblox.com/t/3656083)
- "Show off your UI designs" ([311776](https://devforum.roblox.com/t/311776), about 2,750 posts)
- The unroot creator spotlight ([3077233](https://devforum.roblox.com/t/3077233)). It was read, but it has nothing on patterns or timings.
- Grow a Garden style UI packs on itch.io and BuiltByBit
- Interface In Game and Game UI Database, which unroot recommends for reference

ArtStation, Behance and X were not searched.

## What fits Ride a Fish (ranked proposals to try)
Already built in UI review 1, so not proposed again: the spring open and swell-close, the half dim behind the
stalls, the hover grow and press, the "!" bounce, toasts, the rising "+$N", and the sale total counting down.
1. **Try turning the studs down on window bodies.** Today the stud tile sits at one strength on the header, body,
   buttons and cards (`Shop.Studs`). Give the body's stud label a vertical transparency gradient (about 0.55 to 0.9),
   or the new Elliptical gradient on big panels so the studs fall off toward the edges. Keep headers and buttons as
   they are. This is cheap and easy to undo. It is a proposal: the evidence only says "turned down", not "faded".
2. **A shine sweep only on the money buttons** (Shop, Sell, upgrade). Today the gloss is static and only on the
   Shop's header. Slide the gradient's Offset, which is the cheap way.
3. **A short stagger for the Shop and tank cards, and for the sale's cards leaving** (listed as not built).
   30-50 ms each, done within about 0.35 s *(ours)*.
4. **A reward burst on a tame or a rare catch.** Use the Spray library or a flipbook now, and switch to
   ParticleEmitter2D once Roblox releases it.
5. **A Reduce Motion path:** fades instead of springs, and the "!" bounce stops, when GuiService.ReducedMotionEnabled
   is on.
6. Lower priority: a light blur on top of the stall dim, or a tick-up on the HUD cash (Ride a Dino snaps it).
7. Hold back on these: an FOV change on UI open (fine for one big moment, tiring when repeated), idle bob on more
   than one thing at a time, and scrolling stud backdrops behind content.
