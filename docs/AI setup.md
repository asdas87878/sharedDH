# AI setup: Fable 5.2 quality on a small share of Fable's limit

Up: [Home](../Home.md). Set up 2026-11-22 at the user's request, changed the same day. **Fable 5.2's weekly limit is what runs
out; Opus 5.5 barely moves the plan's limits.** So Opus 5.5 does the work and Fable 5.2 is its advisor, consulted only at
the moments that decide quality. Everything here is in the repo, so both PCs get it.

## The split
- **Opus 5.5 at `high` effort does the work**: reading, editing, running scripts, Studio checks, the helpers.
- **Fable 5.2 is the advisor** (`advisorModel` in `.claude/settings.json`). Claude Code lets the working model consult a
  stronger one; the advisor reads the whole chat and answers. The rule in CLAUDE.md says when: **before committing to a
  plan for a piece of work, when a bug survives two fixes, before telling the user a piece is done, and for any call on how
  something looks or feels.** Never for lookups, routine edits, running scripts or Studio checks.
- So a piece of work that takes a hundred steps uses Fable three to five times instead of a hundred. Fable still makes the
  decisions that set quality: the plan, the hard bugs, the final check, the look.
- **When a piece really needs Fable at every step** (a hard design problem, a look being worked out with the user): pick
  Fable 5.2 in that chat's model menu for that piece, type `/advisor off` there, and switch back after.

## What was wasting tokens (measured 2026-11-22)
- **The game-code chat ("Obsidian chat integration") had a 783k-token context.** A chat re-reads its whole history on
  every step, so each step re-read about 780k tokens; it ran at `max` effort, the setting that thinks the longest.
- **Every Ride a Fish chat was started in the FPS folder** (`C:\Users\blast\New folder`), so each carried the FPS game's
  instructions and memory (24k tokens) on every step.
- **The start-up reading was huge:** "read Sessions at the start" meant about 60k tokens; Handoff is about 86k and
  Decisions about 45k if read whole.
- **CLAUDE.md was 7.6k tokens**, mostly rules for one area at a time.

These matter twice now: the advisor reads the whole chat on every consult, so a short chat makes each Fable consult cheap.

## What is set
| Piece | Where | What it does |
|---|---|---|
| Worker, advisor, effort | `.claude/settings.json` | Opus 5.5 (`"model": "opus"`), Fable 5.2 advisor (`"advisorModel": "fable"`), `high` effort |
| Compaction | same file | a chat sums itself up at 300k tokens instead of near 1M |
| Slim CLAUDE.md | `CLAUDE.md` | 1.6k tokens: the project, the rules, when to consult Fable, pointers |
| Area skills | `.claude/skills/` | `game-code`, `creature-look`, `map-build`: CLAUDE.md's area rules, word for word, loaded only by a chat doing that work |
| Procedure skills | same | `studio-test` (driving Studio and its traps), `handoff` (`/handoff`: closes a chat into the vault, with a start message for the next), `look-check` (below) |
| The 3D advisor | `.claude/skills/look-check/` | how a model, prop, map view or screen gets Fable's eye in one consult: the chat reads one preview sheet and the concept (so the advisor sees them), then asks once with a fixed rubric (real animal at game distance, mass and proportions, the user's block language, joins, rarity and eyes, our own design; for props and views: reads at play distance, the land's colour, the map's rules) |
| Helpers | `.claude/agents/` | `scout`, `studio-tester`, `fresh-eyes`, `creature-builder`, below |
| Reading rule | [Working together](Working%20together.md), [Sessions](Sessions.md) | read the top of Sessions (80 lines), search Handoff and Decisions, never read them whole |
| Memory | this PC's Claude memory for the `RideAFish` folder | the Ride a Fish memories copied over |

**The helpers** run on Opus 5.5 like the chat. Their work stays out of the main chat; only a short report comes back:
- `scout`: finds things in the vault and code, returns quotes with `file:line`. Never consults Fable.
- `studio-tester`: runs a Studio check, returns pass/fail and numbers. Never consults Fable.
- `fresh-eyes`: reviews a finished piece; consults Fable once, with its draft findings.
- `creature-builder`: builds one creature by the brief until the gate passes, then runs `look-check` (one Fable consult
  on the preview sheet), fixes, then finishes.

## Per step of a fresh chat (measured 2026-11-22 on the two new chats)
| | Old game-code chat | New chat |
|---|---|---|
| Model on every step | Opus 5.5 at max (Fable 5.2 when the limit allowed) | Opus 5.5 at high |
| Fable on every step | yes, when on Fable | no: only at the consult points |
| Context re-read per step | 783k | about 135k at the start, capped at 300k |
| Another project's instructions and memory | 24k | 3k (Ride a Fish's own) |

## How to work with it
- **Start every Ride a Fish chat in the `C:\Users\blast\RideAFish` folder, and pick Opus 5.5 in the model menu.** The
  desktop app uses its own model menu, not the folder's settings (checked 2026-11-22). File chats in the sidebar group
  "Roblox – Ride a Fish". Chats started in the FPS folder miss all of this.
- **Which chat** (sidebar group "Roblox – Ride a Fish"; the retired ones are titled "(old) ..." in "Roblox – Ride a Fish
  (old)"): game code, playtests, Studio, Config, merging Hugo's work: "Ride a Fish game code". Creatures: "Ride a Fish
  creatures". Map, hub, props, water: "Ride a Fish map". Screens and HUD: "Ride a Fish UI". Speeds, spawns, Oxygen,
  prices: "Ride a Fish tuning". Something new: a new chat in this folder. Talk to the chat that owns the work directly,
  not through another chat.
- **One piece of work per chat.** When it's done (or the chat passes about 250k tokens), say `/handoff`: the chat writes
  its state into Sessions and Handoff and gives you a start message for the next chat.
- **Nothing to check by hand.** If Fable's weekly bar still fills too fast one week, tell any chat and the consult points
  get narrowed.
- **Pictures cost the most per step after thinking:** numbers and scripted checks first, one picture when a look is judged.

## Left out on purpose
- **Sonnet and Haiku.** The user's rule: never trade model quality for usage below Opus.
- **Fast mode.** On a subscription it runs only on paid usage credits at twice the price.

## Hugo's PC
These files come through the repo, so chats started in Hugo's clone get the same settings, skills and helpers. To change
them on one PC only, put the override in `.claude/settings.local.json` (not shared). Claude's memory is per PC.
