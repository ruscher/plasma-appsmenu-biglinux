# 01 · X11 validation

Development notes. Nothing here is needed at runtime.

Session confirmed as X11 before any testing — see
[00-environment-baseline.md](00-environment-baseline.md): `loginctl` session 5
`Type=x11`, plasmashell's own environment `XDG_SESSION_TYPE=x11 DISPLAY=:1`,
compositor `kwin_x11`.

Input was driven with **xdotool** (real X11 events), the menu opened through
`org.kde.kglobalaccel`, screenshots taken with `import`. The popup was located
each time via `xdotool getwindowgeometry` rather than hard-coded, and a helper
(`popup_id`/`ensure_open`/`ensure_closed`) made open/close deterministic instead
of blind toggling.

Popup geometry: `1017x635+131+117` on a 1280x800 screen, bottom panel.

## Results

| # | Area | Test | Result |
| --- | --- | --- | --- |
| 1 | Install | `kpackagetool6 --install`, correct copy loaded | PASS — loaded from `~/.local/share/...`, confirmed from QML file paths |
| 2 | Launcher | opens via global shortcut | PASS |
| 3 | Launcher | closes, reopens repeatedly | PASS (60 stress cycles) |
| 4 | Onboarding | overlay shown once, dismissed, does not return | PASS |
| 5 | Header | resting state: avatar + name + `Search…` | **FAIL → fixed** (issue #1) |
| 6 | Header | engaged state: avatar collapses, long placeholder | PASS after fix |
| 7 | Home | Favorites render | PASS |
| 8 | Home | "Recent files are turned off" call to action | PASS — shown correctly, history really was off |
| 9 | Home | **Turn on recent files** | PASS — see below |
| 10 | Home | Recent Files populated after enabling | PASS — `audit-test.txt` appeared |
| 11 | Apps | categories + counts + contents | PASS — Escritório 8, Gráficos 4, Internet 4, Jogos 4, Multimídia 7, Sistema 10, Utilitários 9, Webapps 10 |
| 12 | Apps | context menu | PASS — jump list ("Software Render"), Pin to Task Manager, Edit Application, Uninstall/manage, Add to Favorites |
| 13 | Places | five categories, Frequently Used first | PASS |
| 14 | Places | "turned off" overlay covering live content | **FAIL → fixed** (issue #2) |
| 15 | Places → Computer | Applications / Locais / Remoto groups | PASS — XDG dirs from KFilePlacesModel, incl. the user's own entries |
| 16 | Search | `firefox` | PASS |
| 17 | Search | `2+2` → Calculadora / 4 | PASS |
| 18 | Search | `sqrt(144)` | PASS |
| 19 | Search | `1 l em ml` → Conversor de unidades / 1.000 ml | PASS |
| 20 | Search | spurious package suggestions for conversions | **FAIL → fixed** (issue #3) |
| 21 | Keyboard | Escape with text clears the query | PASS |
| 22 | Keyboard | Escape with empty field closes the menu | PASS |
| 23 | Keyboard | typing reaches the field without clicking | PASS |
| 24 | Restart | `systemctl --user restart plasma-plasmashell` | PASS — 4 applet instances preserved, single process |
| 25 | Duplicates | no second plasmashell | PASS — `plasmashell --no-respawn`, one process |
| 26 | Stress | 60 open/tab-cycle/search/close cycles | PASS — no crash, same PID |
| 27 | Memory | RSS across the stress run | PASS — 487.7 → 490.0 MB (+0.47%), curve flattening |
| 28 | Logs | QML warnings from the plasmoid | **1 pre-existing → fixed** (issue #5), then **zero** |
| 29 | Crashes | `coredumpctl`, journal | PASS — none from plasmashell |
| 30 | Drag & drop | app → desktop | NOT TESTED — see below |

## The Turn-on-recent-files result, in full

This VM booted with the activity history off in the worst possible state, all
three blockers at once:

```
what-to-remember=2
enabled=false
off-the-record-activities=82dd571b-…     ← the current activity
check=false
```

One click on the button in the menu:

```
tracking=on  reason=ok  documents=on  enabled=true
off-the-record=            what-to-remember=0
check=true

ResourceEvent: 0 -> 1  (RECORDING)
```

and Home then listed the file under **Recent Files**. This is the first time
that code path has been exercised on a genuinely broken system.

## Drag and drop — why it is NOT TESTED rather than FAIL

`xdotool` never starts a drag, and the reason is in the delegate, inherited
from upstream Kickoff:

```qml
// Only enable drag and drop with a mouse.
// We don't have a good way to handle it and drag scrolling with touch.
mouseArea.dragEnabled = mouse.source === Qt.MouseEventNotSynthesized
```

`xdotool` injects through XTEST, so Qt reports the press as synthesized and the
drag is deliberately never armed. Three attempts (fast, slow, and with an
explicit threshold crossing) all behaved the same way, and the window count did
rise during the gesture, so the press reached the delegate — it simply refused
to arm a drag, exactly as written.

The code itself uses Qt's backend-agnostic `Drag.Automatic` API with
`Drag.mimeData: { "text/uri-list": url }`, which is the correct shared
implementation for XDND and `wl_data_device`.

## Also investigated

* **Context menu appeared stuck.** It is a separate plasmashell popup window
  (`323x200+791+213`); `Escape` sent while focus was on the launcher never
  reached it. Clicking outside dismisses it. Harness error, not a defect.
* **`QT_LOGGING_RULES=*=false`** is set session-wide on this image, so every
  log conclusion here was drawn only after overriding it.
