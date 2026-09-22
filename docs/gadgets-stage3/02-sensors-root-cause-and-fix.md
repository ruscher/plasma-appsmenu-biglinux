# 02 — Sensor: the subscription that never happened

## The report

> I opened the gadget, no temperature appeared. I went into Configure,
> added/changed sensors, and only then did it start working. After a
> while some readings disappeared again.

All three halves of that are one bug, and it is not where the previous
stage looked.

## What was ruled out first

- **The catalogue.** Probed inside plasmashell: the sensor tree is fully
  populated within a second, and discovery finishes correctly.
  ```
  t=1 ready=false arvore=316 temps=0  fans=0
  t=4 ready=true  arvore=316 temps=24 fans=1
  ```
- **The settle timer.** In a bare `qml6` process, values arrive ~100 ms
  after subscribing and never change afterwards — the 1800 ms wait was
  never losing a race.
- **The signals.** `SensorDataModel` emits `modelReset`,
  `columnsInserted` and then `dataChanged` repeatedly; values were
  readable 2 ms after subscription.

## What it was

With the catalogue correct and the card scrolled into view:

```
sens t=8  active=true  shown=8 liveEnabled=true  liveCols=0 values=0
sens t=20 active=true  shown=8 liveEnabled=true  liveCols=0 values=0
```

Enabled, eight ids in `sensors`, and **zero columns twenty seconds
later**. The model had simply not subscribed. Re-assigning the same list,
live, in the same session:

```
PROBE3 live.sensors=[8 ids] enabled=true cols=0
PROBE3 reatribuido; cols agora=0
PROBE3 depois de reatribuir: cols=8 values=8
```

**`SensorDataModel` only subscribes when the sensor list is assigned
while the model is enabled.** A list handed to a disabled model is
remembered and never acted on, and enabling it afterwards does nothing.

A gadget does exactly the wrong thing without trying: the card is created
off screen, so `enabled` is false, and the id list arrives a moment later
when discovery finishes. Hence:

- **nothing on first open** — the list arrived while disabled;
- **Configure fixes it** — changing a setting changes the list, which
  re-assigns it, this time while enabled;
- **it goes away again** — scrolling the card out of view disables the
  model; scrolling back enables it without re-assigning anything.

## The fix

`gadgets/SensorSubscription.qml` owns subscribing, for this gadget and
for Fans:

```qml
enabled: sub.wanted                    // on screen, and something to watch
sensors: enabled ? sub.ids : []        // assigned only while enabled
```

The list is therefore re-assigned every time the model becomes enabled.
A watchdog re-assigns once more if columns have still not appeared after
four seconds, because this is an upstream behaviour rather than a
contract and it should not fail silently twice.

Readings are kept when the card leaves the screen and marked stale rather
than dropped, so a row does not blank and jump back on return.

Measured after the fix, scrolling away at t=20 and back at t=28:

```
t=7  active=true  values=0             worst=-1 sub=[]
t=9  active=true  values=8             worst=2  sub=[Everything is fine!]
t=21 active=false values=8 stale=true  worst=2  sub=[Everything is fine!]
t=29 active=true  values=8             worst=2  sub=[Everything is fine!]
```

## Discovery, made honest

Two further rules in `SensorCatalog`, both learned from what the previous
version did:

- **A sensor is not dropped for having no reading at that instant.**
  Classification used to run once and drop any temperature without a
  value, permanently — a snapshot deciding existence. Existence comes
  from the unit; whether a value has arrived is the gadget's business and
  changes minute to minute. This is what made readings vanish and never
  return.
- **An empty result is never published as "ready".** If the tree is not
  up yet the catalogue retries with a growing delay (1, 2, 4, 8, then
  15 s) and keeps whatever is already on screen, instead of announcing a
  machine with no sensors.

Classification waits for the metadata to *settle* — the count of sensors
reporting a unit stops growing for two rounds — rather than for a fixed
1800 ms, with a five-second ceiling.

## The card

Drive Info's language, with the kind of hardware as the row's icon:

```
CPU
[chip]  Temperatura média            66°C
        Normal
        ▂▂▂▂▂▂▂▂▂▂▂▃▃▃▃▃▃─────────

Navi 44 [Radeon RX 9060 XT]
[card]  junction                     53°C
        Normal
        ▂▂▂▂▂▂▂▂▂▃▃▃──────────────
```

Group headings appear only when there is more than one group. On a 1x1
card the verdict line is dropped and the row is two lines; the verdict is
still in the tooltip and the accessible name, so colour is never the only
channel. A sensor with no reading keeps its row and says *"Waiting for a
reading"* rather than disappearing.

Icons: `cpu-symbolic` and `gpu-symbolic` are drawn for this project —
Breeze has a 64 px coloured `cpu` and a settings icon, neither of which
belongs in a 16 px row, and its only GPU glyph means "desktop effects".
NVMe uses `media-flash-symbolic` and drives `drive-harddisk-symbolic`,
both Breeze. The gadget's own icon is a drawn thermometer because
Breeze's `temperature-normal-symbolic` is a symlink to the coloured
status icon, whose stylesheet class and semi-transparent fill collapse
into a filled square when drawn as a mask — which is exactly what the
card's title bar was showing.

## Thresholds

Unchanged from stage 2 and documented there: per kind of hardware, and
bent under the limit the sensor itself reports when it has one. CPU
35/78/88/95 °C, GPU 35/65/80/95, NVMe 30/50/65/75, HDD 25/40/50/60,
board 30/45/60/75. Per-core readings stay hidden by default — sixteen
rows repeating the package figure.

## Status

| | |
|---|---|
| works on first open, no Configure | **TESTED ON REAL HARDWARE** |
| survives leaving and re-entering the viewport | **TESTED ON REAL HARDWARE** |
| readings do not vanish | **TESTED ON REAL HARDWARE** |
| classification by unit | **TESTED ON REAL HARDWARE** |
| CPU/GPU/NVMe visually distinct | **TESTED ON REAL HARDWARE** |
| retry while the daemon starts | **TESTED ON VM** (no sensors at all) |
| hardware appearing or disappearing | **NOT TESTED** — nothing to plug in |
