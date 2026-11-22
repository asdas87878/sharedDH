---
name: handoff
description: Ends a Ride a Fish chat cleanly so a fresh chat can carry on without re-reading the old one - updates the chat's row in Sessions, writes a Handoff entry if code was pushed, and gives the user a short start message for the next chat. Use it when a piece of work is done, when the context passes about 250k tokens, before a long break, or when the user says "hand off" or /handoff.
argument-hint: "[what the next chat should do]"
---

# Handing off

A long chat re-reads its whole history on every step, so a fresh chat with a short brief is faster and much cheaper than
one that runs for days. The vault is the memory; this puts the state there.

1. **Sessions** (`docs/Sessions.md`, read only its first 80 lines): bring your row in "Who has what" up to date: what is
   done, what is in hand, Studio free or not. Add one dated line at the TOP of "Notes between chats" if another chat needs
   to know something.
2. **Handoff** (`docs/Handoff.md`): only if code or the place changed: a new `## <date> · <title>` entry at the top, the
   way the others are written (what changed, what was checked and how, what is not done).
3. **Decisions**: anything the user settled in this chat that isn't there yet, as a new top row.
4. **The start message:** give the user, in a code block, a message to paste into a new chat started in the
   `C:\Users\blast\RideAFish` folder (model Fable 5.2, effort high). At most 8 lines: what to do next (from the
   argument, if given), the design note and files to read, what is in hand and by whom, and what not to touch. Name files;
   don't retell the history.
5. Tell the user in one line that this chat can be archived once the new one has started.
