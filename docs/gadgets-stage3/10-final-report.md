# 10 — Final report

## Summary

Seven reported faults across six gadgets. Five of them turned out to be
one of three *causes*, none of which was where the symptom pointed:

- two gadgets showed nothing because a KSysGuard model only subscribes
  when its sensor list is assigned while it is enabled, and a card is
  created disabled;
- the Gallery arrows were painted underneath the photograph;
- the Countdown stopped counting when its card scrolled off screen, and
  the pop-up it did send was suppressed by the desktop's own Do Not
  Disturb — which is the entire "Wayland does not work" report.

Everything is fixed in code, installed, and verified on real hardware.
plasmashell never crashed during this stage, and every run of the final
tree produced **zero QML messages**.

## Bugs reproduced, and their root causes

| # | report | root cause | where |
|---|---|---|---|
| 1 | Sensor shows nothing until you open Configure, then loses readings again | `SensorDataModel` ignores a sensor list assigned while disabled; a card is created off screen, and discovery finishes a moment later | `02` |
| 2 | Fans does not show all fans | the kernel exposes one fan (no Super I/O driver); *but* the catalogue was also filtering candidates by name before looking at units | `00`, `01` |
| 3 | Fans: RPM missing, icon broken, no animation | same subscription bug; the glyph was drawn asymmetrically; the animation was correctly not running for a fan at 0 RPM, which the card failed to say | `01` |
| 4 | Gallery arrows vanish and hover does not bring them back | the two crossfading slides swap `z: 0/1`; the buttons were at the default `z: 0` | `03` |
| 5 | GPU Meter scrolls for two GPUs | one fixed card shape, and the container made to cope | `04` |
| 6 | Configure Live Scores does not fit | the dialog never gave a settings page its width after the first one, so the page laid out at width 0; and the competition grid depended on width | `05` |
| 7 | Countdown: no notification, no sound on Wayland; fine on X11 | the tick required the card to be *in the viewport*; and Do Not Disturb has been on since 2025 on that machine | `06` |

## Files changed

| file | change |
|---|---|
| `gadgets/SensorSubscription.qml` | **new** — correct subscription, kept readings, watchdog |
| `gadgets/SensorCatalog.qml` | rewritten — classify by unit, no name filter, no dropping on a missing value, bounded retry, settle on stability, `iconFor` |
| `gadgets/items/SensorGadget.qml` | rebuilt in the Drive Info language, category icons, waiting state, height-aware density |
| `gadgets/items/FansGadget.qml` | same, plus the three fan states |
| `gadgets/items/GalleryGadget.qml` | `z` on the buttons and the click area |
| `gadgets/items/GpuGadget.qml` | three densities chosen by height, `power1` fallback, empty state |
| `gadgets/items/SportsGadget.qml` | motorsport branch, settings as one vertical list |
| `gadgets/items/sports/Formula1View.qml` | **new** — the whole F1 presentation |
| `gadgets/lib/Formula1Provider.js` | **new** — jolpica/Ergast |
| `gadgets/GadgetSettingsDialog.qml` | width handed to the page, scale-aware sizing, clamps |
| `gadgets/GadgetHost.qml` | `pageActive` |
| `gadgets/items/CountdownGadget.qml` | ticks on `pageActive`, reads and explains Do Not Disturb |
| `gadgets/GadgetRegistry.qml` | icons that exist |
| `gadgets/icons/{fan,cpu,gpu,temperature}-symbolic.svg` | fan redrawn; three new |

## Architectural changes

1. **Subscription is a component, not a pattern to repeat.**
   `SensorSubscription` owns the rule that was got wrong twice, and both
   sensor gadgets go through it.
2. **The catalogue answers "what exists", the gadget answers "what is
   readable".** Existence comes from the sensor's unit and changes only
   when hardware changes; a value is a moment-to-moment thing. Mixing the
   two is what made rows disappear.
3. **`pageActive` beside `active`.** Two different questions — "is this
   card visible" and "is this page open" — that were being answered by
   one property.
4. **Density is computed from available height**, in the GPU meter and in
   both sensor cards, instead of a layout per card size.
5. **A provider per sport family.** TheSportsDB stays for team sports;
   Formula 1 has its own provider and its own view, chosen after checking
   what each source actually returns.

## Per gadget

### Fans — `01`

*Before*: one fan listed, `—` for its speed for ever, a clover-shaped
icon, no animation. *Cause*: the subscription bug, a name-based candidate
filter, and a badly drawn glyph. *After*: speed updates, `0 RPM` and "no
reading yet" are different things, the icon is a symmetric three-blade
rotor, the animation is gated exactly as before and now explains itself.
*Tested*: real hardware (1 fan), VM (none), harness (sizes).

### Sensor — `02`

*Before*: empty until Configure, then partial, then empty again.
*Cause*: the subscription bug, plus a classification pass that dropped
any sensor without a value at that instant — permanently. *After*: eight
sensors two seconds after the card comes into view, values kept across
scrolling, grouped by device with the kind of hardware as the row's icon.
*Tested*: real hardware, VM, harness.

### Gallery — `03`

*Before*: arrows for a moment, then never. *Cause*: `z`. *After*: always
present at 0.45, full on hover or focus, above the picture. *Tested*:
real hardware, 212 pictures.

### GPU Meter — `04`

*Before*: two GPUs, a scrollbar, and no power reading. *After*: both
cards complete at every size, three densities, power from whichever
sensor carries it. *Tested*: real hardware (2 GPUs) and harness at
1x1/2x1/1x2/2x2.

### Live Scores — `05`

*Before*: settings that did not fit. *Cause*: two — a page laid out at
width 0, and a width-dependent grid. *After*: one vertical list, controls
under their labels, notes in a footer, a dialog that sizes itself from
the popup. *Tested*: real hardware.

### Formula 1 — `05`

*Before*: a football fixture list with cars in it, and no championship at
all. *After*: next race, results, drivers, teams, calendar, from
jolpica/Ergast, cached, with team colours and flags and no dependence on
remote images. *Tested*: real hardware, live data.

### Countdown — `06`

*Before*: silent. *After*: counts while the menu is open wherever the
card sits, and says so when Do Not Disturb is hiding the pop-up.
*Tested*: real hardware (Wayland), VM (Wayland and X11).

## Wayland versus X11

**There is no difference.** The correlation was a coincidence of
configuration: the machine that "did not work" has Do Not Disturb on
until September 2027 and a Countdown card below the fold; the machine
that "worked" has neither. Both display servers were tested with the same
build and behave identically — install, Info page, countdown firing with
the card out of view, zero QML messages, no crash.

## Performance — `08`

- 42-gadget stress on the VM: edit mode costs nothing measurable, scroll
  is vsync-bound, RSS plateaus at 662 MB over 50 open/close cycles.
- Sensor discovery is one tree walk plus one metadata burst that
  unsubscribes when it is done; live subscriptions exist only for rows on
  screen and genuinely stop when the card leaves the viewport.
- Formula 1 costs at most five requests per refresh, cached for 30
  minutes (12 hours for the calendar), and none at all when another
  competition is selected.
- Nothing new runs while the menu is closed.

## Accessibility and i18n — `07`

Roles and sentence-shaped names on every new row; colour never the only
channel; group headings as headings. Source strings are English with
context, plurals and locale-aware numbers and dates — the audit reports
**0 unwrapped visible literals**. No screen-reader session was run.

## Found but not fixed

- **The developer machine's default audio sink is a digital S/PDIF
  output.** Anything played there is inaudible without a receiver
  attached, and `canberra-gtk-play` exits 0 either way. Not the gadget's
  to fix, but it is the likeliest reason a working alarm still sounds
  silent (`06`).
- **Motherboard fans need the `nct6775` driver**, which this system does
  not load. Loading a kernel module on someone's machine to improve a
  screenshot is not something this stage did; the settings now say so.
- **`NotesGadget` has no scrollbar** on its text area — pre-existing and
  outside this stage's area.
- **Three instances of the applet keep an empty `gadgetLayout`**, one per
  screen that has never shown the Info page. Harmless, but it means any
  tool reading the config must tolerate an empty value; this stage's
  scripts learned that the hard way.

## Known limits

- A turning fan was never observed; the spin is exercised only by forcing
  the angle.
- Three or more GPUs, Intel and NVIDIA discovery, and interface scales
  above 100 % are reasoned about, not measured.
- The Formula 1 provider was not tested against an outage or a
  rate-limit response.
- The `.notifyrc` packaging conclusion comes from reading the PKGBUILD,
  not from building the package.

## Verdict

| area | verdict |
|---|---|
| Fans | **pass** — with the hardware's own limit stated plainly |
| Sensor | **pass** |
| Gallery | **pass** |
| GPU Meter | **pass** for 1 and 2 GPUs; 3+ unverified |
| Live Scores settings | **pass** |
| Formula 1 | **pass** |
| Countdown | **pass** — cause found and explained; the pop-up remains the user's setting |
| Wayland vs X11 | **answered**: not the cause |
| performance | **pass** |
| stability | **pass** — no crash, no QML message, in any run |
