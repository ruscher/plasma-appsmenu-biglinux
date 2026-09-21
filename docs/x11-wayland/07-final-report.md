# 07 · Final report — X11 / Wayland compatibility audit

Development notes. Nothing here is needed at runtime. No credentials appear in
this directory.

## Environment

| | |
| --- | --- |
| Distribution | BigLinux based on Manjaro, rolling |
| Kernel | 6.18.44-1-MANJARO |
| Plasma | 6.7.4 |
| KWin | 6.7.4 (`kwin_x11` and `kwin_wayland` both present) |
| KDE Frameworks | 6.29.0 |
| Qt | 6.11.2 |
| Xorg / Wayland / Mesa | 21.1.24 / 1.26.0 / 26.2.2 |
| GPU | virtio, **llvmpipe** software rendering |
| Screen | single 1280x800 virtual output, bottom panel |

Both rounds ran in real login sessions, each confirmed three ways (`loginctl`,
plasmashell's own environment, the running compositor) — never from the SSH
shell's variables.

## Initial problems

| # | Severity | Problem |
| --- | --- | --- |
| 1 | P1 | The header opened in its "searching" state — avatar and user name missing, long placeholder — before the user did anything |
| 2 | P1 | In Places, "Recent activity is turned off" covered Frequently Used and the histories permanently, on top of live content |
| 3 | P2 | Searching `1 l em ml` offered to install `perl`, `docbook5-xml`, `python-elementpath` |
| 4 | P4 | A QML warning on every launch: overlay anchored inside a layout ("undefined behavior") |

## Root causes

1. **Intent inferred from `focusReason`.** The field is focused on open so the
   user can type immediately; the code assumed that focus would be
   distinguishable from a deliberate one. Instrumenting the running plasmoid
   measured `focusReason = 3 (BacktabFocusReason)` at rest — the field is
   focused through the popup's focus chain, not by the call that requested it.
   This was the only genuinely backend-sensitive logic in the project.
2. **An API mismatch exposed by integration.** `RecentActivityTracking` now
   reports a state string `trackingState`; `PlacesPage` still read the removed
   boolean `tracking`, so `!undefined` was permanently true. Each branch was
   self-consistent alone — only the merged tree shows it.
3. **The allowlist answered the wrong question.** It checked whether a query was
   safe for a shell, not whether it plausibly named software.
4. **`EmptyPage` is a `T.Page`**, so an item declared in its body goes into
   `contentData` and the content `RowLayout` took ownership of the overlay's
   geometry while the overlay also anchored itself.

## Changes

| File | Why |
| --- | --- |
| `contents/ui/Header.qml` | explicit `searchEngaged` intent; `TapHandler` (DragThreshold) and the avatar's Tab set it; reset on open |
| `contents/ui/PlacesPage.qml` | derive `historyOff` from `trackingState`, matching HomePage |
| `contents/ui/components/SoftwareSearch.qml` | reject queries that start with a bare number or have no word ≥3 chars |
| `contents/ui/FullRepresentation.qml` | `parent: root` on the onboarding overlay |
| `docs/x11-wayland/*` | this audit |

No `PKGBUILD` change; no new runtime dependency; no test tool became a
dependency.

## X11

Session 5 `Type=x11`, `DISPLAY=:1`, `kwin_x11`. Input driven with **xdotool**
(real X events), popup located by geometry each time rather than hard-coded.

30 checks run. All three functional defects were **found** here and fixed here.
Highlights: launcher open/close, header both states, Apps categories and
context menu (jump lists, favourites), Places five categories and Computer
groups, search for applications / calculator / unit conversion, Escape
semantics, plasmashell restart with 4 applets preserved, 60 stress cycles with
no crash, and — after fix #4 — **zero QML warnings**.

The strongest single result: this VM booted with the activity history off in the
worst possible state (`what-to-remember=2`, `enabled=false`, **and** the current
activity off-the-record). One click on **Turn on recent files** produced
`tracking=on reason=ok`, and the activity manager then actually recorded
(`ResourceEvent 0 → 1`), with the file appearing under Home → Recent Files.

## Wayland

Reached by temporarily configuring SDDM autologin to the Wayland session; both
that file and SDDM's state were **reverted afterwards**. Session 72
`Type=wayland`, `WAYLAND_DISPLAY=wayland-0`, `kwin_wayland`.

`xdotool` was proven useless here before relying on anything else: it finds no
plasmashell window and the X window count does not change when the launcher
opens, because the popup is a native Wayland surface. Real input came from
**ydotool** via `/dev/uinput`.

All four fixes verified. Calculator, unit conversion, the absence of spurious
package rows, both header states, the Info gadgets (Clock, Weather, Calendar,
CPU 32 % @ 3.80 GHz, Memory 38 %), Escape semantics, plasmashell restart, a
clean uninstall + reinstall, ~210 open/close cycles, **zero QML warnings**, no
crashes.

**Limitation:** injected *pointer* input (absolute warp through uinput) makes
the popup deactivate and close on this compositor, so pointer-driven UI — Apps
categories, context menus, Places category clicks — could not be exercised on
Wayland. Keyboard-driven paths were, which is what the brief prioritises.

## Performance

| | X11 | Wayland |
| --- | --- | --- |
| Stress cycles | 60 | ~210 |
| Crashes | none | none |
| RSS start → end | 487.7 → 490.0 MB (+0.47 %) | 645.8 → ~686 MB, then flat |

The Wayland rise looked like a leak at +5.5 %, so it was attributed rather than
excused. Two controls against the same process: 30 cycles of keyboard events
without opening the launcher changed RSS by **−644 kB**; 30 open/close cycles
of the launcher cost **+6 236 kB**. So it was the popup — on Wayland only.

Then 90 further open/close cycles: RSS **fell** ~1.8 MB and settled at
685–686 MB. The rise is warm-up reaching a steady state, not unbounded growth.
**No leak attributable to the launcher on either backend.**

## Stability

No plasmashell crash on either backend, in any run. `coredumpctl` shows none
(the only crashes in the journal are an unrelated audio application). No
duplicate plasmashell — a single `--no-respawn` process. No `TypeError`,
`ReferenceError`, binding loop or destroyed-object error at any point. After
fix #4, exercising every page on both backends produces **no QML output at all**
from this plasmoid.

## Remaining limitations

Real, and not worked around:

* **Drag and drop: NOT TESTED on either backend.** The delegate arms a drag only
  for `mouse.source === Qt.MouseEventNotSynthesized` (upstream Kickoff code), so
  injected input never qualifies. The implementation uses Qt's protocol-agnostic
  `Drag.Automatic` API, so there is no X11-specific path to fail on Wayland —
  but that is an argument, not a test.
* **Pointer-driven UI on Wayland: NOT TESTED** (popup closes on injected pointer
  warp). Apps categories, context menus and Places clicks are therefore verified
  on X11 only.
* **Clipboard / PRIMARY selection: NOT TESTED.** The launcher has no clipboard
  code of its own; the Clipboard gadget was not exercised.
* **Multi-monitor, fractional scaling, other panel edges, alternative themes:
  NOT TESTED.** The VM has one 1280x800 virtual output at 100 %.
* **Gadgets:** only those visible on the default Info page were observed
  (Clock, Weather, Calendar, CPU, Memory). The other ~18 were not individually
  added, configured, resized or persistence-tested.
* llvmpipe software rendering means no timing figure here represents a normal
  desktop.

## Final compatibility matrix

See [06-final-compatibility-matrix.md](06-final-compatibility-matrix.md). There
is no row where one backend passes and the other fails.

## Technical verdict

The plasmoid contains **no backend-specific code**: a search for `DISPLAY`,
`XAUTHORITY`, `X11`, `Xlib`, `wayland`, `xdotool`, `xrandr`, `xprop`,
`Qt.platform`, `platformName`, `isWayland` or `isX11` across every `.qml` and
`.js` returns only explanatory comments. Applications launch through Kicker
models, drags use Qt's abstract API, and nothing touches window coordinates or
the compositor directly. That is *why* the four defects found here were
protocol-independent, and why each fix worked on both backends without a branch.

Fix #1 removed the one place where behaviour depended on something neither
protocol guarantees.

**Verdict: ready for both backends**, with the tested scope stated above.
What was verified is genuinely verified on real sessions of both types; what
was not is listed rather than assumed. The untested areas are concentrated in
pointer-driven interaction on Wayland and in drag and drop, both blocked by
input-injection limits rather than by anything found in the code.
