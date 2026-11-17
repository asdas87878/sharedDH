# The hook

What the rider throws to get from fish to fish. Built 2026-11-17. It is a picture only: the hop, the lock and the
grab work exactly as before.

The user, 2026-11-17: "we have the hook mechanic, you can hook onto the next fish, but there's nothing actually
doing that. So I'd like to implement a hook, either like a harpoon gun or a grappling hook, whichever works better.
Something that flails about in the air, something that has very dynamic movements, just like it does in Ride a
Dino for the lasso."

## What it is

A small yellow anchor on a rope, in the rider's right hand.

- **Why a grappling hook and not a harpoon gun.** A gun is held still and fires once. The ask was for something
  that flails about, and a hook on a rope can be whirled the way the reference's lasso is.
- **Why an anchor.** It is the sea's own grappling hook, and it is ours: the reference has a lasso hoop.
- It is made of plain parts in code. Nothing was uploaded.

## What it does

| The rider | The hook |
|---|---|
| Riding | Whirled lazily over the head, 0.8 turns a second, like a rodeo rider's lasso |
| In the hop | Whirled harder and wider, 1.6 turns a second on an 8 stud rope |
| In the hop, a fish locked | It winds up: faster, wider, and the ring leans toward that fish |
| The grab | Thrown at the fish in the first part of the pull-in. It bites with bubbles and a tick, and the rope pulls taut: you are hauled in along it |
| Landed, or the grab refused | It comes back to the hand in 0.22 seconds and is whirled again |
| Floating, the dock, drowning | Put away |

**The rope moves by itself.** It is a chain of 12 points that each keep their own momentum, are dragged by the
water and sink a little. Only its two ends are placed: the hand and the anchor. The whipping and lagging is what
that chain does when its ends are thrown about. Nothing is keyed by hand.

## Slimmer and calmer (the same day)

The user: "the model is too bulky and the wire is too bulky ... it flales around in the air too randomly, it should
flale but not like a madman. For bulk thats also included in general size. But i like other parts of it".

| What | Before | Now |
|---|---|---|
| The rope's thickness | 0.45 studs, with a black outline | 0.2, dark brown, no outline |
| The anchor | 3.4 studs long, thick pieces | 2 studs long, pieces about a third thinner |
| The whirl on a fish | ring 3.4, rope 7.5, 1 turn a second | ring 2.6, rope 6.2, 0.8 turns |
| The whirl in the hop | ring 7, rope 13, 2.3 turns a second | ring 4.8, rope 8.2, 1.6 turns |
| The ring's breathing | 24% in and out | 7% |
| Rocking out of the ring's plane | twice a turn | none |
| The ring's tip | 16 degrees | 9, going round half as fast |
| The anchor's own roll | 2 a turn | half a turn |
| The water's drag on the rope | 2.5 | 5 (calmer) |

- **Two things made it a madman, found in the code.** The rope was half as long again as the ring needed, and
  all the spare rope flapped. And the ring's size jumped once every turn: its breathing was counted from the
  whirl's angle, which starts again each turn. It has its own count now.
- **The outline was most of the rope's bulk.** An outline is as wide on screen however thin the rope. The anchor
  keeps its outline; the rope is dark instead, so it still shows against the pale floors (`RopeOutline` 1 puts
  it back).
- The throw, the bite, the taut rope and the pull back are as they were.

## The dials

All in `Config.Hook`, and the main ones in the N panel under Hook.

| Dial | Value | What it does |
|---|---|---|
| `On` | 1 | 0: no hook |
| `Ride` | 1 | 0: put away on a fish, out only in the hop |
| `Thick`, `HeadSize` | 0.2, 0.85 | The rope's thickness, the anchor's size |
| `RopeOutline` | 0 | 1: a black outline round the rope too |
| `Carry` | 0.9 | Lower: the rope streams out further behind you |
| `Drag` | 5 | Lower: it whips more. Higher: calmer |
| `RideRate`, `RideRadius`, `RideLength` | 0.8, 2.6, 6.2 | The whirl on a fish |
| `HopRate`, `HopRadius`, `HopLength` | 1.6, 4.8, 8.2 | The whirl in the hop |
| `Wobble`, `Tilt` | 0.07, 9 | How much the ring breathes, and how far it is tipped. 0: a clean flat circle |
| `LockRate`, `LockRadius`, `LockLean` | 1.3, 1.15, 24 | The wind-up with a fish locked |
| `ThrowShare` | 0.4 | The share of the pull-in the anchor takes to reach the fish |
| `ThrowSlack` | 1.3 | How much loose rope whips out behind the anchor as it leaves |
| `Retract` | 0.22 | Seconds to come back to the hand |

## Tested

Run in Studio by script, 2026-11-17: a dive and three hops by key press.

- The hook was out for every hop and every ride, and put away on the dock.
- Three throws out of three reached the fish: 44, 47 and 74 studs of rope out, then back to the hand at the landing.
- The anchor moved at up to 240 studs a second in the hop's whirl and 580 in a throw.
- After the slimming: a dive and two more hops. The hook was out in every frame of the hops and the rides and
  was thrown as far as 77 studs; each throw was not counted this time. One capture looked at: a thin dark rope
  and a small anchor over the rider.
- Two captures looked at (the first, bulky version): riding, the anchor and its outlined rope read clearly over the rider. In the hop the
  rider is small at the top of the screen and the whirl reads as a loop beside them.

## Not done, and not known

- **Not seen moving.** Two still captures only. Whether it flails enough is the user's to say.
- **The rider's arm is not raised.** The rope starts at the hand wherever the pose has it. That belongs to the
  pass on character placement and animations that comes next.
- **Other players' hooks are not drawn.** Each player sees only their own.
- **In the hop the name tags can cover the rider and the hook.**
- The sounds are stand-ins (Roblox's own swim and landing sounds, pitched).
- Where it is in the code: `src/client/Controllers/HookController.luau`.
