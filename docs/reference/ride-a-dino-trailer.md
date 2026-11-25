# Ride a Dino's page video, shot by shot

From the user's recording of the game page (2026-11-25; the recording has no sound, so nothing here is about music). About
26 seconds. All 40 sampled frames: [sheet](../attachments/ride-a-dino-trailer-shots.jpg). Times are in the video itself,
about 5.5 s behind the sheet's. We copy the order and the framing, with our own fish, map and screens.

| From | Shot | How it is framed |
|---|---|---|
| 0.0 | A rider close up on a Triceratops, whirling a lasso | No HUD. Starts as a blur a hand's width away, pulls back and swings round them |
| 1.4 | A pale T-Rex, running | Side on, full body, low; the animal fills half the width |
| 2.0 | A huge red Spinosaurus, rider tiny on top | Side on, low, fills the frame: the "cool one", about a second in |
| 2.7 | A long-neck dwarfing the rest | From below and behind, so its height reads |
| 3.2 | Real riding: gold ring on the target, the jump, the gold trail | Over the shoulder, still no HUD |
| 4.8 | Desert: a leap between two animals, landing | Same camera, wider; the last second turns to the side on the new mount |
| 7.4 | HUD on. Home: dropping the catch in the pen | Player's camera |
| 8.4 | Pen filling: each equip quicker than the last, $/s tags stacking up | Fixed camera on the pen, jump cuts |
| 10.2 | Riding the training machine, +1s bursting round the head | Behind the rider |
| 12.2 | Machine shop scrolled fast: +12 up to +500 | The window fills the frame, world dark behind |
| 13.6 | Aura shop, sideways scroll | The same |
| 14.3 | Lava, snow, forest: about one second each on a stronger and stronger mount | Behind the mount, its back large in the foot of the frame |
| 17.6 | Fuse: pink burst, then gold, then the result | Wide, whole hub in view |
| 19.0 | Airline: flight down a valley, "NOW ARRIVING" | Behind |
| 21.0 | Whip into one airline card, then its shop of tiers | Zoom through the picture |
| 22.3 | Snow: one long jump onto a Mythic | Wide, its name over it |
| 23.8 | Two best mounts again | Behind |
| 25.5 | "PLAY NOW": letters drop in over a jump onto a giant, then hold | Text fills the width |

**What it does:** every cut is 0.6 to 1.5 s (about 20 shots in 26 s); the first seven seconds have no HUD and are only
animals; blur whips hide the cuts; weak to strong three times over (animals, machines, mounts); no words until PLAY NOW.

## Ours (proposal, not agreed)

| Theirs | Ours |
|---|---|
| Lasso close up | Rider close up on a Clownfish, camera whips back |
| T-Rex, Spinosaurus, long-neck | Sharks, side on, each bigger: Reef Shark, Hammerhead, Great White, Megalodon, Molten Megalodon |
| The jump with the gold ring | The hop, fish to fish, then the leap out of the water |
| Desert leap | Kelp, the trench, then the bone and lava lands |
| Pen filling | Our tank filling, fish by fish, $/s up |
| Machine with +1s | Seahorse level 1 with +4s and an x4, then all 12 levels, half a second each, to Prismatic |
| Machine, aura shops | Seahorse upgrade, auras |
| Lava, snow, forest | Three deep lands on Mythics (The Devourer, Void Whale) |
| Fuse | Our fuse |
| Airline | Submarine, its air hop |
| PLAY NOW | PLAY NOW over a hop onto a giant |

**How it would be filmed:** a trailer mode for Studio only (a list of shots: fish, size, place, camera path, HUD on or off),
played by one key, so every take is the same. Studio's own captures are single pictures about a second apart, so the video
itself has to be recorded with OBS (one press by the user); the cut, whips and PLAY NOW are then put on by a script
(`imageio_ffmpeg` and `cv2` are on this PC). Music is the user's to pick (it must be licensed for Roblox).
