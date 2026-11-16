# Roblox GitHub repos: what is worth taking

Surveyed 2026-11-16 by a research agent of the game-code chat, on the user's word ("study the top 20 github repos for
roblox development... see if there's anything worth getting"). Stars, last releases, licences and the deprecation
notices were read off GitHub that day. What it means for the game: [the loop review](../design/loop-review.md).

## The verdict
The game has no third-party code and should stay close to that. **One thing is worth taking now, for the next
feature: ProfileStore, for saving.** Two tools cost nothing at run time. Everything else waits for a named need.

## Take now
| What | Why |
|---|---|
| **ProfileStore** (MadStudioRoblox, Apache-2.0, one ModuleScript copied in) | Saving is the next feature and this is the standard: session-locked, autosaving. ProfileService's own README says it is no longer supported and to use ProfileStore |
| **luau-lsp** (editor extension, MIT) | Strict-mode checks with a Rojo sourcemap. Hugo's side already runs it |
| **Lune** (Rokit, MPL-2.0) | Runs plain Luau from the command line: tests for save migrations and economy maths with no test framework |

## Take when we build the thing
| What | When |
|---|---|
| Asphalt (packed image sheets) | The Index needs hundreds of creature icons: fewer downloads, less memory on phones |
| spr, or sleitnick's `spring` | The hub, shop and Index screens: springy UI without a UI framework |
| sleitnick's `shake` | Camera shake beyond what `Lib/Feel` does. Small enough to copy the idea instead |
| Blink (typed, checked buffer remotes) | The remote count grows with shops and trading. Preferred over Zap (mid-rewrite) and ByteNet (stale) |
| Chrono, CullThrottle | Only if measurement shows creature replication or client animation is the bottleneck |
| Cmdr | Products and currency need admin and test commands |
| Vide | Only if hand-built UI becomes painful for the Index and shop. Still pre-release |
| Wally | Only when the first package above is taken |

## Not for this game
- **Knit:** archived. Its author says ModuleScripts cover its role; our Init / Start pattern already does.
- **Roact:** archived, points to React. **react-luau:** heavy for low-end phones and a small codebase.
- **Fusion:** at 0.3-beta for two years.
- **jecs, Matter (ECS):** a rewrite of a working Heartbeat loop for no gain at 600 creatures.
- **Chickynoid:** replaces Humanoid characters; no push since 2024; nothing to do with ridden creatures.
- **DataStore2, BridgeNet2, Red, Flipper, TestEZ, RbxCameraShaker:** stale, archived or superseded.
- **Lyra, Lapis:** their own READMEs say not battle-tested. Lyra's transactions are worth a look only if trading
  ships.

## Techniques worth copying without the dependency
- **Saving, the way ProfileStore does it:** load once, change in memory, autosave about every 5 minutes, save on
  leave and on shutdown, never save after a failed load, a version number with migrations. Keep handled receipt ids
  in the profile and answer a purchase as granted only after the grant is in the profile.
- **Idle income:** work it out from a stored server time when the player comes back, with a cap. Don't tick it.
- **Creatures on the wire:** our herd's paths are already worked out from fixed numbers. If traffic becomes a
  problem, the cheapest fix is to send each fish's numbers once and let clients work out where it is. Next cheapest:
  one buffer a tick over an unreliable remote, about 10 times a second, only fish near that player, 6 to 8 bytes a
  fish.
- **Parking:** moving a model in and out of ServerStorage sends the whole model again. Pooled models on the client
  with bare server logic would avoid it. Measure before changing.
- **Client animation:** a time budget a frame, near and on-screen fish first, writes batched
  (`workspace:BulkMoveTo`).
- **Springs and shake:** a closed-form damped spring stays stable at 30 frames a second; shake as trauma squared
  times noise.
- **Every remote from a client:** check type, range and rate.

## The list
Stars and dates as read 2026-11-16.

| Repo | What | Stars | Latest | Licence |
|---|---|---|---|---|
| rojo-rbx/rojo | File sync (used) | 1.9k | v7.7.1, Oct 2026 | MPL-2.0 |
| JohnnyMorganz/StyLua | Formatter (used) | 2.3k | v2.6.0, Oct 2026 | MPL-2.0 |
| Kampfkarren/selene | Linter (used) | 842 | 0.32.0, Oct 2026 | MPL-2.0 |
| rojo-rbx/rokit | Tool versions (used) | 516 | v1.2.0, Sep 2025 | MIT |
| UpliftGames/wally | Packages | 514 | 0.3.2 stable (2023), 0.4.0-alpha Oct 2026 | MPL-2.0 |
| JohnnyMorganz/luau-lsp | Language server | 567 | 1.70.1, Sep 2026 | MIT |
| lune-org/lune | Luau runtime for scripts and tests | 982 | v0.11.1, Oct 2026 | MPL-2.0 |
| jackTabsCode/asphalt | Assets as files, sprite packing | 167 | v2.0.2, Jul 2026 | MIT |
| 1Axen/blink | Typed buffer remotes, generated | 193 | v1.0.0-pre.11, Nov 2026 | MIT |
| red-blox/zap | The same idea | 190 | v0.6.29, Jun 2026 (rewrite under way) | MIT |
| ffrostfall/ByteNet | Buffer networking at run time | 185 | Mar 2024 | MIT |
| Parihsz/Chrono | Custom replication for server-moved things | 159 | v2.3.0, Nov 2026 | MIT |
| MadStudioRoblox/ProfileStore | Session-locked saving | 354 | no tags; last push Jul 2025 | Apache-2.0 |
| Roblox/react-luau | React 17 port | 591 | Oct 2026 | MIT |
| dphfox/Fusion | Reactive UI | 818 | v0.3-beta, Aug 2024 | MIT |
| centau/vide | Small reactive UI | 359 | 0.4.1, Jul 2026 (pre-release) | MIT |
| Ukendio/jecs | ECS | 486 | v0.11.0, Mar 2026 | MIT |
| Sleitnick/RbxUtil | Signal, Trove, Shake, Spring, Timer, TableUtil | 477 | Aug 2026 | MIT |
| fraktality/spr | One-line springs | 146 | v2.1.0, 2023 (finished) | MIT |
| SirMallard/Iris | Immediate-mode debug UI | 362 | v2.5.1, Mar 2026 | MIT |
| boatbomber/CullThrottle | Throttles thousands of animated things by view and time | 80 | v0.1.0-rc.11, Jul 2026 | MPL-2.0 |

Also looked at: Nevermore, roblox-lua-promise, Cmdr, ripple, charm, ui-labs, jest-roblox, lyra, lapis.

**From the agent's memory, not checked that day:** the Rokit tool ids, ProfileStore's copy-in route, the size limit
of an unreliable remote (about 900 bytes), and the techniques above.
