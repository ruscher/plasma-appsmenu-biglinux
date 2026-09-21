# 05 · Performance and stress

Development notes. Nothing here is needed at runtime.

The VM renders with **llvmpipe** (virtio GPU, no hardware acceleration), so
every surface is composited on the CPU. Absolute numbers here are a floor, not
a representative desktop; the comparisons between backends and between
controls are the meaningful part.

## Stress

Each cycle: open the launcher, exercise it, close it.

| | X11 | Wayland |
| --- | --- | --- |
| Cycles | 60 | 60 |
| Per cycle | open, 4 tab clicks, type `kate`, clear, close | open, type `kate`, Escape, Tab, Escape |
| Input | xdotool (real X events) | ydotool (uinput) |
| Crashes | **none** | **none** |
| plasmashell PID | unchanged throughout | unchanged throughout |
| Duplicate processes | none (`plasmashell --no-respawn`, one process) | none |

Plus a further ~150 open/close cycles on Wayland during the memory analysis
below — about 210 in total — with no crash and no stuck transition.

## Memory

### X11

```
RSS_start  487 716 kB
cycle 15   489 044 kB
cycle 30   490 016 kB
cycle 45   490 208 kB
cycle 60   490 016 kB      ← lower than cycle 45
RSS_end    490 016 kB      (+0.47 %)
```

Flat within allocator noise.

### Wayland — measured, then attributed, then bounded

The first Wayland run looked worse:

```
RSS_start  645 812 kB
cycle 60   681 116 kB      (+5.5 %)
```

That deserved attribution rather than a shrug, so two controls were run against
the same process:

| Control | Cycles | RSS change |
| --- | --- | --- |
| **A** — keyboard events only, launcher never opened | 30 | **−644 kB** |
| **B** — open/close the launcher, no typing | 30 | **+6 236 kB** (~208 kB/cycle) |

So the growth really was the launcher popup, on Wayland only (the same cycles
cost ~38 kB each on X11). That looked like a leak.

It is not. Continuing the same open/close cycles shows it plateauing:

```
start of round 2      687 980 kB
after 30 more cycles  685 944 kB     ← down
after 60 more cycles  685 320 kB     ← down
after 90 more cycles  686 180 kB
after 20 s idle       686 180 kB
```

Across ~90 further cycles RSS **fell** by about 1.8 MB and settled at
685–686 MB. The earlier rise was warm-up — surface buffers, glyph and icon
caches, QML component caches — reaching a steady state, not unbounded growth.

**Conclusion: no memory leak attributable to the launcher on either backend.**
Wayland has a higher plateau (≈686 MB vs ≈490 MB) and takes longer to reach it,
which is consistent with software-composited Wayland surfaces being held per
popup, and with plasmashell itself starting ~160 MB heavier on this session.

## Startup and responsiveness

Not instrumented with timers. Subjectively, and from the fixed waits that were
sufficient throughout the harness: the popup is usable well within the 2–3 s
settle the scripts allowed, on both backends, on software rendering.

`plasma-ksystemstats.service` starts **inactive** and is activated on demand —
the Info gadgets (CPU 32 % @ 3.80 GHz, Memory 38 %) populated without anything
being started by hand.

## What was not measured

* No frame-time or CPU profile (`QSG_RENDER_TIMING`, `perf`, `heaptrack`). The
  memory question was answered with controls instead, which was enough to
  settle it.
* Time-to-first-result for search was not timed.
* `valgrind`/`heaptrack` are not installed on the VM and were not added, since
  the plateau result made deeper profiling unnecessary for this audit.
