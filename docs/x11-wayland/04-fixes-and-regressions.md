# 04 · Fixes and regression checks

Development notes. Nothing here is needed at runtime.

Four fixes. Every one was verified on **both** backends after the change, and
none introduced backend-conditional code.

| # | Fix | File | X11 after | Wayland after |
| --- | --- | --- | --- | --- |
| 1 | Search intent is explicit, not inferred from `focusReason` | `Header.qml` | PASS | PASS |
| 2 | Places follows the `trackingState` API | `PlacesPage.qml` | PASS | PASS |
| 3 | No package suggestions for arithmetic / unit conversions | `components/SoftwareSearch.qml` | PASS | PASS |
| 4 | Onboarding overlay no longer anchors inside a layout | `FullRepresentation.qml` | PASS | PASS |

Causes and evidence are in
[03-issues-and-root-causes.md](03-issues-and-root-causes.md).

## Why none of them is backend-specific

The brief asks for one implementation rather than `if X11 … else Wayland …`.
None of these fixes needed a branch:

* **#1** removed the only piece of backend-sensitive logic in the project. It
  depended on how a popup's focus chain resolves, which is not guaranteed to be
  the same anywhere; the replacement depends on the user tapping, tabbing, or
  typing, which is identical everywhere.
* **#2** is an API mismatch, protocol-independent.
* **#3** is string handling.
* **#4** is QML parenting.

After the fixes, a search across every `.qml` and `.js` file for `DISPLAY`,
`XAUTHORITY`, `X11`, `Xlib`, `wayland`, `xdotool`, `xrandr`, `xprop`,
`Qt.platform`, `platformName`, `isWayland`, `isX11` returns **only the
explanatory comments in `Header.qml`**. There is no conditional code for either
backend anywhere in the plasmoid.

## Regression checks after the fixes

Run on both backends with the final build:

| Area | X11 | Wayland |
| --- | --- | --- |
| Launcher opens / closes | PASS | PASS |
| Header resting state (avatar, `Search…`) | PASS | PASS |
| Header engaged state | PASS | PASS (via typing) |
| Home — favourites | PASS | PASS |
| Home — recent files after enabling history | PASS | n/a (already enabled) |
| Apps — categories and contents | PASS | NOT TESTED (pointer) |
| Apps — context menu | PASS | NOT TESTED (pointer) |
| Places — five categories | PASS | NOT TESTED (pointer) |
| Places — Computer groups | PASS | NOT TESTED (pointer) |
| Search — calculator | PASS | PASS |
| Search — unit conversion | PASS | PASS |
| Search — no spurious software rows | PASS | PASS |
| Info — gadgets render | PASS | PASS |
| Keyboard — Escape clears then closes | PASS | PASS |
| plasmashell restart — applets preserved | PASS | PASS |
| Clean uninstall + reinstall | PASS (initial install) | PASS |
| QML warnings from the plasmoid | **zero** | **zero** |
| Crashes | none | none |

Nothing that worked before these changes stopped working. The two behaviours
that *changed* are the two that were wrong: the header now rests instead of
opening expanded, and Places no longer covers its content with the "turned off"
message.

## Temporary changes made to the VM, and their removal

The audit needed root twice. Both changes were reverted:

| Change | Why | Reverted |
| --- | --- | --- |
| `/etc/sddm.conf.d/zz-audit-wayland.conf` (autologin to the Wayland session) | the VM had no autologin and SDDM's state file is root-owned, so there was no other way to reach a Wayland session without typing at the greeter | **removed** |
| `/var/lib/sddm/state.conf` set to the Wayland session | same | **restored from backup** — now back to `plasmax11.desktop` |
| `ydotool` + `ydotoold` installed | the only way to inject real input on Wayland; xdotool cannot reach a native Wayland client | daemon stopped, **package removed** |

No credentials were written anywhere, and no test tool became a dependency of
the plasmoid — `pkgbuild/PKGBUILD` is unchanged by this audit.
