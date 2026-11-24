# The second hunt (2026-11-24, game code chat)

The user: play it again "from the perspective of a 16 year old with a short attention span who is skeptical of these types of
games"; tweaks and small features only. Nothing in the game was changed. How: 13 scripted dives at 100 Oxygen plus one
key-mashing dive and one short one, with loggers (Studio was not drawing 3D, so no looks; no phone; nobody heard the sounds),
an economy simulation (`work/hunt/economy_sim.py`, absolute minutes about 30% either way), and the code read by four readers.
[seen] = seen in the running game; [code] = read in the code; [sim] = simulated.

**The dives:** median 32 s, 6 fish of the 7 the hands hold, 1.3 landings a dive on a fish too strong. One catch every 4 s, always
the same 1.9 s tame, hop and chime.

## Reward loop
1. [seen] Tank's 7 places full by dive 2 or 3; every deposit then says "+$0/s!" (`AquariumService` 663, 710; `TankPrompt` 77). Put
   All In closes the window that has Equip Best (`TankPanel` 1059). Never pressing it: $17/s for 3 hours against $193/s at 10 min [sim].
2. [seen] Put All In sends one message a fish in one instant: up to 7 cash sounds, 7 cards on one spot, no total
   (`AquariumService` 1382); up to 28 model rebuilds [code].
3. [code] Tank stage ($1M) adds two places and fills neither, so income does not move (`upgrade`, 834).
4. [code] The 8th tame of a dive fills its ring and vanishes silently (`RideService` 1686). "New fish replaces the worst carried"
   (progression question 8, unanswered): the biggest single lever, 60-min income 564 to 21.9K [sim].
5. [code, seen] Every catch is the same plate, chime and shake; size and colour are not on the plate (`CaughtText`, `SoundController`).
6. [code] First-catch reward (+100 Oxygen, $200: a whole starter meter) is only in the Index, behind a menu. [sim] subs or not, not
   claiming costs a third of the Oxygen at 5 min.
7. [sim] Land-set reward is under the last fish in it (land 1: 41 Oxygen against Archelon's 390). `SetOxygen` 5, `SetCoinSeconds` 2500.
8. [sim] After the lesson the cheapest price is $15,000 and nothing says so; gaps of 18, 37, 73 min between buys without subs. Free
   sub is worth x3 at 10 min and nothing points at it (`Sub.Free` 1 is decided for now).
9. [code] Income is not on the HUD; coins change with no motion. Buying, claiming, selling and level-ups have no sound.
10. [sim] Colours pay almost nothing (Rainbow Clownfish $4/s against a land-2 Uncommon's $13).
11. [sim] At 100 Oxygen only 36% of coloured fish and none of the Giants in land 1 can be held.

## Diving
12. [seen] The hook takes fish too strong as gladly as any (lock scoring ignores it). One dive ended 8 s in on one.
13. [seen] Mashing hop: land 4 of 10 on the first dive, 77 s, one fish kept. Any small fish you can hold resets the red count
    (`RideService` 897: the user's rule of 2026-11-22 says so).
14. [code] Leaving at 90% tamed, passing your best, low air and the angry fish are silent.

## Errors
15. [code] A copied fish: the equipped or sub-ridden fish is a copy that others can tame once you hop off (`FishService` 1308, 1819).
16. [code, seen] Sounds (mine, today): music group at 0.5; surface music on the sub trip; hop sound on the dive; no preload; a
    tick on the phone's jump button; no mute button.
17. [code] Reset Character keeps "already tamed" (`RideService` 1867). [code] A held right stick spins the next dive's camera
    (gamepad). [code] Sub buy has no tier in its ask: a double click buys two once `Sub.Free` is 0 (`SubService` 528).
18. [code] Ninth player gets no tank and no words; their catch is emptied. Set max players to 8.
19. [code] Saving is off (`SaveParts` 28), and the Index is not in it.
20. [code] Phone: unequip cross 12 px, tank Sell and Take Out 25 px high; the tank's Ride hold breaks as the fish drifts.
21. [code] Robux prices on both upgrade signs with no product behind them; Shop "!" returns every visit to 16 "Soon" items.
22. Not attributed: stalls of 0.2 to 0.65 s a few times a dive, the server and the client at the same moment, no parts arriving:
    likely this PC and a covered Studio. Measure on a phone.

Read with no fault: admin and test keys (nothing reaches normal players), receipts, leaving mid-dive, two players on one fish.
