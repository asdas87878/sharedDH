# Ride a Fish

Ride prehistoric sea creatures deeper and deeper. Tame them, show them off in your tank, earn money, train your breath, dive
further. A quick game in the Ride a Dino genre, going down instead of across. This page links everything. Pin it in Obsidian.

## Start here
- [Code map](docs/Code%20map.md): a way into the game code for someone new: how it starts, who decides what, one dive through the files, every file in a line, every message (2026-11-22).
- [Handing the game over](docs/plans/sale-readiness.md): what another team would be missing today and the stages to put it right, for a sale (2026-11-22; a plan).
- [What to sort in the code](docs/reviews/code-organisation.md): the check of all of `src/`: unfinished pieces, unpicked options left in, dead code, comments, names (2026-11-22; nothing changed yet).
- [AI setup](docs/AI%20setup.md): how the Claude chats run on Fable 5.2 with far fewer tokens: start chats in this folder, one piece of work per chat, `/handoff`, the helpers and skills (2026-11-22).
- [The refinement](docs/Refinement.md): the plan to get every part of the game up to scratch (2026-11-16): where each part stands, ten streams of work, the order, and the questions for the user.
- [What the studies found](docs/Findings.md): one page over the four studies of 2026-11-16, ranked: what to decide first, what to build next, what to test in Studio, what to keep in mind, and what we had wrong.
- [Inbox](docs/Inbox.md): drop ideas and voice-mode brain dumps here, unsorted. Claude files them into the right notes.
- [Handoff](docs/Handoff.md): what each push changed and where things stand. Read it after pulling.
- [Decisions](docs/Decisions.md): what's settled, when, and why.
- [Working together](docs/Working%20together.md): how the user and Claude work on this.
- [Sessions](docs/Sessions.md): which Claude chats are working on what, and their notes to each other.
- [The movement sandbox](docs/sandbox.md): play-testing the ride, the jump and the camera in Studio, with every number open.
- [Blockout](docs/blockout.md): the dock and the long dive, v4 back to v1.
- [The map: how we build it](docs/design/map-method.md): the new direction (2026-11-10): walls in wavy steps, props that break, the descent.
- [The map's structure](docs/design/map-structure.md): matching how the reference builds its walls, squares and studs, pass by pass on a bench in Studio.
- [The map's feel](docs/design/map-feel.md): the lane as a canyon in the sea's floor, a look for each zone, lighting the dark lands.
- [The map before the big push](docs/design/before-the-push.md): the small details and larger things Ride a Dino has that we don't (lip rows, first-layer trees, wall shelves, bunting, far silhouettes, puffs, day and night, events), and the order to build them before one push into the game (plan, 2026-11-19).
- [Fish against their lands](docs/design/fish-values.md): how Ride a Dino's creatures sit in their land's value by rarity (measured), ours measured the same way, and every fish marked keep, recolour or cut (proposal, 2026-11-19).
- [Colour](docs/design/colour.md): how Ride a Dino colours its ten lands (measured), where ours break its rules, and a palette for our lands that copies its values (proposal, 2026-11-19).
- [Breakable props and the later lands' skyline](docs/design/props-and-landmarks.md): how Ride a Dino builds and breaks its props, three ways to rebuild ours (studs, colourways, brick size), and far landmarks seen from the hub (drafts, 2026-11-18).
- [The moving water](docs/design/water.md): the tutorial's four-layer water with foam, drifting and breathing; shows in Play.
- [Map state](docs/map-state.md): blockout v4 as it stood, and the stud tiles. Set aside.

## The game
- [Core loop](docs/design/core-loop.md): the cycle in one page.
- [Archetypes and speed per fish](docs/design/archetypes.md): every creature's own speed and its passive archetypes (fast, predator, breaker and more), in one table.
- [Fusing](docs/design/fusing.md): three fish of a kind become one a size bigger, at the Fuse machine (built 2026-11-25, not played).
- [Riding feel](docs/design/riding-feel.md): the ride, the jump fish to fish and the herd, as built.
- [The sling](docs/design/sling.md): getting from fish to fish: what was weak, the three fixes on switches, the feel log and the M key (built 2026-11-17); fast fish no longer refuse a hook or drop you off, and the hands-off hook comes when the reference's does, 1.7 s after the jump (2026-11-18).
- [The long hook](docs/design/long-hook.md): a hook onto a far fish feels far and lands hard: the long shot (the camera), the rush and the thud, the word (built 2026-11-18).
- [Feel review 3](docs/reviews/feel-review-3.md): the hook's speed against the reference's, 49 of its hooks read frame by frame: ours is about twice as fast (2026-11-19).
- [Feel review 2](docs/reviews/feel-review-2.md): the hover, the landing snap, the throw's punch and the herd at 0.85, measured against review 1; then 20, 30 and 40 fish per 1,000 over 100 hops each (2026-11-19).
- [Feel review 1](docs/reviews/feel-review-1.md): Ride a Dino's loop measured against ours, what makes theirs satisfying, where ours is weaker and stronger, what to change; to be run again (2026-11-19).
- [The lock](docs/design/the-lock.md): the hook takes the fish in front of you, where the camera looks; A and D step it to the next fish that way; it reaches further straight ahead just after you launch; the reach counts the whole fish, head to tail; a press always grabs if a fish is in reach (built 2026-11-18).
- [The wild ride](docs/design/wild-ride.md): the rider locked to the fish's back, fits while you ride, the rodeo pose, and the camera that goes with it (built 2026-11-17); the stride, the fish's steps left and right (2026-11-18).
- [The hook](docs/design/hook.md): the anchor on a rope the rider whirls and throws to reach the next fish (built 2026-11-17).
- [The dive-in, and the speed of the sea](docs/design/dive-in.md): a plan (2026-11-16) for the first seconds from the gate to the first fish, and for what speed should mean to the player.
- [The first minutes](docs/design/first-minutes.md): how Ride a Dino teaches a new player, second by second, and what ours should show: where to go, the deposit, the seahorse (study and proposal, 2026-11-23).
- [The dive](docs/design/the-dive.md): riding, jumping, taming, the zones going down.
- [The dock](docs/design/the-dock.md): the hub, your tank, the stations.
- [The hub's layout](docs/design/hub-layout.md): the dive-in strip, the walls round it, the space behind the tanks (study, 2026-11-20).
- [UI](docs/design/ui.md): what the player sees on screen: the dive's HUD and the dock's screens (proposed, with mock-ups).
- [The leaderboards](docs/design/leaderboards.md): three boards in the hub, who is on them, how they look (on a branch, 2026-11-25).
- [Creatures](docs/design/creatures.md): what's decided about the creatures, tags, sizes and mutations.
- [Roster](docs/design/roster.md): the scale against Ride a Dino and three drafted progressions (76 creatures).
- [Creature queue](docs/design/creature-queue.md): the voxel models exported and waiting to go into the game
- [Creature import](docs/design/creature-import.md): what goes into the game next, the user's picks, and the steps
- [Creature brief](docs/style/creature-brief.md): how to build a voxel creature, and how to run a batch of them
- [Workout 7: telling creatures apart](docs/style/07-shape-variety.md): shape, mouth, colour and mark; a trial on four sharks
- [Workout 8: colour treatments](docs/style/08-colour-treatments.md): eight ways to add colour by rule, and a ladder by rarity; a trial
- [Workout 9: fifteen early creatures remodelled](docs/style/09-early-remodels.md): the dull ones of the first four zones redesigned; 4 of 15 built, stopped
- [Workout 10: the huge shark and five more](docs/style/10-sharks-round-2.md): six shark-chart trials and Megalodon V3
- [Workout 11: the wow of rare creatures](docs/style/11-rare-wow-study.md): what Ride a Dino's rare dinos do (variants, full-strength hues, glow as shapes, a bright shell) and what ours lack
- [Cosmic](docs/design/cosmic.md): a rarity above Mythic, proposed, and a book of effect, lighting and gimmick ideas; a draft
- [Money and Robux](docs/design/money.md): income, upgrades, what's for sale.
- [First version](docs/design/first-version.md): what ships first and what waits.

## The look
- [Style workouts](docs/style/Style%20workouts.md): the numbered style tests and what's been picked.
  - [1. Going down, and the ocean round it](docs/style/01-going-down.md)
  - [2. The creature look](docs/style/02-creature-look.md)
- [Creature method](docs/style/creature-method.md): how every creature is designed and built, and how references are used.

## The reference
- [Ride a Dino breakdown](docs/reference/ride-a-dino.md): how it works, from the user's recording.
- [How its map is built](docs/reference/ride-a-dino-map.md): floor, walls, breakable props and the hub.
- [Ride a Dino, studied from the outside](docs/reference/ride-a-dino-deep.md): its first minutes, systems, money, why it works, where it is weak, and what our team was missing.

## The studies (2026-11-16)
Start with [what the studies found](docs/Findings.md). The evidence:
- [Lighting](docs/reference/look-lighting.md): how stylised Roblox games are lit, with numbers and 15 tests for Studio.
- [Fast food menus](docs/reference/fast-food-menus.md): how the big chains lay out a menu and make choosing easy, and what our Shop took from it.
- [Buildings and props](docs/reference/look-assets.md): how stud-style games build hubs, plots and stalls, our brief checked, 17 tests.
- [Creators and trending games](docs/reference/creators-and-trending.md): who to learn from, who to skip, what the trending games share.
- [Roblox videos](docs/reference/roblox-videos.md) and [repos](docs/reference/roblox-repos.md): the earlier surveys.
- [How Reddit and YouTube are read](docs/reference/research-tools.md): the two readers in `tools/sources/`.

## For Claude
- [CLAUDE.md](CLAUDE.md): the project's instructions.
