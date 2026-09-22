# 12 — Final validation

Every check below was run on the lab VM (Plasma 6.7.4, KF 6.29, Qt 6.11.2,
QEMU/virtio, 8 vCPU, no hwmon) unless the row says *host* (the developer
machine, through the offscreen harness) or *source* (static inspection).
Session type was always read from the plasmashell process, not from the
SSH shell. "Zero QML messages" means the journal of that plasmashell pid,
with `QT_LOGGING_RULES=qml=true;default=true` forced on, had no line
mentioning the plasmoid, binding loops, `Overwriting binding`, `TypeError`,
`ReferenceError`, `undefined` or `NaN`.

## Acceptance criteria

| # | criterion | result | evidence |
|---|---|---|---|
| 1 | Games works at 1x1 with all five games | **pass** | VM probe cycled the five games at 1x1: all loaded, `compact=true`, strip hidden, title actions present (`02`) |
| 2 | Compact layouts are real, not `scale` | **pass** | source: no `scale` on any board; per-game compact rules (`02`) |
| 3 | Block Puzzle at 1x1 shows board + 3 pieces, comfortably | **pass** | board 147 px / 18.4 px cells, tray 59 px, piece cells ≈ 14 px; renders at 1x1, 1x2, 2x1, 2x2 inspected |
| 4 | Sudoku at 1x1 keeps the full grid and can be played | **pass** | 18.4 px cells + popover pad beside the selected cell, keyboard digits |
| 5 | Game selector compact at 1x1 | **pass** | title-bar menu with checkable items |
| 6 | Network keeps the line chart | **pass** | unchanged component, legend beside it |
| 7 | Legend `● Download … / ● Upload …` | **pass** | `03` |
| 8 | Binary units B/s, KiB/s, MiB/s, GiB/s; no "KB/s" over 1024 | **pass** | `speed()`; live values on the VM (`03`) |
| 9 | Overview / Details tabs | **pass** | `GadgetTabStrip`, Details loaded on demand |
| 10 | Details: type, speed, MAC, device, IPv4/IPv6 address, gateway, DNS | **pass** (what the connection has) | plasma-nm `ConnectionDetailsModel`, 8 localised rows on the VM's wired link; fields only when present |
| 11 | Copy buttons with feedback, tooltip, accessible name | **pass** | `edit-copy-symbolic`, "Copied" tooltip, *"Copy <field>"* |
| 12 | Default-route interface identified | **pass** | NM `PrimaryConnection` over D-Bus, one-shot, path validated by regex |
| 13 | No repeated shell commands for network data | **pass** | one `busctl` per rescan; everything else from the plasma-nm model |
| 14 | Gear opens System Settings → network natively | **pass** | `KCMLauncher.openSystemSettings("kcm_networkmanagement")` |
| 15 | Countdown: next event highlighted + scrollable list | **pass** | 20 events: 1 highlighted, 19 in the `ListView` |
| 16 | Alarm loops until acknowledged | **pass** | repeats every 2.5 s while unacknowledged; `playing` true → false on acknowledge, on the VM and on the developer's machine |
| 17 | Safe alarm lifecycle, no orphan process, no `while true` | **pass** | a QML `Timer` drives one short-lived play command per repetition; no shell loop; `pgrep` for players after stopping: none |
| 18 | Alarm window titled "Countdown" with a chronometer icon | **pass** | own `notifyrc` component; bus capture showed `app_name "Countdown"`, `app_icon "chronometer"` (`04`) |
| 19 | Dismiss stops audio, closes, marks acknowledged | **pass** | probe log `ringing 1 → 0`, `notes 1 → 0`, `acked` persisted across a Plasma restart |
| 20 | Symbolic icons for Games / Gallery / Calendar etc., central, verified, with fallback | **pass** | `GadgetRegistry` entries with `iconFallback`; names checked on disk (`05`) |
| 21 | Gallery Previous / Next discoverable + Left / Right keys | **pass** | `06`/`05`; `activeFocusOnTab`, `Keys.onLeft/RightPressed` |
| 22 | Header: title left, `2 3 4 | Edit | Add` right, never shifting | **pass** | right block x identical with Edit on/off (724 px); `TextMetrics` for both labels |
| 23 | Edit mode fluid; profiled before fixing | **pass** | 220–240 % CPU → edit = idle; 48-gadget stress: edit on 47–52 % vs 50 % idle (`06`, `11`) |
| 24 | Drag auto-scroll zones visible, larger, smooth acceleration | **pass** | 2.6 gu zones drawn while dragging; 0 → 3003 px in 6 s; quadratic ramp (`07`, `11`) |
| 25 | Sensor gadget lists all temperatures dynamically | **pass** (host) / **empty state** (VM) | catalogue from KSystemStats; host: CPU, two GPUs, NVMe |
| 26 | KSystemStats first, no `sensors` polling | **pass** | `SensorCatalog`; no process spawned |
| 27 | Thermometer indicators, colour bands blue → red | **pass** | six bands; renders |
| 28 | Per-hardware thresholds; sensor limits used when available | **pass** | defaults table + `max`-derived bands (`08`) |
| 29 | Friendly status texts | **pass** | "Everything is fine!" … "Caution: extremely high temperature" |
| 30 | Grouping by device | **pass** | sections CPU / GPU name / NVMe / Drive / Motherboard |
| 31 | Per-sensor hide, persisted | **pass** | `cfg.hidden` / `cfg.shown` |
| 32 | Fans gadget lists all fans with RPM | **pass** (host, one fan) / **empty state** (VM) | `09` |
| 33 | Fan icon spins only when RPM > 0, cheap shared animation | **pass** | one timer, four gates; 0 RPM never rotates |
| 34 | Per-fan hide + "Animate fan icons" | **pass** | settings |
| 35 | Both in Registry / Add Gadget with sizes | **pass** | `sensors` 1x1–2x2 (default 1x2), `fans` 1x1–2x2 (default 1x1) |
| 36 | Shared backend, no duplicated discovery | **pass** | one singleton, one walk, one probe model |
| 37 | Accessibility | **pass** with limits | `10`; no AT session run |
| 38 | i18n: English source, no Portuguese in QML | **pass** | audit: 0 unwrapped literals |
| 39 | UX: progressive disclosure, Units / Theme | **pass** | tabs, popovers, `Kirigami.Units` throughout; audit: 0 literal colours outside palettes |
| 40 | Real profiling | **pass** | frame log timelines in `06`, `11` |
| 41 | Stress with many gadgets | **pass** | 48 gadgets: idle 4 fps, edit = idle, RSS plateau (`11`) |
| 42 | Size tests 1x1 / 2x1 / 1x2 / 2x2 | **pass** | games and sensor rendered at all four; fans at 1x1 |
| 43 | Network tests | **pass** wired; Wi-Fi / VPN / global IPv6 **not tested** | VM has one wired link and no `wireguard` module |
| 44 | Countdown tests | **pass** | 2 simultaneous, 20 events, restart |
| 45 | Sensor / fan tests incl. empty states | **pass** | VM empty states; host populated; disappearance simulated |
| 46 | Logs clean | **pass** | zero QML messages in every run of the final tree (games cycle, countdown, stress, X11, final) |
| 47 | No heavy dependencies | **pass** | KSystemStats, plasma-nm, KCMUtils, KNotification already on every Plasma; audio is `canberra-gtk-play`/`paplay`/`pw-play` out of process, no media framework linked into the shell |
| 48 | Security: no unsafe shell concatenation | **pass** | the only shell path is `busctl` with a regex-validated object path; sensors/network/files never reach a shell |
| 49 | Regressions: configs, layout, scores, events, cache preserved; `puzzle → games` keeps 1x1 | **pass** | migration keeps size; `best` untouched; countdown events survived restarts |
| 50 | Code quality: no AI comments, TODOs, dead code | **pass** | `grep -riE "claude\|anthropic\|todo\|fixme"` finds nothing under `gadgets/`, `InfoPage.qml` or the docs; the seven `TODO`/`HACK` lines that remain are upstream Kickoff comments in `KickoffListView/GridView`, `LeaveButtons` and `main.qml`, untouched by this work |

## What the page looks like in the real session

Captured from inside plasmashell (`Item.grabToImage` on the page, no
screenshot tool, no synthetic input), Wayland, light theme:
`img/info-page.png` (normal), `img/info-page-edit.png` (edit mode: badges,
static accent border, header block unmoved), `img/info-page-2-columns.png`,
`img/info-page-4-columns.png`. Visible in them: Games at 1x1 with the
Block Puzzle board and its three pieces, the Sensor and Fans empty states,
Countdown's highlighted event plus its scrolling list, and the
`2 3 4 | Edit | Add` block at the same x in every capture.

## Runs of the final tree on the VM

| run | session | result |
|---|---|---|
| games cycle at 1x1 (5 games) | Wayland | all loaded; 0 messages |
| countdown, 20 events, ring / acknowledge / restart | Wayland | as designed; 0 messages |
| stress, 48 gadgets, timeline + 40 open/close cycles | Wayland | idle 4 fps, edit = idle, RSS plateau; 0 messages |
| Info page idle / edit, 24 gadgets | **X11** | 4 fps, 9–14 % CPU; 0 messages |
| Info page idle / edit, 24 gadgets, final clean install | Wayland | 4 fps idle and in edit; 0 messages (`11`) |

## A crash this validation missed

Everything above passed on the lab VM, and the Countdown alarm still shipped
a bug that put the developer's desktop into a 122-restart SIGSEGV loop the
moment it was installed: `QtMultimedia` → FFmpeg → Vulkan → the machine's
**vkBasalt** layer (`04`). The alarm is now played out of process and the
crash is gone, verified on that machine.

Two lessons, recorded because they are about this validation, not about the
alarm:

- **A lab VM cannot clear a graphics or media stack.** The VM has no real
  GPU, no Vulkan layers, no VAAPI; the very things that make a desktop
  machine's media stack fragile are the things it does not have. Anything
  touching audio, video or the GPU needs a run on hardware before it is
  called tested.
- **"The service is active" is not "it did not crash."** The first check
  after installing read `systemctl is-active` and a single pid, both of
  which a crash loop satisfies perfectly — systemd had already restarted it.
  The check that catches it is the same pid sampled over a minute, plus
  `NRestarts` and `coredumpctl`, which is what this document's numbers now
  come from.

## Not tested, and why

- **Wi-Fi, VPN, WireGuard, global IPv6** in Network → Details: the VM has
  a single wired link and no `wireguard` kernel module; no VPN endpoint
  was available. The rows come from plasma-nm's own details model, which
  is what the system tray applet shows for those connection types.
- **A fan actually turning**: no reachable machine reported RPM > 0 this
  session. The moving state was exercised in the harness by forcing the
  shared angle; the gating logic is what the stopped case tests.
- **Hot-plugged sensors**: the catalogue's re-walk is wired to the tree
  model's row signals and reuses the first-run path; the gadget's reaction
  to the catalogue changing was simulated (6 → 2 → 0 rows).
- **Screen reader**: properties verified in source and engine; no Orca.
- **Real pointer drag**: Kickoff-derived delegates ignore synthetic mice;
  the drag path was driven through the grid's own API with the same
  effects a pointer produces.

## Left on the VM

The clean package from the branch installed in `~/.local/share`, the test
uids and countdown test events removed from the board, `lastTab` /
`rememberLastPage` / `gadgetColumns` restored to defaults, the logging and
`QML_XHR_ALLOW_FILE_WRITE` overrides unset, the SDDM autologin file
removed, Wayland session running.
