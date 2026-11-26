# Ride a Fish badges

The `badges` branch starts with every badge ID at `0` and `Config.Badges.On = 0`. The six 512×512 icons are in [icons](icons/), with a [contact sheet](icons/sheet.png). The art combines the game's Shallows background and Clownfish render, its Twilight, Midnight, and Underworld land paintings, three Yellow Tang renders, and the level-12 Prismatic trainer render from the seahorse tier builds. The composition uses the game's store-icon treatment and Fredoka type. Each icon fits Roblox's circular crop.

## Award triggers

| Badge | Server trigger |
| --- | --- |
| First Catch | `RideService.OnTamed` after the server completes a tame. The badge service chains the existing lesson callback. |
| Into the Twilight | An active diver reaches `TWILIGHT` inside the surveyed lane, with continuous movement or a validated submarine drop. |
| Midnight Diver | The same check finds `MIDNIGHT`. |
| The Underworld | The same check finds `THE UNDERWORLD`. |
| Fusion! | `AquariumService.fuse` returns a successful result. The badge service wraps that method, which FuseService calls after validating the request. |
| Seahorse Maxed | The server's `TrainerLevel` is 12, including when the save restores an already-maxed seahorse. |

The award service checks Roblox ownership before each award attempt. One worker per player and badge handles the request and keeps confirmed ownership for the session. After three failed attempts the worker waits 60 seconds before trying again. The player can move on once the milestone is earned.

Ordinary dives start tracking in the Shallows. Each later sample must be within the surveyed lane and reachable from the last accepted sample. A badge requires entering the named zone below the surface. Leaving the submarine can start tracking at the trip’s destination when the diver is inside that zone and near the server’s planned drop point during its arrival window.

Taming, fusion, and zone milestones are checked through gameplay after activation. Previously completed taming, fusion, and dives have no retroactive grant.

## Review offline

```sh
python3 tools/badges/setup.py --dry-run
```

A plain invocation also prints the offline plan. It reads no API key, performs no HTTP calls, and writes no files.

Run `lune run tools/badges/award_test.luau` from the repo root to check zone boundaries, submarine arrival, award recovery, and deduplication with a mocked Roblox service.

## Activate later

1. Use an API key for the account that manages the experience. Save it as a regular file with mode `600` at `~/.config/ride-a-fish/roblox-key`. Save the numeric experience **universe ID** at `~/.config/ride-a-fish/universe-id`. The Experimental Open Cloud badge-creation endpoint requires `legacy-universe.badge:manage-and-spend-robux`. [Badge endpoints](https://create.roblox.com/docs/cloud/reference/features/badges#post_legacy_badges_v1_universes__universeId__badges) · [API scopes](https://create.roblox.com/docs/cloud/reference/scopes)
2. When ready, run the following from the `badges` checkout. `--max-robux 100` authorizes up to 100 Robux for this run. Roblox documents five free creations per experience per UTC day and 100 Robux per additional badge. Use `--group-funds` if paying from group funds. [Roblox badge creation limits](https://create.roblox.com/docs/production/publishing/badges#create-badges)

   ```sh
   python3 tools/badges/setup.py --apply --enable-awards --max-robux 100
   ```

3. Review and commit the updated `Badges.luau` and `Config.luau`, then merge `badges` into `main` and publish through the game's normal Studio workflow.

The tool lists every page of the universe's badges before creating anything. It reuses uniquely matching names and keeps their existing pictures and descriptions. If a matching badge is disabled, enable it in Creator Dashboard before retrying. A configured ID that disagrees with the target catalog or a duplicate name stops the run.

With no `--max-robux`, the tool creates only badges covered by the available free quota. If fewer than six can be created or matched, rerun after the quota resets. Each POST carries Roblox's expected cost so a price or quota change cannot silently raise the charge. IDs are written only after all six badges are resolved. `--apply` alone leaves the award switch at its current value. If a create request errors after being sent, check Creator Dashboard for that badge before rerunning. Run one setup at a time for this universe.

If the Experimental endpoint is unavailable for the account, create the missing badges manually in Creator Dashboard using the names, descriptions, and PNGs from the dry run. Then run `--apply --enable-awards` to list and record all six IDs. The badge IDs and switch take effect when those scripts are published.
