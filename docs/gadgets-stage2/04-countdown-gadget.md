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

`gadgets/CountdownAlarm.qml` keeps the short-lived process and adds what was
missing. It owns a `Timer` that fires every 2.5 s — about the length of the
sound — while `ringing` is true, and each tick runs one play command that
exits on its own. The loop is therefore in QML, not in a shell: acknowledging
stops it at the next tick, at most one sound plays out, there is no
`while true`, and nothing survives the gadget. `ringing` is the single fact
*"at least one finished event has not been acknowledged"*.

The command is a fixed string — `canberra-gtk-play -i alarm-clock-elapsed`,
falling back to `paplay` and `pw-play` on the freedesktop theme's file.
Nothing from an event, a setting or a file name is interpolated into it.

### Why not QtMultimedia

The first version of this file *was* a `MediaPlayer { loops: Infinite }`,
which is the obvious way to loop a sound and worked on the lab VM. It cost
the developer's desktop 122 crashes.

Importing `QtMultimedia` brings up the FFmpeg backend, which brings up
Vulkan, which loads the machine's implicit Vulkan layers. On a machine with
**vkBasalt** enabled that combination segfaults. Inside plasmashell it is not
a missing sound, it is the whole desktop in a restart loop: the panel and the
menu blink in and out for as long as the gadget is on the board, because the
Countdown card creates the player as soon as it is instantiated.

Measured with a file containing nothing but a `MediaPlayer`, under bare
`qml6` (so: not a Plasma problem, and not this plasmoid's own code):

| run | result |
|---|---|
| as the machine is configured | **SIGSEGV** |
| `VK_LOADER_LAYERS_DISABLE='*'` | survives |
| `DISABLE_VKBASALT=1` | **survives** |
| FFmpeg hardware decoding disabled | SIGSEGV |

So the trigger is the Vulkan layer, not hardware decoding, and not something
the gadget can detect beforehand — a segfault cannot be caught, and
`Loader.status === Error` only covers a *missing* module, not one that
crashes the process while loading. The rule this leaves behind: **the shell
is not the process that gets to find out whether the media stack works
here.** Audio goes out of process, where a broken stack costs a sound and
nothing more.

`qt6-multimedia` is no longer an optional dependency; `libcanberra` is.

### Verified

On the VM, two events set to the same minute (with the earlier player, the
behaviour the rewrite reproduces):

```
t=69s  ringing=2  playing=True   notes=2   both fired, one loop
t=71s  ringing=2  playing=True   notes=2   acknowledge #1
t=72s  ringing=1  playing=True   notes=1   still ringing for #2
t=74s  ringing=1  playing=True   notes=1   acknowledge #2
t=75s  ringing=0  playing=False  notes=0   stopped
```

On the developer's machine, the rewritten file loaded on its own: `ringing`
on → `playing` true and audible, held for 6 s across repetitions, `ringing`
off → `playing` false, process exit 0, and `pgrep canberra|paplay|pw-play`
empty afterwards. plasmashell then ran 2.5 minutes with the gadget on the
board and the menu open: same pid, `NRestarts=0`, no new core dumps.

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
