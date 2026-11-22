# AI setup: Fable 5.2 quality, faster and with fewer tokens

Up: [Home](../Home.md). Set up 2026-11-22 at the user's request. How the Claude chats on Ride a Fish are configured so they
run on the best model (Fable 5.2) but spend far fewer tokens and answer faster. Everything here is in the repo, so both PCs
get it.

## What was wasting tokens (measured 2026-11-22)
- **The game-code chat ("Obsidian chat integration") had a 783k-token context** (78% of its window). A chat re-reads its
  whole history on every step, so each step re-read about 780k tokens. It ran on Opus 5.5 at `max` effort, the setting
  that thinks the longest.
- **Every Ride a Fish chat was started in the FPS folder** (`C:\Users\blast\New folder`), so each one carried the FPS
  game's instructions and memory (24k tokens) on every step, and didn't get this vault's CLAUDE.md on its own.
- **The start-up reading was huge:** "read Sessions at the start" meant about 60k tokens (Sessions is 1,700 lines);
  Handoff is about 86k and Decisions about 45k if read whole.
- **CLAUDE.md was 7.6k tokens**, mostly rules for one area at a time (map, creatures, game code) that every chat carried.

## What is set now
| Piece | Where | What it does |
|---|---|---|
| Model and effort | `.claude/settings.json` | Fable 5.2 (`"model": "fable"`) at `high` effort for every chat started in this folder |
| Compaction | same file | a chat sums itself up at 300k tokens instead of near 1M, so no step re-reads more than that |
| Slim CLAUDE.md | `CLAUDE.md` | 1.4k tokens: the project, the rules, and pointers |
| Area skills | `.claude/skills/` | `game-code`, `creature-look`, `map-build`: CLAUDE.md's area rules, word for word, loaded only by a chat doing that work |
| Procedure skills | same | `studio-test` (driving Studio and its traps), `handoff` (`/handoff`: closes a chat into the vault, with a start message for the next) |
| Helpers | `.claude/agents/` | `scout`, `studio-tester`, `fresh-eyes`, `creature-builder`, below |
| Reading rule | [Working together](Working%20together.md), [Sessions](Sessions.md) | read the top of Sessions (80 lines), search Handoff and Decisions, never read them whole |
| Memory | this PC's Claude memory for the `RideAFish` folder | the Ride a Fish memories copied over, so chats started here keep the user's preferences |

**The helpers** all run on the same model as the chat (Fable 5.2), never a cheaper one. Their work stays out of the main
chat; only their short report comes back:
- `scout`: finds things in the vault and code and returns quotes with `file:line` (low effort: it only looks things up).
- `studio-tester`: runs a Studio check (sync, play, scripted check, console, stop and reset) and returns pass/fail and
  numbers, not console dumps or pictures.
- `fresh-eyes`: reviews a finished piece against its design note and the decisions, instead of a whole second chat.
- `creature-builder`: builds one creature by the brief until the gate passes; several can run at once for a batch.

## Before and after, per step of a fresh chat (estimates from file sizes, about 3 characters a token)
| | Before | Now |
|---|---|---|
| Another project's instructions and memory | 24k | 0 |
| This vault's CLAUDE.md and memory | 7.6k (read by hand) | 3.1k (loaded by itself) |
| Start-up reading (Working together, Sessions) | 62k | 7k |
| Area rules | 0 extra (all in CLAUDE.md) | 1.7k to 3.3k, only the area in use |
| **Total project text carried on every step** | **about 94k** | **about 12k** |

On top of that, compaction caps a long chat at 300k instead of letting it grow to 970k, and `high` effort thinks much less
than `max`. Fable 5.2 at `high` is expected to match or beat Opus 5.5 at `max` on quality (newer models at lower effort
usually match older ones at higher effort), but that is the one thing to watch in the first chats.

## How to work with it
- **Start every Ride a Fish chat in the `C:\Users\blast\RideAFish` folder**, and pick Fable 5.2 in the model menu if the
  app doesn't already show it. Chats started in the FPS folder miss all of this.
- **One piece of work per chat.** When it's done (or the chat passes about 250k tokens), say `/handoff`: the chat writes its
  state into Sessions and Handoff and gives you a start message for the next chat. Archive the old chat after.
- **Effort:** leave it at `high`. Raise it to `xhigh` for one hard bug, then back. `max` is for nothing day to day.
- **Pictures cost the most per step after thinking:** numbers and scripted checks first, one picture when a look is being
  judged.

## Left out on purpose
- **Cheaper models (Sonnet, Haiku).** The user's rule: never trade model quality for usage. Every helper inherits Fable 5.2.
- **Fast mode.** It speeds a reply up to 2.5x, but on a subscription it runs only on paid usage credits at twice the price,
  not inside the plan's limits.
- **The advisor (a cheaper model that consults Fable).** Claude Code has it (`advisorModel`), but it puts a cheaper model in
  charge of the work. Ask if you want it tried.

## Hugo's PC
These files come through the repo, so chats started in Hugo's clone get the same model, effort, skills and helpers. To
change them on one PC only, put the override in `.claude/settings.local.json` (not shared). Claude's memory is per PC, so
the memory copy above is on the user's PC only.
