# 09 — Test matrix

Four labels, used strictly:

- **REAL** — run on the developer's machine (Wayland, two GPUs, real
  sensors, one fan), inside the running plasmashell unless stated.
- **VM** — run on the lab VM (no sensors, no fans, no GPU), Wayland or
  X11 as marked.
- **HARNESS** — rendered offscreen with `qml6` and a mock host, against
  this machine's real KSystemStats data where the gadget reads sensors.
- **NOT TESTED** — not run, with the reason.

## Fans

| check | result | where |
|---|---|---|
| every fan KSystemStats exposes appears | pass (1 fan; the kernel has no more — `00`) | REAL |
| discovery independent of sensor names | pass — classification is by unit | REAL |
| RPM updates | pass | REAL |
| 0 RPM is a valid reading | pass — shown as `0 RPM`, distinct from `—` | REAL |
| no reading ≠ stopped | pass | REAL |
| icon correct at 16/22/32/48/64 px | pass | HARNESS + REAL |
| icon unchanged by a third of a turn | pass | HARNESS |
| stopped fan does not spin | pass | REAL |
| a turning fan spins | **NOT TESTED** — nothing reported RPM > 0 | — |
| settings persist | pass | REAL |
| empty state | pass | VM |
| 1x1 / 2x2 | pass | HARNESS |

## Sensor

| check | result | where |
|---|---|---|
| works on first open, without Configure | pass | REAL |
| readings survive leaving and re-entering the viewport | pass | REAL |
| readings do not vanish over time | pass (20 min open) | REAL |
| CPU / GPU / NVMe visually distinct | pass | REAL |
| symbolic icons render as masks | pass | REAL |
| thresholds unchanged | pass — same table as stage 2 | source |
| a sensor with no reading keeps its row | pass | REAL (VM shows it at scale) |
| retry while the daemon starts | pass | VM |
| hardware appearing or disappearing | **NOT TESTED** — nothing to plug in | — |
| 1x1 / 2x1 / 1x2 / 2x2 | pass | HARNESS |

## Gallery

| check | result | where |
|---|---|---|
| arrows never permanently invisible | pass | REAL |
| arrows above the picture after many changes | pass | REAL |
| hover raises them | pass | REAL |
| one picture → no arrows | pass | source + REAL (212-picture folder) |
| slideshow still runs | pass | REAL |
| corrupt pictures skipped | unchanged from stage 1 | VM (stage 1) |
| keyboard Left / Right | **NOT TESTED** — synthetic input does not reach this popup | — |

## GPU Meter

| check | result | where |
|---|---|---|
| 1 GPU → roomy layout | pass | HARNESS (1x2, 2x2) |
| 2 GPUs → both visible, no vertical scroll | pass | REAL + HARNESS (all four sizes) |
| 3+ GPUs → denser | **NOT TESTED** — no such machine | — |
| many GPUs → scroll | **NOT TESTED** | — |
| power reading present | pass — via `power1` on amdgpu | REAL |
| cards named by the driver, not by index | pass | REAL |
| no GPU → empty state | **NOT TESTED** on hardware; the binding is `gpuIds.length === 0` | VM has no GPU sensors and shows it |
| Intel / NVIDIA | **NOT TESTED** — nothing vendor-specific was added | — |

## Live Scores

| check | result | where |
|---|---|---|
| settings fit in the popup | pass — dialog 513 px over 766 px of content, scrolls | REAL |
| every competition reachable | pass — one vertical list | REAL |
| refresh interval reachable | pass | REAL |
| notifications switch reachable | pass | REAL |
| auxiliary text in the footer | pass | REAL |
| interface scale 125–200 % | **NOT TESTED** — the fixed cap that broke it is gone; sizing is in grid units | — |
| long translations | **NOT TESTED** directly; labels sit above controls so they lengthen the dialog | — |

## Formula 1

| check | result | where |
|---|---|---|
| race results with laps and time | pass — 14 rounds, live data | REAL |
| drivers' standings | pass — Antonelli 292, Russell 211, Hamilton 191 | REAL |
| constructors' standings | pass — Mercedes 503, Ferrari 358, McLaren 306 | REAL |
| season calendar, done / next / ahead | pass — 23 rounds | REAL |
| next race with local time | pass — round 15, Azerbaijan, 26/09 08:00 local | REAL |
| loads when F1 is already selected at startup | pass (after the `Loader` fix — it was blank) | REAL |
| cache: switching tabs costs no request | pass | REAL |
| no fetches while another competition is selected | pass | source + REAL |
| no season written into the code | pass — `current` throughout | source |
| offline / API error | **NOT TESTED** against a real outage | — |
| missing fields | pass by construction — every optional field is guarded | source |

## Network → Details

| check | result | where |
|---|---|---|
| Ethernet speed, MAC, device | pass | REAL |
| IPv4 address, gateway, both DNS | pass | REAL |
| IPv6 address, gateway, both DNS | pass | REAL |
| copy buttons on copyable values only | pass | REAL |
| primary picked among four active connections | pass | REAL |
| Wi-Fi, VPN sections | **NOT TESTED** — neither machine has one | — |

A note on the earlier "smoke test" of this file: it was run with a wrong
relative path, so the component never loaded and the pass was worthless.
The check now renders the panel and looks at it. See `11`.

## Countdown

| check | result | where |
|---|---|---|
| fires with the card scrolled out of view | pass | REAL, VM-Wayland, VM-X11 |
| notification dispatched | pass | REAL |
| notification visible | **suppressed by the user's Do Not Disturb**, now explained on the card | REAL |
| own identity on the bus (name, icon) | pass | REAL (from `qml6`, same component) |
| sound plays | pass — player process observed | REAL |
| no orphan process | pass | REAL |
| dismiss, repeated alarms, two at once | unchanged from stage 2 | VM (stage 2) |
| package vs development install of the `.notifyrc` | **analysed**, not built: PKGBUILD copies `usr/`, `kpackagetool6` does not | source |

## Cross-cutting

| check | result | where |
|---|---|---|
| plasmashell never crashed | pass — 0 restarts across every run | REAL + VM |
| zero QML messages | pass | REAL + VM (Wayland and X11) |
| no binding loops | pass | REAL + VM |
| 42-gadget stress | pass | VM |
| 50 open/close cycles, RSS plateau | pass — 658 → 662 MB | VM |
| X11 | pass — install, Info page, countdown, no messages | VM |
| Wayland | pass | REAL + VM |
| i18n: 0 unwrapped literals | pass | audit |
| screen reader | **NOT TESTED** — no Orca on either machine | — |
| real pointer drag | **NOT TESTED** — Kickoff delegates ignore synthetic input | — |
