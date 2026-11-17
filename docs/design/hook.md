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
| Riding | Whirled lazily over the head, one turn a second, like a rodeo rider's lasso |
| In the hop | Whirled hard and wide, 2.3 turns a second on a 13 stud rope |
| In the hop, a fish locked | It winds up: faster, wider, and the ring leans toward that fish |
| The grab | Thrown at the fish in the first part of the pull-in. It bites with bubbles and a tick, and the rope pulls taut: you are hauled in along it |
| Landed, or the grab refused | It comes back to the hand in 0.22 seconds and is whirled again |
| Floating, the dock, drowning | Put away |

**The rope moves by itself.** It is a chain of 12 points that each keep their own momentum, are dragged by the
water and sink a little. Only its two ends are placed: the hand and the anchor. The whipping and lagging is what
that chain does when its ends are thrown about. Nothing is keyed by hand.

## The dials

All in `Config.Hook`, and the main ones in the N panel under Hook.

| Dial | Value | What it does |
|---|---|---|
| `On` | 1 | 0: no hook |
| `Ride` | 1 | 0: put away on a fish, out only in the hop |
| `Thick`, `HeadSize` | 0.45, 1.4 | The rope's thickness, the anchor's size |
| `Carry` | 0.8 | Lower: the rope streams out further behind you |
| `Drag` | 2.5 | Lower: it whips more. Higher: calmer |
| `RideRate`, `RideRadius`, `RideLength` | 1, 3.4, 7.5 | The whirl on a fish |
| `HopRate`, `HopRadius`, `HopLength` | 2.3, 7, 13 | The whirl in the hop |
| `Wobble` | 0.24 | How much the ring breathes and rocks. 0: a clean circle |
| `LockRate`, `LockRadius`, `LockLean` | 1.4, 1.2, 28 | The wind-up with a fish locked |
| `ThrowShare` | 0.4 | The share of the pull-in the anchor takes to reach the fish |
| `ThrowSlack` | 1.3 | How much loose rope whips out behind the anchor as it leaves |
| `Retract` | 0.22 | Seconds to come back to the hand |

## Tested

Run in Studio by script, 2026-11-17: a dive and three hops by key press.

- The hook was out for every hop and every ride, and put away on the dock.
- Three throws out of three reached the fish: 44, 47 and 74 studs of rope out, then back to the hand at the landing.
- The anchor moved at up to 240 studs a second in the hop's whirl and 580 in a throw.
- Two captures looked at: riding, the anchor and its outlined rope read clearly over the rider. In the hop the
  rider is small at the top of the screen and the whirl reads as a loop beside them.

## Not done, and not known

- **Not seen moving.** Two still captures only. Whether it flails enough is the user's to say.
- **The rider's arm is not raised.** The rope starts at the hand wherever the pose has it. That belongs to the
  pass on character placement and animations that comes next.
- **Other players' hooks are not drawn.** Each player sees only their own.
- **In the hop the name tags can cover the rider and the hook.**
- The sounds are stand-ins (Roblox's own swim and landing sounds, pitched).
- Where it is in the code: `src/client/Controllers/HookController.luau`.
