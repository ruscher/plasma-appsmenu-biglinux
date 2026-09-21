# 06 · Final compatibility matrix

Development notes. Nothing here is needed at runtime.

Legend: **PASS** tested and works · **FAIL** tested and broken · **NOT TESTED**
not exercised, with the reason given · **N/A** does not apply to that protocol.

All rows refer to the final build (after the four fixes).

| Feature | X11 | Wayland | Note |
| --- | --- | --- | --- |
| Session genuinely of that type | PASS | PASS | `loginctl` + plasmashell environ + compositor process |
| Install via `kpackagetool6` | PASS | PASS | |
| Correct copy loaded (not the old system package) | PASS | PASS | verified from QML file paths |
| Clean uninstall + reinstall | PASS | PASS | |
| Launcher opens | PASS | PASS | X11: global shortcut · Wayland: `activateLauncherMenu()` |
| Launcher closes (Escape) | PASS | PASS | |
| Repeated open/close | PASS | PASS | 60 and ~210 cycles respectively |
| Header — resting (avatar + `Search…`) | PASS | PASS | was broken on both, fix #1 |
| Header — expands on engagement | PASS | PASS | |
| Onboarding overlay | PASS | PASS | shown once, dismissed, no warning after fix #4 |
| Home — favourites | PASS | PASS | |
| Home — "recent files off" call to action | PASS | N/A | history was already on in the Wayland round |
| Home — **Turn on recent files** | PASS | N/A | fixed all three blockers in one click |
| Home — recent files populate | PASS | N/A | |
| Apps — categories, counts, contents | PASS | NOT TESTED | pointer injection closes the popup on Wayland |
| Apps — context menu, jump lists, favourites | PASS | NOT TESTED | same |
| Places — five categories, Frequently Used first | PASS | NOT TESTED | same |
| Places — "turned off" overlay bug | PASS | PASS | fix #2; the binding is protocol-independent |
| Places — Computer: Applications / Places / Remote | PASS | NOT TESTED | pointer |
| Search — applications | PASS | PASS | |
| Search — calculator (`2+2`, `sqrt(144)`) | PASS | PASS | |
| Search — unit conversion (`1 l em ml`) | PASS | PASS | |
| Search — no packages for conversions | PASS | PASS | fix #3 |
| Search — typing reaches the field with no click | PASS | PASS | |
| Info — gadgets render live | PASS | PASS | Clock, Weather, Calendar, CPU, Memory |
| `plasma-ksystemstats` on-demand activation | PASS | PASS | |
| Keyboard — Escape clears query | PASS | PASS | |
| Keyboard — second Escape closes | PASS | PASS | |
| Keyboard — Tab | PASS | PASS | |
| Drag & drop | NOT TESTED | NOT TESTED | delegate arms drags only for `Qt.MouseEventNotSynthesized`; injected input never qualifies |
| Clipboard / PRIMARY selection | NOT TESTED | NOT TESTED | the launcher has no clipboard code of its own; the Clipboard gadget was not exercised |
| Multi-monitor | NOT TESTED | NOT TESTED | VM has one virtual output (1280x800) |
| Fractional scaling | NOT TESTED | NOT TESTED | not configured on the VM |
| Panel on other edges | NOT TESTED | NOT TESTED | bottom panel only |
| Themes (Breeze light/dark) | NOT TESTED | NOT TESTED | default BigLinux theme only |
| plasmashell restart — applets preserved | PASS | PASS | 4 instances |
| No duplicate plasmashell | PASS | PASS | `--no-respawn`, single process |
| Stress — no crash | PASS | PASS | |
| Memory — no leak | PASS | PASS | plateaus; see 05 |
| QML warnings from the plasmoid | **zero** | **zero** | after fix #4 |
| Crashes attributable to the launcher | none | none | |

## Honest reading of this table

There is no row where X11 passes and Wayland fails, or the reverse. Every
defect found reproduced on both backends and every fix verified on both — which
is the expected outcome for a plasmoid that contains no backend-specific code.

The Wayland NOT TESTED rows are all the **same single cause**: injected pointer
input closes the popup on this compositor, so pointer-driven UI could not be
exercised there. They are not evidence of a problem, and they are not evidence
of correctness either.
