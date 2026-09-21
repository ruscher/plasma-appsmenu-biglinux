# 00 · Environment baseline

Development notes. Nothing here is needed at runtime. No credentials are
recorded in this directory.

## The machine

Disposable lab VM, reached over SSH. The graphical session was **not** assumed
from the SSH environment — it was confirmed with `loginctl` and by reading the
real environment of the `plasmashell` process.

```
$ loginctl show-session 5 -p Id -p Type -p Class -p State -p Active -p Display -p Service
Id=5
Display=:1
Remote=no
Service=sddm
Type=x11          ← the graphical session
Class=user
Active=yes
State=active
```

```
$ pid=$(pgrep -n plasmashell); tr '\0' '\n' < /proc/$pid/environ
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
DISPLAY=:1
QT_LOGGING_RULES=*=false
XAUTHORITY=/tmp/xauth_ylJlEh
XDG_CURRENT_DESKTOP=KDE
XDG_RUNTIME_DIR=/run/user/1000
XDG_SESSION_TYPE=x11
```

```
$ pgrep -a -f 'kwin_x11|kwin_wayland|Xorg'
1306  /usr/lib/Xorg … vt2
64826 /usr/lib/Xorg … vt3
65385 /usr/bin/kwin_x11 --replace
```

Three independent confirmations that round one really ran on X11.

Note `QT_LOGGING_RULES=*=false` in the session environment: **QML warnings are
hidden by default on this image**. Every log check in this audit was made after
overriding it with

```
systemctl --user set-environment 'QT_LOGGING_RULES=*.debug=false;*.info=false;*.warning=true;*.critical=true'
```

Without that, "no warnings in the journal" would have been meaningless.

## Versions

| Component | Version |
| --- | --- |
| Distribution | BigLinux based on Manjaro, rolling |
| Kernel | 6.18.44-1-MANJARO |
| systemd | 261 |
| Plasma | **6.7.4** |
| KWin | **6.7.4** (both `kwin_x11` and `kwin_wayland` present) |
| KDE Frameworks | **6.29.0** (kirigami, kio, kitemmodels, baloo) |
| Qt | **6.11.2** |
| plasma5support | 6.7.4 |
| plasma-activities-stats | 6.7.4 |
| Xorg server | 21.1.24 |
| Wayland | 1.26.0 |
| Mesa | 26.2.2 |
| GPU | Red Hat Virtio 1.0 GPU — **llvmpipe** (software rendering) |
| kpackagetool6 | 2.0 |

Software rendering matters for the performance section: everything is composited
on the CPU, so timings here are a floor, not a representative desktop.

## Sessions available

```
/usr/share/xsessions/        bigcontrolcenter.desktop  plasmax11.desktop
/usr/share/wayland-sessions/ plasma.desktop
```

Both backends are installed, so the second round is possible on this machine.

## User services

| Unit | State |
| --- | --- |
| `plasma-plasmashell.service` | active |
| `plasma-kactivitymanagerd.service` | active |
| `plasma-ksystemstats.service` | **inactive** (socket/D-Bus activated; it starts when a sensor is first requested) |

## Which copy of the plasmoid is under test

This mattered: the VM shipped an **old** package,
`plasma-appsmenu-biglinux 25.12.23-1333`, installed at
`/usr/share/plasma/plasmoids/org.biglinux.appsmenu`. Testing that by accident
would have invalidated the whole audit.

The branch under test was installed per-user:

```
$ kpackagetool6 --type Plasma/Applet --install ~/appsmenu-src
Successfully installed /home/ruscher/.local/share/plasma/plasmoids/org.biglinux.appsmenu/
```

and the loaded copy was then confirmed from plasmashell's own QML file paths
rather than assumed:

```
$ journalctl --user -u plasma-plasmashell.service | grep -oE 'file:///[^ :]*appsmenu[^ :]*'
file:///home/ruscher/.local/share/plasma/plasmoids/org.biglinux.appsmenu
```

Neither copy declares a `Version` in `metadata.json`, so version strings could
not have been used to tell them apart — the file path was the only reliable
discriminator.

`kpackagetool6 --appstream-metainfo` on the package exits 0 and emits valid
AppStream XML.

## Code under test

The three pending feature branches were merged onto
`audit/x11-wayland-compatibility` so the audit covers what would actually ship:

```
main
 ├── fix/recent-files-locations
 ├── feature/krunner-search-pamac
 └── feature/places-activity-hub   ← stacked on krunner
        └── audit/x11-wayland-compatibility  = places + recent-files merged
```

One merge conflict, in `FullRepresentation.qml`: recent-files added empty-state
wiring to the inline Places block, which places-activity-hub had replaced with
`PlacesPage.qml`. Resolved in favour of `PlacesPage`, which already carries the
richer empty states.

Integrating the branches is also what exposed issue **#2** in
[03-issues-and-root-causes.md](03-issues-and-root-causes.md) — a real API
mismatch that neither branch could show on its own.
