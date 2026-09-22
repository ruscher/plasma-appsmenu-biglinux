# 04 — Countdown gadget

## The list

Only the next event was shown. Now the next one is large and every other
event sits in a `ListView` under it: upcoming ones with their remaining time
(days once it is that far, then `h min`, then `m:ss`), finished ones marked
*done* until removed. The list is bounded by the card and scrolls; on a 1x1
card it gets whatever height the countdown leaves. Twenty events do not grow
the gadget.

## The alarm

The old alarm ran `canberra-gtk-play || paplay || pw-play` through the
executable data engine: one shot, unstoppable, unloopable, and a process the
gadget could not clean up.

`gadgets/CountdownAlarm.qml` is a `MediaPlayer` with `loops: Infinite` on the
system sound theme's alarm (Ocean, then freedesktop, then Oxygen, tried in
order on error). It is owned by the gadget item, starts and stops with the
single fact *"at least one finished event has not been acknowledged"*, and is
stopped on destruction. There is no process to orphan.

It lives in its own file because it imports `QtMultimedia`: the gadget loads
it through a `Loader`, and if the module is absent the load fails in that file
alone and the old single beep is used. `qt6-multimedia` is an optional
dependency in the PKGBUILD for that reason.

### Verified on the VM

Two events set to the same minute:

```
t=69s  ringing=2  playing=True   notes=2   both fired, one loop
t=71s  ringing=2  playing=True   notes=2   acknowledge #1
t=72s  ringing=1  playing=True   notes=1   still ringing for #2
t=74s  ringing=1  playing=True   notes=1   acknowledge #2
t=75s  ringing=0  playing=False  notes=0   stopped
```

`pgrep canberra|paplay|pw-play` → 0 throughout. The backend announced itself
in the journal: `Using Qt multimedia with FFmpeg`.

## The window that said "Plasma"

Traced, not assumed. The gadget used `KNotification` with `componentName:
"plasma_workspace"`. A notification's application name and icon come from
that component's notifyrc — `plasma_workspace.notifyrc` has `Name=Plasma` and
`IconName=start-here-kde-plasma` — and nothing in the sending code can
override them. Setting `iconName` on the notification changes the body icon,
not the app icon in the header.

The fix is a component of our own, the way the Timer applet ships
`plasma_applet_timer.notifyrc`:

```
usr/share/knotifications6/org.biglinux.appsmenu.countdown.notifyrc
  [Global]  Name=Countdown  IconName=chronometer
  [Event/finished]  Action=Popup
```

Captured on the session bus with `busctl monitor`:

```
Notify( app_name="Countdown", app_icon="chronometer", summary=<event name>,
        actions=["1","Dismiss"], hints: x-kde-appname=org.biglinux.appsmenu.countdown )
```

The popup has a **Dismiss** action; it, the default action and closing the
popup all call `acknowledge()`, which marks the event `acked`, closes the
popup, and — because the alarm runs on "unacknowledged finished events" —
silences the sound. The same dismissal is on the card (a bell button on a
ringing row), and removing a finished event acknowledges it too. The sound can
never outlive the notification that explains it.

`kpackagetool6` installs only the plasmoid, so a development install has no
notifyrc and KNotification shows nothing for the event; the package installs
`usr/share/knotifications6/` and the lab VM was given the file under
`~/.local/share/knotifications6/`. Worth knowing when testing.

## Limits, stated

The gadget ticks while the menu is open. An event that elapses with the menu
closed fires on the next open. That was the design before and remains
deliberate: a countdown does not justify a background service.
