# 06 — Edit mode and idle performance

## Method

`QSG_RENDER_TIMING=1` plus the `qt.scenegraph.time.renderloop` log category,
frames per second counted from the journal's `polishAndSync: start` lines,
plasmashell CPU from `top`, on the lab VM (8 vCPU, virtio GPU) with the
22-gadget board. Edit mode was toggled by a probe inside the deployed
`InfoPage`, so the numbers are the real page, not a synthetic scene.

A first attempt measured the wrong page: KConfig drops keys at their default,
so writing `lastTab=3` over a line that no longer existed changed nothing and
the menu opened on Home. The kit's `settab.py` inserts the key.

## Baseline

| state | fps | render / frame | CPU |
|---|---|---|---|
| Home page open | 2 | 3 ms | ~4 % |
| Info page, edit **off** | 40–57 | 8–10 ms | — |
| Info page, edit **on** | 73–77 | ~12 ms | **220–240 %** |

## Edit mode — what it was

`SequentialAnimation on rotation { loops: Animation.Infinite }` in every
`GadgetHost`. Beyond 22 animations ticking, rotation is the worst transform
for these cards: each content area is clipped, an axis-aligned clip uses the
scissor fast path, a rotated one falls back to stencil clipping — for every
card, every frame.

## Edit mode — what it is

Static: the card scales to 0.965 and gets a 2 px accent outline; the badges
appear. Scale keeps the axes aligned, so the clip stays cheap, and it animates
once on the way in and once on the way out. No loop of any kind.

## The other 45 fps

With edit off the Info page still repainted at 40–57 fps while Home sat at 2.
A bisection paused every gadget (`inViewport = false`) and resumed them one at
a time, six seconds each, measuring the last three:

| gadget | steady fps alone |
|---|---|
| (all paused) | 2 |
| clock | **24** — before the fix |
| cpu | 9 (a 200 ms gauge animation on each 2 s update) |
| every other gadget | 2 |

The 2 fps floor is the search field's cursor blinking; it is the menu's, not
the gadgets'.

Reading the sources then turned up every loop bound only to `host.active`,
i.e. running whenever the menu was open:

| where | loop | now |
|---|---|---|
| Clock | seconds hand swept with a 500 ms animation every second; the minute hand did too (its angle carried a seconds term) | seconds hand ticks; minute hand moves once a minute |
| Weather | icon "floating" ±3 px forever | only under the pointer |
| Battery | liquid wave phase, plus a "breathe" while charging | only under the pointer |
| Live Scores | pulsing dot per live match | static dot + the word LIVE (colour alone was never a signal) |
| Gallery | Ken Burns zoom lasting the whole slide (~9 s) | zoom bounded to the 900 ms crossfade |

## After

| state | fps | CPU |
|---|---|---|
| Info page, edit off | 2–5, bursts to ~20 on sensor updates | ~4 % |
| Info page, edit on | same as edit off | same |

Entering Edit no longer changes the frame rate at all. The remaining bursts
are data-driven — the CPU/GPU/Memory gauges animate 200 ms on each 2 s
reading, and the sparklines repaint on each sample — which is animation that
carries information, and it stops the moment a gadget leaves the viewport or
the menu closes.

## Kept

The pause mechanism (`host.active = grid.active && inViewport && !dragging`)
was audited across all gadgets: every repeating timer and every sensor is
bound to it, and the new Sensor and Fans gadgets follow the same rule.
