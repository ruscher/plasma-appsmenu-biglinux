# 08 — Performance and stress

Instruments as in stage 2: `QSG_RENDER_TIMING=1` with the
`qt.scenegraph.time.renderloop` category, frames per second counted from
`polishAndSync: start` in the journal of the **current** plasmashell pid,
render time from `frame rendered in Nms`, CPU from `top -d 1` samples,
RSS from `ps`. A temporary probe in the deployed `InfoPage` drove the
timeline; nothing was injected as pointer or keyboard input.

The stress run is on the lab VM, not on the developer's desktop: it
duplicates the whole board, and doing that to someone's live
configuration to produce a number is not a trade worth making.

## Stress: 42 gadgets on the VM

| phase | fps | render / frame | CPU |
|---|---|---|---|
| idle, 4 columns, cards settling | 3–45 | 8–12 ms | 49 % |
| edit mode | 3–45 (no different) | 10–13 ms | 34 % |
| after edit, columns changing | bursts | 10–17 ms | 80 % (burst) |
| programmatic scroll, top → bottom → top | 57–75 (vsync bound) | 11–14 ms | — |
| drag into the auto-scroll zone | 29–69 | 13–14 ms | — |

Edit mode costs nothing measurable, as in stage 2 — the wiggle that used
to cost 220–240 % CPU is still gone. The bursts are relayouts and the
animated scroll, both of which redraw the whole popup while they last and
both of which end within a couple of seconds.

### 50 open/close cycles

| point | RSS |
|---|---|
| before the cycles | 658.3 MB |
| after 25 | 661.8 MB |
| after 50 | **662.1 MB** |

Same pid throughout, and the figure plateaus — the pattern this launcher
has shown before (`docs/x11-wayland/`), not a leak. **Zero QML messages**
over the whole run.

## What this stage added, and what it costs

### Sensors and fans

- **One tree walk and one metadata burst per discovery**, shared by both
  gadgets through the singleton. The burst subscribes to every real
  sensor (316 here) for as long as it takes units to settle — two quiet
  300 ms rounds, five seconds at most — then unsubscribes completely
  (`probe.enabled = false; probe.sensors = []`).
- **Live subscriptions exist only for the rows on screen.** The id list
  is bound to `enabled`, so leaving the viewport genuinely unsubscribes
  and returning genuinely re-subscribes; measured in `02`.
- **The fan spin is one 80 ms timer** for every icon, gated four ways.
  With the only fan at 0 RPM it never runs, which is the state on this
  machine.
- The catalogue's retry is bounded: 1, 2, 4, 8, then 15 s, and it stops
  the moment the tree answers.

### GPU Meter

Unchanged in cost: the same seven `Sensors.Sensor` objects per card,
`enabled: host.active`, VRAM total and name at a 60-second rate because
they do not change. The density decision is arithmetic on two numbers.

### Formula 1

- **Five requests per refresh, at most.** Each piece has its own cache
  entry and is fetched only when that entry has aged out: standings,
  results and the next race after 30 minutes, the calendar after 12
  hours. Switching between the four tabs costs nothing — the data is
  already there.
- **No polling.** The refresh timer runs only while the card is active,
  and `refresh()` returns immediately if it is not.
- **Nothing runs for the other competitions while F1 is selected**, and
  nothing runs for F1 while another competition is selected: the guard is
  at the top of `load()` and `refreshIfStale()`.
- The winners are fetched as position 1 only, which is roughly 14 kB for
  a season instead of every classified car of every race.

### Countdown

The tick moved from `host.active` to `host.pageActive`, so it now runs
while the menu is open even if the card is scrolled away. That is one
`Timer` at 1 Hz doing date arithmetic on a handful of events — and the
alternative was a countdown that does not go off (`06`). Nothing runs
while the menu is closed.

## The audit's two flags, and why they stay

```
17. PERFORMANCE — repeating timers not gated on host.active
  gadgets/CountdownAlarm.qml:56      running: alarm.ringing
  gadgets/items/CountdownGadget.qml  running: cd.host.pageActive && cd.next !== null
```

Both are deliberate and both are narrower than they look. The alarm's
timer runs only while something is actually ringing and unacknowledged;
the countdown's runs only while the menu is open and there is a pending
event. The audit looks for the literal string `host.active`, which is the
right default and the wrong rule for these two.

## Idle cost on the developer's machine

With the 23-gadget board and the menu open, plasmashell sits at 11–12 %
CPU and 845 MB RSS on three screens, which is where it sat before this
stage. No new timer runs while the menu is closed: the sensor
subscriptions are disabled, the fan animation is stopped, the F1 refresh
timer is not running, and the countdown is not ticking.

## Status

| | |
|---|---|
| 42-gadget stress, timeline and cycles | **TESTED ON VM** |
| RSS plateau over 50 cycles | **TESTED ON VM** |
| edit mode costs nothing extra | **TESTED ON VM** |
| subscriptions stop off screen | **TESTED ON REAL HARDWARE** |
| F1 request count and caching | **TESTED ON REAL HARDWARE** (cache hits on tab switches) |
| many sensors / many fans | **NOT TESTED** — 24 temperatures and one fan is what this hardware has |
