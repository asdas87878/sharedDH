# Fast food menus, for our Shop

The user, 2026-11-23: "go through the store we have and maybe slightly alter it if needed ... study how large fast food chains
like mcdonalds structure their store, look at their visual hierarchy, how they seperate hard choices, how they drive the user to
buy and things they use to make you really want to buy". Read by the UI chat the same day; what came of it in the Shop is at the foot.

How sure each line is: **seen** (looked at by us), **study** (published research), **chain** (the company says so), **vendor** (someone
selling menus or kiosks says so; treat as a hint). We looked at websites, not a kiosk in a shop.

## What they do

### Visual hierarchy
- **Kinds first, at the side, in pictures.** McDonald's menu: a left rail of 13 kinds, each a small food picture and one or two
  words, the current one marked; the list scrolls beside it. Order: Featured, Meals, Value, then the kinds, sauces last (seen).
- **One big thing at the top**, then a grid of three to a row: a big food photo, a short name, and no price on the menu page (seen).
- **One loud colour for one act.** Yellow is the order button and nearly nothing else; badges are few and in one style (seen).
- **The same best seller in several places.** The Big Mac is under Featured, Meals and Burgers (seen).
- First, second and last in a list are looked at longest (study told by the eye-tracking firm); top left and centre (vendor).

### Making hard choices easy
- **One decision at a time.** Burger, then meal or not, then side, then drink (study: a 12-step walk through one German kiosk).
- **A meal answers four questions at once.** People pick a combo even with no discount: "easier to select a No. 3" (study: Sharpe
  and Staelin 2010, 215 US adults, made-up choices; 15% who had skipped fries took a combo with them).
- **A default.** The Big Mac Meal comes as medium fries and medium drink, with one line saying what's in it (seen).
- **Sizes.** People avoid the smallest and the largest, so a larger size moves them up one (study: Sharpe, Staelin, Huber 2008).
- **Not simply fewer things.** Over 50 experiments, more choice does about nothing on average (study: Scheibehenne 2010); what hurts
  is things hard to compare and not knowing what you want (study: Chernev 2015). So: make it easy to tell apart, don't cut it.
- **The board drops** what few buy, is slow to make and earns little (chain).
- A dear thing bundled with a cheap one can look worth **less** (study: Brough and Chernev 2012, up to 45%).

### Making you want it
- **The picture sells** (vendor: up to 80% more for pictured items; the number is not proven).
- **Nothing to lose by looking.** Kiosk orders came out 5 to 6% larger: people stay longer and pick more (chain).
- **A suggestion that fits the order** near the end (chain; the kiosk study counts the same screen as pressure).
- **Words that say what it is:** "10 favorites, each $3 or less" (seen, Taco Bell).

### What the same shops do that we leave out
The kiosk study's list: the single burger labelled "only", "No thanks!" as the way out, full-screen offers one after another, the total
out of sight, a donation step. Roblox bans misleading content used to sell, and a 2026 University of Sydney study of 15 top Roblox games
names fake discounts, countdowns, inflated "worth" and offers after a loss. Our players are children. **So never: timers, struck-out
prices, "most popular" with no numbers behind it, a shaming "no", a pop-up offer, or extra steps to leave.**

## Our Shop before
- Five cards that sell nothing were on top; every pack we can sell was below the fold, with no way to jump.
- The six cards in a section were alike: same picture, size and colour. "+25M" and "+$2T" meant nothing without doing sums.
- Nothing led, nothing said what a pack does, and the amount was no heavier than the button.

## What changed (2026-11-23)
| From the menus | In the Shop |
|---|---|
| Rail of kinds | Five picture buttons at the left; a press runs the list there, the one in view is lit |
| One big thing on top | Featured is now a real pack: the Oxygen one that fits this player |
| The picture is the size | A pile of 1 to 6 bubbles or cash by its place in the ladder |
| A line saying what's in it | "You: 100 → 50.1K"; "Pays for Racer Seahorse" (coins are the only thing an upgrade asks for); "Adds 1.6%" or "Adds under 0.1%" when a pack is too small to show |
| A default, not a pop-up | Two tags at most a section: FOR YOU (the smallest that at least doubles your Oxygen, or pays for a seahorse level your cash doesn't) and BEST VALUE (most a Robux by the prices shown). None while a pack reads Soon, and no FOR YOU when none helps |
| One loud colour | Orange is only the buy button; one shine, on Featured |

FOR YOU picks the **smallest** that does the job: it can't send anyone to a pack that falls just short, which is what three creators felt
"trolled" by in the reference ([in depth](ride-a-dino-deep.md), section 3).

The window is 110 points wider for the rail; a section's two rows still fit the list whole, so every size is in one look.
*Checked in Studio by script with the real mouse (2026-11-24; not played by hand, no touch screen):* the rail's buttons and both plus
buttons land on their sections and light the right one; every word and pile fits and no tag touches a pile, at 1370x801 and a
phone's 844x390, for a new player, one at 3M and one at 351B Oxygen; as it ships every buy button reads Soon with no tag.
One look check (Fable): its five fixes are in. *To see it with prices:* in Studio, before Play, set the workspace attribute
`ShopPreview` to true (the prices are ours from the agreed ladder, and nothing can be bought).

## Ideas, not agreed
- **A meal:** one button for Oxygen and Cash together. Needs new products, prices and a server grant of two things.
- **The offer where it is needed:** one quiet "Get Oxygen" on the fail screen that opens the Shop there. Others' files.
- **The empty Soon cards to the bottom** (Packs, Passes). The order on top is the reference's, the user's pick.

## Sources
[McDonald's menu](https://www.mcdonalds.com/us/en-us/full-menu.html) ·
[Taco Bell menu](https://www.tacobell.com/food) ·
[Deception by Design, the kiosk study](https://arxiv.org/html/2603.03218v1) ·
[Sharpe and Staelin on combos](https://today.duke.edu/2010/12/value_meal.html) ([more](https://www.fastcasual.com/news/study-people-choose-combo-meals-regardless-of-value-or-size)) ·
[Sharpe, Staelin and Huber on sizes](https://scholars.duke.edu/publication/800043) ·
[Brough and Chernev](https://insight.kellogg.northwestern.edu/article/when_two_products_are_less_than_one) ·
[choice overload: the replications](https://atticusli.com/replication-crisis/choice-overload-jam-study/) ([Chernev 2015](https://evergreenhq.com/?p=22784)) ·
[why McDonald's adds kiosks](https://bigthink.com/technology-innovation/the-secret-to-why-mcdonalds-is-adding-self-serve-kiosks-at-a-rapid-pace/) ·
[eye tracking on menus](https://imotions.com/customer-stories/20-profit-boost-from-menu-redesigns-thanks-to-eye-tracking/) ·
[Roblox: monetization foundations](https://create.roblox.com/docs/production/game-design/monetization-foundations) ·
[Roblox community standards](https://about.roblox.com/community-standards) ·
[University of Sydney, 2026](https://www.sydney.edu.au/news-opinion/news/2026/05/17/inside-the-pay-to-play-world-of-roblox-targeting-children-.html).
Not opened (refused): Chick-fil-A, Wendy's, QSR Magazine, Food Business News and Big Think's own pages (read through search results).
