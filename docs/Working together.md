# Working together

How the user and Claude work on Ride a Fish. Claude reads this at the start of every session. Anything changed here is how
Claude works from then on.

## Who does what
- **The user:** strong in game design, Studio and assets; basic Luau. They block out environments by hand in Studio, because it
  comes out more curated.
- **Claude:** writes the code, makes the models and textures, and enhances what the user builds.
- **Design talks:** pitch ideas in plain, concrete terms and check they're understood before building on them.

## How to work
- **Speed is the point of this project.** It's a quick burner: ship a small first version while the genre is hot. Cut anything
  that doesn't serve the loop or the riding feel.
- **Feel first:** the movement, riding, jumping and animations are what make the game. Build and judge those before content.
- **Do the thing and report briefly.** Take a screenshot only when the result is visual and being judged, or the user asks.
- **Parallel sessions:** independent work in its own session, but only one session drives each PC's Studio at a time.
- **Never use computer use on the user's PC.** If access is missing, ask for a connector or an API.
- **Image generation costs credits:** ask before spending any.
- **Roblox uploads are permanent:** upload only what's chosen.
- **Git:** commit or push only when asked (the Obsidian Git plugin's own syncing is fine).
- **The reference:** copy Ride a Dino's loop and feel, never its look, models or layout.

## Sharing the project (two people)
The user and their partner share one Claude account and work from two PCs. The project is a private GitHub repo,
`asdas87878/sharedDH`. Each clone is the vault and the game at once.
- **Joining:**
  1. Install Git and clone the repo.
  2. Open the folder in Obsidian with "Open folder as vault".
  3. Install the community plugin "Git" (by Vinzent). In its settings, turn on pull on startup and set auto commit-and-sync to
     5 minutes.
  4. Install the other plugins (Dataview, Excalidraw, Kanban) from Obsidian's community plugins. Their settings come with the
     repo.
- **Working:** pull before starting, and don't both edit the same note at the same moment. If the Git plugin reports a conflict,
  ask Claude to sort it out.
- **Claude's memory is per PC.** Anything both people need goes in this vault: this note, Decisions, the design notes.
  CLAUDE.md is read on both PCs.
- **Studio:** there's no shared Studio connection (the user has no ID for it). Each person's Claude drives their own Studio.
  - **Code** goes through Rojo: run `rojo serve` in your own clone.
  - **Things built in Studio** are to be saved as `.rbxmx` model files in the repo, which Rojo loads, with one owner per piece at
    a time. This gets set up when the first Studio-built piece needs sharing.
  - **Anything a script in `tools/studio/` builds** rebuilds from the repo.
- **Uploads** come from the account that owns the game, since animations and sounds only work in their owner's games. One person
  publishes the game.
- **Never commit secrets** (keys, cookies, tokens). The repo is private but shared.

## Studio traps (from the other projects)
- **Captures:** one screen capture per message (two together cost minutes). Blank or dark captures, or 15 fps, mean Studio's
  window is covered.
- **The glb importer** turns each mesh 180 degrees about its centre.
- **Model pivots:** a Model with a PrimaryPart pivots on that part and ignores WorldPivot.
- **Terrain** sits about 2 studs above the written height. Past about 1,024 studs it doesn't load on the client.
- **If the Studio connector fails,** `C:\Users\blast\RpgGame\tools\studio\studio_mcp.py` reaches Studio directly.

## The PC
- **The machine:** i5-9400F, GTX 1660 Super, 16 GB. A realistic low-end target; most players will be on phones.
- **The drives:** C: is a small SSD that's nearly full. D: is a failing HDD, so keep the project off D: and backed up.
