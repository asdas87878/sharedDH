# Roblox development videos: what ten of them teach

Read 2026-11-16 by a research agent of the game-code chat, on the user's word ("analyse the top 10 youtube videos on
roblox development... download and transcribe any necessary material"). All ten were read as full transcripts
(YouTube's own captions; no video or audio was downloaded). Summarised in our words. What it means for the game:
[the loop review](../design/loop-review.md).

**How they were picked:** substance over views. The talks from Roblox's own conference, by people who shipped hits,
have 5,000 to 70,000 views and say the most. The high-view creator videos that were checked were mostly thin.

## The ten
| Tag | Video | By | Views | Year |
|---|---|---|---|---|
| ONETT | [Creating an Intriguing First Time User Experience](https://www.youtube.com/watch?v=TZ14iO23Bpk) | Onett (Bee Swarm Simulator), RDC | 407K | 2022 |
| RET | [The Retention Playbook](https://www.youtube.com/watch?v=YgyfcMfxQcI) | Roblox, with Jailbreak, Bee Swarm, Evade, Gunfight Arena | 7.6K | 2025 |
| LIVE | [Finding Success with your LiveOps Strategy](https://www.youtube.com/watch?v=DxrLfwsfV1I) | Roblox, Tower Defense Simulator's team | 11.7K | 2024 |
| VOLDEX | [Navigating the Difference Between Roblox and Mobile Free-to-Play](https://www.youtube.com/watch?v=Z-ZKqBPdl44) | Voldex, RDC | 7.7K | 2023 |
| MON | [Roblox Game Monetization Explained Like You're 5](https://www.youtube.com/watch?v=zoz3PSMqets) | Tizzy RBLX | 31K | 2026 |
| SILME | [5 Small Changes That Make Your Roblox Game Feel WAY Better](https://www.youtube.com/watch?v=--rrTz9qObY) | Silme | 37K | 2026 |
| DEV | [Make Your Attacks Feel POWERFUL in Roblox](https://www.youtube.com/watch?v=KdARoj-IWds) | Develuper | 21K | 2026 |
| PERF | [Top Game Performance Tales](https://www.youtube.com/watch?v=rwLEnBtXr30) | Roblox: Dead Rails, Grow a Garden | 70K | 2025 |
| OPT | [How to optimize performance on Roblox](https://www.youtube.com/watch?v=VDO_amtWfDw) | Roblox Creators | 123K | 2025 |
| DISC | [What Drives Discovery: Understanding the Algorithm](https://www.youtube.com/watch?v=bkRZeTZAvLw) | Roblox, with Turning Tables and Voldex | 24K | 2026 |

Also read: Mastering Monetization (RDC 2026), "My Roblox Game Makes $119,300/mo" (Tizzy RBLX), a UI buttons tutorial
(PineappleDev).

## The first minute and the first session
- **Curiosity, not explanation** (ONETT): spawn facing the hub where veterans' collections show, with lines of sight
  to places you can't go yet, and one arrow to the first loop.
- **The first loop is cheap and goes round many times** in the first session; costs scale later (ONETT).
- **An arrow is not enough** (VOLDEX, tested): pointing new players at the action raised what they did on day one
  and not whether they came back.
- **What did move retention in tests** (VOLDEX): an easy starter character; an on-rails tutorial against dropping
  players in; a light level system (+7% day 3); a list of goals for new players with a special reward (+10% day 7).
- **They disagree:** Onett uses no real tutorial; Voldex's tests favour teaching; Tower Defense Simulator added a
  tutorial after four years when first sessions fell (LIVE). Our reading: teach the controls plainly, leave the
  world to be found.
- **Measure every step.** Tower Defense Simulator lost 5% at loading and 24% by one step (LIVE). Turning Tables
  treats 40% finishing as an emergency (DISC).
- **Veterans:** new players put against veterans stayed 5 to 15% less on day one. Let them see veterans, not lose
  to them (VOLDEX).

## The loop and the session
- **The activity must change in kind as you progress,** not only in its numbers (ONETT).
- **Timers shape sessions:** loot that comes back every half hour, events every two hours (ONETT).
- No video gave a target session length or a time to the first reward.

## Coming back
- **Plant the reasons in the first session** (ONETT): quests longer than one session; a benchmark that scales
  without end, with reward tiers; gates that say what they need; late-game things shown early at absurd prices.
- **A return should unlock something, not hand out coins** (DISC). This cuts against the usual daily reward.
- **Pace what you add:** two things a week for ten weeks beats ten at once (RET). Alternate features, content and
  fixes, planned 3 to 6 months ahead (LIVE).
- **Keep the early game as simple as at launch;** add depth behind later gates (RET).
- **An event split in parts:** four missions opening 42 hours apart with a month-long pass gave Tower Defense
  Simulator +84% returning players (LIVE).
- **A benchmark:** day-1 retention of about 16% was the top tenth for Voldex's genres in 2023.

## Money
- **Players have small budgets and are rational** (VOLDEX): 61% of spenders had spent 1 to 800 Robux in all. Prices
  of 250 to 400 Robux beat 650. A poor-value starter pack cut spending across the whole game.
- **Most revenue comes from players over 90 days old** (VOLDEX, DISC). So new players are for keeping, not for
  selling to.
- One creator's advice, not tested (MON): sell what repeats as something used up, not as a pass; the best sellers
  take away a pain the player already feels; put the offer where the player already is.

## Feel
The thinnest part: tutorials only, nothing from a shipped hit, nothing useful on movement or field of view.
- Anticipation, then the hit, then the recovery (DEV).
- Hit-stop: freeze the animation for a split second at the hit (DEV).
- Camera shake: small, and dying away (DEV).
- A one-frame flash at the hit (DEV).
- **Every payoff gets a sound and a burst of particles at the exact moment;** music stays under the effects (SILME).
- Buttons grow a little with an overshoot, with a sound, all of them the same way.

## Phones
- **About 500,000 triangles and 500 draw calls in view.** Reuse the same meshes so they batch (OPT).
- **Many players have 2 GB phones.** Crashes climb past about 1.4 GB, which leaves about 600 MB for the game (PERF).
- **Each part costs about 1 KB, more with attributes and tags.** Grow a Garden went from 3 to 45% crashes from
  attributes on parts (PERF).
- Phone processors run at about a quarter of a desktop's. Shadows off on small parts; no big moving lights (OPT).
- On the server: anchoring far creatures and stopping their animators halved the load (PERF).
- Streaming on. Test on a real old phone. Build a tool that spawns the full load (PERF).

## Discovery
- **What Roblox's recommendations count** (DISC): days played, time played, days played with friends on purpose,
  Robux spent and days spent on, over day 1, days 2 to 7 and days 8 to 28.
- Clicking through, and staying after the click, are counted apart and come first. So the icon, title and
  thumbnail matter.
- **Retention ranks first, then money.**
- A quarter of the top 100 recommended games are under 90 days old.
- Fix the weakest number first, against the benchmarks in the Creator Hub.

## If only five things
The agent's own order, from the evidence. The first two have tests behind them.
1. Measure every step of the first session and fix the biggest drop each week.
2. Teach how and give a why: an on-rails first ride on an easy fish with a catch that can't fail, then a list of
   goals whose reward takes more than one session.
3. Build the hub to be wanted: spawn facing veterans' earning fish, show the deeper gates and absurd late-game
   things.
4. Returns that unlock: earnings to collect, a deepest-dive benchmark with tiers, small weekly additions.
5. Run on a 2 GB phone.
