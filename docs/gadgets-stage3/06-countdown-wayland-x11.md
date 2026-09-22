# 06 — Countdown: why it was silent, and why it was not Wayland

## The report

> On my main machine (Wayland) the countdown finished, the notification
> did not appear properly, and the alert sound did not play. On the VM
> (X11) it worked.

The instruction was to find out whether X11 and Wayland really differ or
whether the correlation is misleading. It is misleading. There were two
causes, and neither is the display server.

## Cause one: the card had to be on screen to count

```qml
Timer { running: cd.host.active && cd.next !== null; … }
```

and

```qml
readonly property bool active: grid.active && inViewport && !dragging
```

So the countdown ticked only while its card was **scrolled into view**.
On a board with 23 gadgets in 4 columns the Countdown card sits below the
fold: opening the menu was not enough, the user had to be looking at that
card for time to pass. No tick means no `fire()`, which means no
notification *and* no sound — both halves of the report at once.

Nobody can guess that rule, and nothing on screen suggests it.

`GadgetHost` gains a second, narrower property:

```qml
readonly property bool active:     grid.active && inViewport && !dragging
readonly property bool pageActive: grid.active && !dragging
```

Almost every gadget wants `active` — polling a sensor nobody can see is
waste. A gadget that must keep *counting* while the user looks elsewhere
on the page uses `pageActive`. The countdown does. It still counts only
while the menu is open: this is not a background service, and the
deliberate design of stage 2 — an event that elapses with the menu closed
is processed when the menu is next opened — is unchanged.

Verified by putting the Countdown card last on the board, opening the
menu and never scrolling to it:

| | |
|---|---|
| developer machine, Wayland | `fired: true` |
| lab VM, Wayland | `fired: true` |
| lab VM, **X11** | `fired: true` |

## Cause two: Do Not Disturb

With the tick fixed, the notification still did not appear on the
developer's machine. Traced step by step inside plasmashell:

```
PROBE fire() entrou: Alarm test ts=… created=…
PROBE fire() texto pronto: Finished at 00:55 after 1 minute (started 00:54).
PROBE fire() objeto=criado
kf.notifications: Calling notify on "Popup"
PROBE fire() sendEvent chamado
```

KNotification dispatches. The same component, sent from a bare `qml6`
process, reaches the bus correctly and with our own identity:

```
string "Contagem regressiva"      ← app name, from our .notifyrc
string "chronometer"              ← app icon
string "Countdown"
string "Alarm test (component of our own)"
```

So the component, the `.notifyrc` and the notification path are all
sound. The pop-up still never appeared on any of the three screens.

```
$ cat ~/.config/plasmanotifyrc
[DoNotDisturb]
NotificationSoundsMuted=true
Until=2027,8,16,18,37,15.86          ← 16 September 2027 (months are 0-based)

$ qdbus6 org.freedesktop.Notifications … Inhibited
true
```

**Do Not Disturb has been on for a year and stays on for another.** Every
notification is suppressed and kept in history, and notification sounds
are muted. The lab VM has no `[DoNotDisturb]` section at all — which is
the entire difference between the two machines, and it happened to be the
X11 one.

The gadget does not override the setting; it is the user's. It says so
instead — on the card while something is ringing, and in the settings:

> Do Not Disturb is on — the pop-up is hidden.

The state is read once when an alarm fires and once when the settings are
opened, never on a timer, with a fixed command
(`busctl --user get-property … Inhibited`) into which nothing is
interpolated.

## The sound

The alarm plays out of process — one short-lived
`canberra-gtk-play -i alarm-clock-elapsed || paplay … || pw-play …` per
repetition, driven by a `Timer` in the gadget rather than a shell loop
(stage 2, `04`: QtMultimedia inside plasmashell segfaults on this machine
through vkBasalt). It is not routed through the notification system, so
`NotificationSoundsMuted` does not silence it.

Observed at the moment an alarm fired on the developer's machine:

```
3126204 /bin/sh -c canberra-gtk-play -i alarm-clock-elapsed || paplay …
3126205 canberra-gtk-play -i alarm-clock-elapsed
```

Two notes on the audio path, neither of which is the gadget's to fix:

- **`canberra-gtk-play` exits 0 whether or not anything was audible.**
  The `||` chain therefore only recovers from a missing binary or a
  missing file, not from silence. This is the "a backend may report
  success and still produce no sound" case in the brief, and it is real.
- This machine's default sink is
  `alsa_output.usb-…-00.iec958-stereo` — a **digital S/PDIF** output at
  100 % and unmuted. Anything played there is inaudible unless a digital
  receiver is attached. The sound theme files exist (`ocean` and
  `freedesktop` both carry `alarm-clock-elapsed.oga`).

## Packaging: the `.notifyrc`

The hypothesis recorded in stage 2 is confirmed, by reading the recipe
rather than by guessing:

- **`pkgbuild/PKGBUILD` copies the whole `usr/` tree**, so the package
  does install `usr/share/knotifications6/org.biglinux.appsmenu.countdown.notifyrc`.
- **`kpackagetool6 --install` installs only the plasmoid package** into
  `~/.local/share/plasma/plasmoids/`. A development install therefore has
  no `.notifyrc` unless it is copied by hand, and KNotification then
  falls back to a generic identity.

For a development install, the one extra step is:

```
install -Dm644 usr/share/knotifications6/org.biglinux.appsmenu.countdown.notifyrc \
  ~/.local/share/knotifications6/org.biglinux.appsmenu.countdown.notifyrc
```

Both machines in this stage had it in `~/.local/share/knotifications6/`,
which is why the identity in the bus capture above is correct.

## Test matrix

| environment | install | fires | notification | sound | dismiss | plasmashell |
|---|---|---|---|---|---|---|
| developer, Wayland | development | **pass** | dispatched, **suppressed by DND** (and now said so) | **pass** (process observed) | **pass** | stable, 0 restarts |
| VM, Wayland | development | **pass** | **not captured** — no DND there, but no screen was watched | not checked | — | stable, 0 restarts |
| VM, **X11** | development | **pass** | **not captured** | not checked | — | stable, 0 restarts |
| any, package install | — | **NOT TESTED** — no package was built in this stage |

Dismiss, repeated alarms and two simultaneous countdowns were verified in
stage 2 (`docs/gadgets-stage2/04`) and none of their code changed here
beyond the tick condition.

## Status

| | |
|---|---|
| why X11 "worked" and Wayland did not | **answered**: the card was off screen, and DND was on — not the display server |
| counts with the card out of view | **TESTED ON REAL HARDWARE** and **ON VM**, both sessions |
| notification reaches the server | **TESTED ON REAL HARDWARE** (dispatch logged; delivery verified separately from `qml6`) |
| pop-up visible with DND off | **NOT TESTED** — the user's DND was left alone |
| sound plays | **TESTED ON REAL HARDWARE** (player process observed) |
| no orphan processes | **TESTED ON REAL HARDWARE** |
| no crash | **TESTED ON REAL HARDWARE** and **ON VM** |
