# 11 — Performance and stress tests

## Method

Same instruments as `06`: `QSG_RENDER_TIMING=1` with the
`qt.scenegraph.time.renderloop` category, frames per second counted from
`polishAndSync: start` lines in the journal of the **current** plasmashell
pid, render time from `frame rendered in Nms`, CPU from `top -d 1` samples,
RSS from `ps`. A temporary probe inside the deployed `InfoPage` drove the
timeline so every phase is marked in the same log; nothing was injected as
pointer or keyboard input (the compositor closes the popup on synthetic
pointer warps, and gadget drag ignores synthetic mice). Lab VM: QEMU,
8 vCPU, virtio GPU, Plasma 6.7.4, Wayland, `AnimationDurationFactor=0.5`.

## Stress board: 48 gadgets

The 24-item board duplicated once (every gadget twice, including the
monitors that the gallery would never let you add twice), 4 columns at
start, then the probe's timeline:

| phase | fps (steady) | render / frame | plasmashell CPU |
|---|---|---|---|
| first 30 s after opening (48 gadgets settling: fetches, images, first paints) | 10–26 | 13–14 ms | ~50 % |
| **edit on** | 4–20 (same as before it) | 14–17 ms | 47–52 % |
| edit off | 4–20 | 13–15 ms | 14 % |
| columns → 2 (content 12 247 px) | 2 s burst 32–52, then **4** | 11–12 ms | 34 % (burst) |
| columns → 4 | 2 s burst 27–56, then 5–21 | 13–14 ms | 197 % (burst) |
| columns → 3 | burst, then 4 | — | — |
| programmatic scroll, top → bottom → top, 8 s | 53–67 (vsync-bound) | 14–17 ms | 144 % |
| drag into the bottom zone, auto-scroll 0 → 3003 px in 6 s | 50–59 | 16–18 ms | — |
| drag into the top zone, auto-scroll back to 0 | 52–56 | 17–19 ms | — |
| drag ended, idle | **4** | 10–12 ms | 14–15 % |

Readings:

- **Edit mode costs nothing measurable any more.** Same fps, same render
  time, same CPU as the page without it — with 48 cards. Stage 1 of this
  work measured 220–240 % CPU at 73–77 fps for 22 cards (`06`).
- **4 columns idle at 10–26 fps is data, not animation.** With four
  columns more monitoring cards are in the viewport, and this board has two
  of each: two CPU gauges, two GPU, two network charts, two clocks. Each
  data tick animates a needle or a bar for `longDuration` (100 ms here, ~6
  frames), and two clocks alone are 2 fps. At 2 or 3 columns the same board
  sits at 4 fps. The earlier bisection (`06`) showed the same shape for a
  single CPU gauge: `[2, 23, 2]` fps across three seconds.
- The 197 % / 144 % samples are the relayout burst and the animated scroll,
  both of which redraw the whole popup every frame while they last; both
  end within 2 s of the trigger.
- Auto-scroll speed matches the formula (`07`): depth ≈ 0.85 into the zone
  gives (1.5 + 9.5·0.85²)·60 ≈ 500 px/s; the log shows 3003 px in ~6 s. The
  zone flags read `bottom=true` then `top=true`, `auto=true`, and the drag
  ended back at `contentY=0` with the layout intact.

## Open / close cycles

`kglobalaccel invokeShortcut "activate application launcher"` toggled the
launcher 40 times (1.2 s open, 1.8 s closed) with the 48-gadget board:

| point | RSS |
|---|---|
| plasmashell started, menu not yet open | 598.8 MB |
| after the timeline, menu open | 761.4 MB |
| after 20 cycles | 787.0 MB |
| after 40 cycles | **786.6 MB** |

Same pid throughout; growth stops after the first 20 cycles — a warm-up
plateau, the pattern documented for this launcher before (a control run in
`docs/x11-wayland/` showed the same). Zero QML messages from the pid over
the whole run.

## X11 session

The VM was switched to the X11 session (SDDM autologin pointed at
`plasmax11.desktop`, then reverted to Wayland and the temporary autologin
file removed) and the same probe run on the 24-item board:

| phase | fps | render / frame | CPU |
|---|---|---|---|
| Info page idle | 4 | 8–12 ms | 10 % |
| edit on (16 s) | 4, one 11 fps second at the toggle | 9–12 ms | 14 % |
| edit off | 4, one 42 fps second at the toggle | 8–13 ms | 9 % |

Session confirmed from the plasmashell process (`XDG_SESSION_TYPE=x11`,
`kwin_x11 --replace` running), not from the SSH shell. Zero QML messages
from that pid.

## Idle page with the normal board, final tree

Measured once more on Wayland after the last commit, clean install of the
branch, 24-item board: **4 fps** idle (render 8–12 ms), **4 fps** with edit
on — a single 38 fps second at the toggle, an 11 fps second when it turns
off — and 4 fps after. CPU samples 12 % / 56 % / 9 % at +6 s, +10 s and
+24 s after opening; the 56 % window coincided with the board's initial
network fetches and image decoding (fps stayed at 4 through it), and the
same probe on X11 a few minutes earlier read 10 % / 14 % / 9 %. Zero QML
messages.

## Sensor and fan gadgets

- Discovery is one tree walk and one short-lived data model, once, shared
  by both gadgets (`08`); after `classify()` the probe model is emptied.
- Live subscriptions exist only for shown sensors and only while the card
  is `active` (grid active, in the viewport, not dragging). On the VM,
  with no readable sensor, neither gadget holds a subscription and the fan
  timer never runs.
- The fan spin is a single 80 ms timer for all icons, gated four ways
  (`09`); with every fan at 0 RPM it does not run.

## Games

No timers in any of the five games; a finished game or a solved board is
a static overlay. Switching games at 1x1 on the VM (five loads in a row)
produced no QML message.
