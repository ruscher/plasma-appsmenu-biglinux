# 01 — Info gadgets: architecture audit (stage 2)

Read before changing anything. Every statement here was checked against the
code and, where it concerns behaviour, against a live Plasma 6.7.4 / Qt 6.11.2
session on the lab VM or against this machine's real hardware.

## How a gadget comes to exist

```
InfoPage.qml            persistence + toolbar + Flickable + auto-scroll
  └ GadgetGrid.qml      ListModel {uid, gadgetId, size, cfgJson}, first-fit packing
      └ Repeater → GadgetHost.qml    one card per row of the model
            └ Loader.setSource("items/<def.source>", { host })
                  └ <SomeGadget>.qml   reads host.cfg, writes via host.setCfg()
```

* **Registry** (`GadgetRegistry.qml`, singleton): the catalogue. Each entry has
  `id, name, icon, category, sizes, defaultSize, source, online, multiple`.
  `byId()` is what the grid and the host use; the gallery filters `gadgets`
  by category; `defaultLayout` is the first-run board.
* **Sizes** are strings `"colsxrows"` from `{1x1, 2x1, 1x2, 2x2}`. `cols` is
  clamped to the grid's column count, so a `2x1` on a 2-column board is still
  2 wide. Nothing in the framework knows a *minimum* size for a game — that
  was bolted onto `GamesGadget` as `minCols/minRows` and is what this stage
  removes.
* **Cells**: `cellWidth = floor((width − spacing·(cols−1)) / cols)`, at least
  80 px; `cellHeight = round(cellWidth · 0.94)`. On the VM at 3 columns a
  cell is ~150 px wide; that is the canvas a `1x1` game has, minus the card's
  padding (`largeSpacing` each side) and the title bar (~22 px).
* **Packing** (`relayout()`): first-fit, top-left, in model order, up to 500
  rows. It runs on every width/column/spacing change and after every model
  mutation, and it is O(rows × cols × items) — fine at these sizes.
* **Host API** to the gadget: `cfg` (read), `setCfg/saveCfg` (write; note
  `cfgChanged` fires twice per save, see stage-1 audit), per-instance and
  shared cache, `setError/clearError`, `loading`, `offline`, `subtitle`,
  `accentColor`, `titleActions`, `settingsComponent`, and geometry helpers
  `compact` (1x1), `wide` (cols ≥ 2), `tall` (rows ≥ 2), `contentWidth/Height`.
* **Activity**: `host.active = grid.active && inViewport && !dragging`, where
  `grid.active = pageActive && kickoff.expanded`. Every timer and sensor in
  every gadget is expected to bind `running/enabled` to it. `inViewport` is
  computed by the grid from the Flickable's `contentY`, with one cell of
  slack above and below.
* **Persistence**: `InfoPage` serialises the grid into
  `Plasmoid.configuration.gadgetLayout` (debounced 700 ms) and the shared
  cache into `gadgetCache` (1.5 s). `migrate()` rewrites renamed gadgets on
  load — today only `puzzle → games`, and it bumps a `1x1` to `1x2`, which
  this stage must revisit because `1x1` comes back.
* **Edit mode**: `grid.editing`. Entered by the toolbar button or a
  press-and-hold anywhere on a card (`TapHandler`, 450 ms). In edit mode a
  full-card `MouseArea` drags; in normal mode only the title bar does. Badges
  (remove / size / settings) are `AbstractButton`s anchored to the corners.
* **Drag**: the grid follows the **pointer**, not the card centre, and only
  reorders after the pointer dwells 140 ms in a new cell and never while the
  page is auto-scrolling. Auto-scroll lives in `InfoPage`: a 16 ms timer that
  moves `contentY` when the pointer is within `1.6 · gridUnit` (~29 px) of the
  Flickable's top or bottom, speed 2–12 px/tick with depth. There is **no
  visual hint** of that zone.
* **Gallery** (`GadgetGallery.qml`): a modal `Popup` over `GadgetRegistry`,
  filtered by category, `Add` per card, `Restore default layout`.

## What the profiling actually showed

Measured with `QSG_RENDER_TIMING=1` and the scenegraph render-loop log,
frames counted per second from the journal, on the VM with the 22-gadget
board open on the Info page. (An earlier attempt measured the *Home* page by
mistake: KConfig deletes keys at their default value, so writing `lastTab=3`
over a line that no longer existed was a silent no-op. `settab.py` in the
test kit inserts the key.)

| state | frames / s | render per frame | plasmashell CPU |
|---|---|---|---|
| menu open on **Home** | 2 | 3 ms | ~4 % |
| menu open on **Info**, edit off | **40–57** | 8–10 ms | — |
| menu open on Info, **edit on** | **73–77** | ~12 ms | **220–240 %** |

Two separate problems, then:

1. **Edit mode** — `SequentialAnimation on rotation { loops: Infinite }` per
   card. Rotation is the costliest transform available here: every card's
   content area is clipped, and a rotated clip cannot use the scissor
   fast-path, so 22 cards fell back to stencil clipping every frame. Two and a
   third cores for a wobble.
2. **Idle Info page** — even with edit off, something repaints continuously.
   Found by reading, not guessing: four decorative loops bound to
   `host.active` alone, i.e. running whenever the menu is open:
   * Weather — the icon "floats" (`anchors.verticalCenterOffset`, 3.6 s loop);
   * Gallery — a Ken Burns zoom whose `Behavior` lasts the whole slide
     interval (≈ 9 s), so it never stops;
   * Live Scores — a pulsing dot per live match;
   * Battery — a liquid wave (`phase`) and a "breathe" while charging.
   Any running animation dirties the scene, and a dirty scene is a full-window
   frame at vsync. Four of them add up to the 45 fps observed.

Both are fixed in stage 8 / stage 17 with numbers in `06-edit-mode-performance.md`.

## Hardware sensors — what the platform already provides

No `/sys` parsing and no `sensors` process are needed. KSystemStats publishes
temperatures with `Unit == 1000` (°C) and fans with `Unit == 1004` (RPM), and
carries the hardware's own critical limit in `Maximum`. Dumped on this machine
through `SensorDataModel`:

```
cpu/all/averageTemperature   Temperatura média      °C  max=0    (no limit known)
cpu/cpu0..15/temperature     Núcleo 1..16           °C  max=0
gpu/gpu0/temperature         RX 9060 XT Temperatura °C  max=105
gpu/gpu0/temp2               … junction             °C  max=115
gpu/gpu0/temp3               … mem                  °C  max=110
gpu/gpu0/fan1                … Ventoinha 1          RPM max=3000  value=0
lmsensors/nvme-pci-0900/temp1  (NVMe composite)     °C
```

Names arrive already translated by the daemon. Ids containing `\d` are
templates, not sensors, and must be skipped. The lab VM (QEMU, virtio GPU)
has **no hwmon at all**, which makes it the right place to test the empty
states and this machine the right place to test populated ones.

## Network — what the platform already provides

`org.kde.plasma.networkmanagement`'s `NetworkModel` exposes, per active
connection, a `ConnectionDetailsModelRole` whose rows are already sectioned
and localised — probed live on the VM:

```
[Ethernet]  Connection speed | MAC Address | Device
[IPv4]      IPv4 Address | IPv4 Default Gateway | IPv4 Primary Nameserver
```

IPv6 rows and secondary nameservers appear only when they exist, which is
exactly the "no placeholders" rule. The one thing the model cannot say is
*which* active connection carries the default route; NetworkManager exposes it
on D-Bus as `PrimaryConnection` → `Connection.Active.Connection`, which maps
onto `ConnectionPathRole`. Connection types follow NetworkManagerQt
(`Wired=13, Wireless=14, Vpn=11, Bridge=4, Bond=3, Loopback=20`).

## The "Plasma" alarm window

`CountdownGadget` sends a `KNotification` with `componentName:
"plasma_workspace"`. The popup's heading and icon come from that component's
`plasma_workspace.notifyrc` — `IconName=start-here-kde-plasma`, application
name "Plasma". Nothing in the gadget can override those two; they belong to
the component. The fix is a component of our own, the way
`plasma_applet_timer.notifyrc` does it for the Timer applet.

## Icons

`bigicons-papient` declares `Inherits=hicolor` only, but KIconLoader adds
Breeze as an implicit fallback — the edit badges have used `configure-symbolic`
(Breeze-only) for months. Symbolic names verified present on disk in Breeze
and/or the BigLinux theme: `applications-games-symbolic`,
`folder-pictures-symbolic`, `view-calendar-symbolic`, `office-calendar-symbolic`
(BigLinux only), `temperature-normal/warm/cold-symbolic`, `edit-copy-symbolic`,
`configure-symbolic`, `chronometer-symbolic`, `alarm-symbolic`. **No fan icon
exists in either theme**, so the Fans gadget ships its own symbolic SVG.
`Kirigami.Icon.valid` is not a presence test — it returned `true` for every
name tried, including invented ones.

## Tooling notes worth keeping

* Qt logs to journald, not stderr, when stderr is not a TTY. Under a pipe,
  `qml6` prints nothing at all until `QT_FORCE_STDERR_LOGGING=1` is set.
* QML `console.*` output lives in the `qml` logging category; the session's
  `QT_LOGGING_RULES='*=false'` swallows it unless overridden.
