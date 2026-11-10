# Sessions

Which Claude chats are working on Ride a Fish, and what each one has in hand. Every chat reads this when it starts, keeps its
own row up to date, and checks the other rows before touching a file. Set up 2026-11-10 at the user's request, so two chats
can build and check each other's work.

## Who has what
| Chat | Working on | Has in hand (ask before editing) | Studio |
|---|---|---|---|
| [Ride a Fish game concept](claude://claude.ai/epitaxy/local_9fbe7dba-9d58-4cd7-9111-c33fc656abbe) | The creature look: [workout 4](style/04-voxel-style.md) (five voxel creatures in big blocks) and [workout 5](style/05-rarity-look.md) (the rarity look: the Hellmaw redone as a Mythic, a six-tier ladder being built) | `tools/blender/voxel_kit.py`, `tools/blender/kit_common.py`, `tools/art/rarity_ladder.py`, `art/creatures/*/voxel.py`, `art/style/rarity_ladder/`, `docs/style/04-voxel-style.md`, `docs/style/05-rarity-look.md`, `docs/style/Style workouts.md`, `docs/attachments/voxel-*` and `rarity-ladder.jpg`, `CLAUDE.md` (the voxel and rarity lines) | Not using it. Nothing is uploaded |
| [Obsidian chat integration](claude://claude.ai/epitaxy/local_e63fbb3e-8d03-486a-abb0-ff395624b3e4) | Nothing picked yet: linked to the vault 2026-11-10, waiting for the user to say what to build or check | Nothing | |

The links open the chat in the Claude app on the PC it runs on.

## How the chats work together
- **One chat per file at a time.** A chat lists the folders and notes it's changing in its row, and takes them off when done.
  To change something another chat has in hand, message that chat or leave a note below.
- **One chat drives Studio at a time.** Whoever has it writes "has it" in the Studio column and clears it after.
- **The vault is the record.** What the user decides goes in [Decisions](Decisions.md), written by the chat that heard it.
  The other chat reads it there, not from a message.
- **Messages are for now, the note is for later.** The chats can message each other directly (finished something to check,
  need a file, found a problem). Anything that should outlast the moment also goes under Notes.
- **Checking each other:** when a chat finishes a piece, it writes what to look at and where under Notes. The other chat
  checks it with fresh eyes and writes what it found in the same place.
- **Memory:** both chats on this PC share one Claude memory. The partner's PC has its own, so the vault still comes first.

## Notes between chats
Newest first. Date, from, to, the note. Delete a note once it's dealt with.

- 2026-11-10, Ride a Fish game concept to Obsidian chat integration: row corrected. Not using Studio. The rest of
  `tools/`, `art/` and `docs/` is free. When the rarity ladder is done I'll note it here for a check with fresh eyes.
