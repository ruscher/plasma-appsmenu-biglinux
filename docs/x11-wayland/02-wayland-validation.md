# 02 · Wayland validation

Development notes. Nothing here is needed at runtime.

## Getting into a real Wayland session

The VM had no autologin and SDDM's state file is root-owned, so switching
sessions needed a deliberate, reversible change:

```
/etc/sddm.conf.d/zz-audit-wayland.conf     ← added
    [Autologin]
    User=ruscher
    Session=plasma.desktop                 ← /usr/share/wayland-sessions/

/var/lib/sddm/state.conf                   ← backed up to /root/audit-backup/
    [Last] Session=/usr/share/wayland-sessions/plasma.desktop
```

then `systemctl restart sddm`. **This is temporary and is removed at the end of
the audit** — see [04-fixes-and-regressions.md](04-fixes-and-regressions.md).

Session confirmed afterwards, three ways:

```
$ loginctl show-session 72 -p Type -p Class -p Active -p Service
Id=72  Service=sddm-autologin  Type=wayland  Class=user  Active=yes

$ tr '\0' '\n' < /proc/$(pgrep -n plasmashell)/environ
WAYLAND_DISPLAY=wayland-0
XDG_SESSION_TYPE=wayland
DISPLAY=:1                   ← Xwayland, not native X

$ pgrep -a -f 'kwin_wayland|Xwayland'
kwin_wayland --wayland-fd 7 --socket wayland-0 --xwayland-fd 8 … --xwayland
Xwayland :1 -auth /run/user/1000/xauth_ujTTRT … -rootless
```

The BigLinux welcome app also reported **TELA: Wayland** on screen.

## Tooling — and why xdotool is not evidence here

`DISPLAY=:1` exists on this session because Xwayland is running, so `xdotool`
*appears* usable. It is not, and this was measured rather than assumed:

```
$ xdotool search --class plasmashell
(nothing)
$ xdotool search --onlyvisible '' | wc -l
3                       ← unchanged before and after opening the launcher
```

plasmashell is a native Wayland client; its popup is a Wayland surface, not an
X window. Any X11 tool is blind to it. Using xdotool here would have produced
confident, meaningless results.

Real input therefore came from **ydotool** (installed for the audit), which
injects through `/dev/uinput` at kernel level:

```
systemd-run --unit=ydotoold-audit /usr/bin/ydotoold -p /tmp/.ydotool_socket -P 0660 -o 1000:1007
```

The menu was opened with `org.kde.PlasmaShell.activateLauncherMenu()` — an
*open*, not a toggle, which removed the state guesswork that plagued the first
attempts. Screenshots via `spectacle`.

**Pointer limitation.** `ydotool mousemove -a` performs an absolute warp through
a synthetic uinput device; on this compositor that consistently caused the
launcher popup to deactivate and close before the click landed. Keyboard
injection has no such problem, so the Wayland round was driven **by keyboard**,
which is what the brief asks to be tested anyway. Pointer-driven tests are
marked accordingly.

## Results

| # | Area | Test | Result |
| --- | --- | --- | --- |
| 1 | Session | genuinely Wayland | PASS — three independent confirmations |
| 2 | Install | correct copy loaded | PASS — `~/.local/share/...` from QML paths |
| 3 | Launcher | opens via D-Bus | PASS |
| 4 | Header | resting: avatar + name + `Search…` | PASS — fix #1 holds on Wayland |
| 5 | Header | expands once text is typed | PASS |
| 6 | Info | gadgets render live | PASS — Clock, Weather (Brasília 31 °C), Calendar, CPU 32 % @ 3.80 GHz, Memory 38 % (3,0/7,7 GB) |
| 7 | Info | `plasma-ksystemstats` activates on demand | PASS — meters populated although the unit starts inactive |
| 8 | Search | `2+2` → Calculadora / 4 | PASS |
| 9 | Search | `1 l em ml` → Conversor de unidades / 1.000 ml | PASS |
| 10 | Search | no package suggestions for conversions | PASS — fix #3 holds on Wayland |
| 11 | Keyboard | typing reaches the field with no click | PASS |
| 12 | Keyboard | Escape clears the query | PASS |
| 13 | Keyboard | second Escape closes the menu | PASS |
| 14 | Stress | 60 keyboard cycles | PASS — no crash, same PID |
| 15 | Memory | RSS across the run | see 05 — grows more than on X11, analysed there |
| 16 | Logs | QML warnings from the plasmoid | PASS — none |
| 17 | Crashes | journal / coredumpctl | PASS — none from plasmashell |
| 18 | Tabs by pointer | click Home/Apps/Places/Info | NOT TESTED — pointer warp closes the popup (tooling) |
| 19 | Context menu | right-click an app | NOT TESTED — same reason |
| 20 | Drag & drop | app → desktop | NOT TESTED — see below |

## Drag and drop on Wayland

Not tested, for the same architectural reason as X11: the delegate only arms a
drag for `Qt.MouseEventNotSynthesized`, and the pointer path could not be
driven at all here without closing the popup.

What *can* be said with confidence is structural: the implementation is
`Drag.active` / `Drag.dragType: Drag.Automatic` / `Drag.mimeData` — Qt's
protocol-agnostic drag API, which maps to XDND on X11 and `wl_data_device` on
Wayland without any code in this project choosing between them. There is no
X11-specific drag code to fail on Wayland, because there is no backend-specific
code at all (see 03).

## What Wayland did *not* break

Worth stating explicitly, because it is the point of the audit: every defect
found in this audit reproduced identically on both backends, and every fix
verified on both. Nothing needed a `if (wayland)` branch, and none was added.
