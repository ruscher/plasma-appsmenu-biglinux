# 09 — Fans gadget

## Data

The same `SensorCatalog` as the temperatures (see `08`): entries whose
KSystemStats unit is **1004 (RPM)**. A fan at 0 RPM is kept — a stopped fan
is information — and only an entry with no value at all is dropped. The
gadget subscribes to the shown ids with one `SensorDataModel`
(`updateRateLimit: 2000`) while the card is active, and to nothing when it
is off screen.

## Rows

Fan icon · name (KSystemStats' own, nothing guessed) · group on a second
line (not at 1x1) · speed in monospace: `"%1 RPM"` with the number
localised, `"0 RPM"` dimmed for a stopped fan, `—` before the first
reading. Subtitle: `"%1 fan turning" / "%1 fans turning"` (`i18ncp`).
Tooltip carries the full name and the technical id; the accessible name is
*"<name>, <rpm> RPM"* or *"<name>, stopped"*.

## The icon

No installed theme has a fan icon (Breeze, bigicons-papient, hicolor were
searched), so `gadgets/icons/fan-symbolic.svg` is an original 16 px
three-blade fan with `fill="currentColor"`, drawn as a mask in the accent
colour when turning and in the disabled text colour when not. The Registry
entry uses it with `temperature-normal` as the fallback name.

## The spin, and why it is cheap

Edit mode taught the lesson (`06`): a running animation per item means a
full-window frame at vsync for as long as it runs. Here:

- one `property real angle` on the gadget, advanced by **one** `Timer`
  (80 ms, +22° per tick ≈ 12 updates a second);
- each icon binds `rotation: angle * spinFactor(fan)`, where
  `spinFactor` is 0 for a stopped fan and `0.35 + 0.65 · min(1, rpm/max)`
  otherwise (`max` from the sensor when it reports one, else 2000 RPM), so
  a slow fan visibly turns slower without pretending to be a tachometer;
- the timer runs only while `host.active && animate && spinning > 0 &&
  Kirigami.Units.longDuration > 0` — off screen, with every fan stopped,
  with animations disabled system-wide, or when the user unticks
  *"Animate fan icons"*, nothing ticks.

A fan at 0 RPM is never rotated, by construction (`rotation: turning ? …
: 0`).

## Settings

*Show detected fans* — one checkbox per fan, persisted in `cfg.hidden`;
*Animate fan icons* — `cfg.animate` (default on).

## Empty states

Busy indicator while the catalogue is not ready; fan glyph + *"No fan
sensors detected"* when the machine reports none; *"All fans are hidden.
Choose some in the settings."* when they are all unticked.

## Evidence

- **Lab VM** (no hwmon): `fans=0`, empty state shown (`img/info-page.png`),
  no timer running, zero QML messages.
- **Host** (amdgpu `fan1` at 0 RPM) through the offscreen harness: one row
  *"Ventoinha 1 — 0 RPM"* dimmed, icon stationary, subtitle *"0 fans
  turning"*.
- No machine with a turning fan was available to this session, so the
  moving state was verified only in the harness by forcing `angle` — the
  bindings and the gating are the part that matters and are exercised by
  the stopped case.

## Registry

`fans` — sizes 1x1 / 2x1 / 1x2 / 2x2, default 1x1, category *system*,
offline, single instance.
