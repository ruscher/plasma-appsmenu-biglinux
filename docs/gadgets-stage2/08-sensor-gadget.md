# 08 — Sensor gadget (temperatures)

## Where the data comes from

KSystemStats, through `org.kde.ksysguard.sensors` — the daemon Plasma's
System Monitor already runs. It reads hwmon, libsensors and the GPU
drivers, localises names, and reports the hardware's critical limit as each
sensor's `Maximum`. So there is no `/sys` walking, no `sensors` process, no
polling of our own: the gadget subscribes to the ids it shows and the
daemon pushes values (`updateRateLimit: 2000`), and it unsubscribes when the
card leaves the viewport (`enabled: host.active && shownIds.length > 0`).

Discovery is shared with the Fans gadget by `gadgets/SensorCatalog.qml`, a
`pragma Singleton` (registered in `gadgets/qmldir`):

1. `kick` (1.2 s after load) walks the `SensorTreeModel` once, fetching lazy
   nodes, and collects leaf ids that are not templates (no `\d`).
2. Candidates — anything matching
   `/temp|therm|fan|rpm|hotspot|junction|edge|composite|lmsensors\//i`
   plus `gpu/gpuN/name` — go into one short-lived `SensorDataModel`.
3. 1.8 s later `classify()` reads their `Unit`: **1000 = °C**, **1004 = RPM**
   (KSysGuard's enum), names, `Maximum`, and the GPU marketing names for
   grouping; then the probe model is emptied. The result is two plain
   arrays, `temperatures` and `fans`, each entry
   `{ id, name, shortName, group, groupId, category, max }`.
4. `rowsInserted/Removed/modelReset` on the tree restart discovery
   (1.5 s debounce), so hardware that appears or vanishes shows up without
   a restart.

Two filters came from the lab VM: KSystemStats lists a CPU temperature for
every core even on a machine with no thermal sensor at all, and those never
carry a value; lmsensors reports a flat 0 °C for an unconnected header. A
temperature with no reading or ≤ 0 °C is not a row. Fans keep their 0 — a
stopped fan is real.

## Grouping

`groupOf(id)`: `cpu/…` and `k10temp|coretemp|zenpower` chips → **CPU**;
`gpu/gpuN/…` → the card's name from `gpu/gpuN/name` (e.g. *Navi 44 [Radeon
RX 9060 XT]*); `nvme*` → **NVMe**; `drivetemp|sata|ata` → **Drive**;
`acpitz|thinkpad|dell|asus|it87|nct|w836|f718|pch|wmi` → **Motherboard**;
anything else keeps its chip name minus the bus suffix. The group name is a
`section` header in the list; GPU labels that repeat the card's name are
trimmed to *junction*, *mem*, *edge*.

## Thresholds and bands

Six bands: 0 cold · 1 cool · 2 fine · 3 moderately high · 4 high ·
5 critical, coloured blue → light blue → positive → yellow → orange →
negative. Defaults per kind of hardware (°C):

| category | cool | normal | warm | hot | crit (derived) |
|---|---|---|---|---|---|
| cpu | 35 | 78 | 88 | 95 | 105 |
| gpu | 35 | 65 | 80 | 95 | 105 |
| nvme | 30 | 50 | 65 | 75 | 85 |
| hdd | 25 | 40 | 50 | 60 | 70 |
| board | 30 | 45 | 60 | 75 | 85 |

A value below `cool − 15` is *cold*, below `cool` *cool*, below `normal`
*fine*, below `warm` *moderately high*, below `hot` *high*, otherwise
*critical*. The CPU band starts higher than the others because a desktop
Ryzen or Core reports 65–75 °C under ordinary load and their own limits
(Tctl 95 °C, TjMax 100 °C) sit where `hot` does; the first renders of the
host's Tctl at 73–74 °C read "Warning" under the earlier 60 °C and 65 °C
lines, which is not a warning anyone should get at their desk.

When the sensor reports its own limit (`max > 0` — amdgpu gives 105 edge /
115 junction / 110 mem, NVMe its composite limit) the bands move under it:
`normal = min(default, max·0.60)`, `warm = min(default, max·0.78)`,
`hot = max·0.90`, `crit = max`. The tooltip states the critical limit.

Texts: band ≤ 2 → subtitle *"Everything is fine!"*; 3 → *"Warning:
moderately high temperature"*; 4 → *"Caution: high temperature"*; 5 →
*"Caution: extremely high temperature"*. On a 1x1 card the subtitle uses
the short forms *"Moderately high"*, *"High temperature"*, *"Extremely
high"*. The verdict is the worst band among **shown** sensors that have a
reading; with no reading there is no verdict, never a fake "fine".

## Layout

Every row: a band glyph, the name, a thermometer bar (fill = position
between `cool − 20` and `crit`) and the value in monospace. At 1x1 the row
becomes two lines — name and value above, the bar under them — because the
row's height is already set by the text and a 4 px bar under it costs
almost nothing, while a third of the width for the name cut *Temperatura
média* to "Temper…". The glyph is dropped at 1x1; the band still shows in
the bar colour, the tooltip and the accessible name.

The glyphs are `temperature-cold-symbolic`, `temperature-normal-symbolic`,
`temperature-warm-symbolic` and `dialog-warning-symbolic`, all present in
Breeze and Breeze Dark at 16/22/24 px (checked on disk on the VM and the
host), with the coloured `temperature-normal` as the fallback. They are
drawn as masks (`isMask: true`) so the glyph takes the band colour
whatever the theme ships — BigLinux's `bigicons-papient` has coloured
`temperature-*` badges that KIconLoader picks for the `-symbolic` name
before it reaches Breeze, and a mask flattens them to the band colour.

One caveat about the pictures in `img/harness-sensor-*.png`: the offscreen
harness runs `qml6` without the KDE platform theme, and that plugin is
what recolours masked icons, so the harness never shows the tint (its
glyphs come out in the theme's own colours). In the real session the tint
applies — the in-process capture `img/info-page.png` shows Countdown's
`chronometer-symbolic` rows in the card's accent colour, which only a mask
tint produces.

## Settings

Per-sensor visibility, persisted in `cfg.hidden` (turned off) and
`cfg.shown` (default-hidden ones turned on). Hidden by default:
per-core temperatures (`cpu/cpuN/…`) and the CPU package max/min, which
would otherwise put 8–16 near-identical rows above the interesting ones.

## Empty states

- catalogue not ready → busy indicator (only while the card is active);
- no temperature at all → thermometer glyph + *"No temperature sensors
  detected"*;
- everything hidden → *"All sensors are hidden. Choose some in the
  settings."*

## Evidence

- **Lab VM** (QEMU, no hwmon): `catalogReady=true`, 11 CPU entries without
  a value dropped, `temps=0`, empty state visible, subtitle empty, busy
  indicator stopped; zero QML messages from that plasmashell pid.
- **Host** (k10temp, amdgpu, nvme) through the offscreen harness: CPU
  average 73 °C, Vega 47 °C, RX 9060 XT junction/mem/edge 57/56/52 °C,
  NVMe composite 36 °C, grouped and sorted; 1x1, 2x1 and 1x2 renders
  inspected (`img/harness-sensor-1x1.png`, `img/harness-sensor-2x1.png`).
- **VM, in-process capture** of the Info page with both empty states:
  `img/info-page.png`.
- **Sensors disappearing**: with the catalogue's `temperatures` cut from
  6 to 2 while the gadget was live, the list dropped to 2 rows and the
  verdict was recomputed in the same frame; cut to 0, the empty state took
  over. (The catalogue's own re-walk on tree changes could not be triggered
  without hardware to plug; the path is the same `discover()` the first
  run uses.)

## Registry

`sensors` — name *Sensor*, `temperature-normal-symbolic` with
`temperature-normal` fallback, category *system*, sizes 1x1 / 2x1 / 1x2 /
2x2, default 1x2, offline.
